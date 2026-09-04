using JetGo.Application.Contracts.Messaging;
using JetGo.Application.Messaging.Notifications;
using JetGo.Domain.Enums;
using JetGo.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace JetGo.Infrastructure.Services;

public sealed class ReservationStatusSyncService
{
    private const string SystemActorUserId = "system:reservation-lifecycle";
    private static readonly TimeSpan PendingPaymentHoldDuration = TimeSpan.FromMinutes(30);

    private readonly JetGoDbContext _dbContext;
    private readonly ReservationStateMachine _stateMachine;
    private readonly INotificationEventPublisher _notificationEventPublisher;
    private readonly ILogger<ReservationStatusSyncService> _logger;

    public ReservationStatusSyncService(
        JetGoDbContext dbContext,
        ReservationStateMachine stateMachine,
        INotificationEventPublisher notificationEventPublisher,
        ILogger<ReservationStatusSyncService> logger)
    {
        _dbContext = dbContext;
        _stateMachine = stateMachine;
        _notificationEventPublisher = notificationEventPublisher;
        _logger = logger;
    }

    public async Task SyncCompletedReservationsAsync(DateTime nowUtc, CancellationToken cancellationToken = default)
    {
        var paymentExpiredBeforeUtc = nowUtc.Subtract(PendingPaymentHoldDuration);

        var expiredReservations = await _dbContext.Reservations
            .Include(x => x.Flight)
            .Include(x => x.Items)
                .ThenInclude(x => x.FlightSeat)
            .Include(x => x.Payment)
            .Where(x =>
                x.Status == ReservationStatus.Pending &&
                x.CreatedAtUtc <= paymentExpiredBeforeUtc &&
                (x.Payment == null || x.Payment.Status != PaymentStatus.Paid))
            .ToListAsync(cancellationToken);

        var expiredReservationNotifications = new List<(string UserId, string ReservationCode, string FlightNumber)>();

        foreach (var reservation in expiredReservations)
        {
            if (!_stateMachine.TryExpirePendingPayment(reservation, SystemActorUserId, nowUtc, PendingPaymentHoldDuration))
            {
                continue;
            }

            var releasedSeats = 0;

            foreach (var item in reservation.Items)
            {
                if (!item.FlightSeat.IsReserved)
                {
                    continue;
                }

                item.FlightSeat.IsReserved = false;
                releasedSeats++;
            }

            reservation.Flight.AvailableSeats = Math.Min(
                reservation.Flight.TotalSeats,
                reservation.Flight.AvailableSeats + releasedSeats);

            if (reservation.Payment?.Status == PaymentStatus.Pending)
            {
                reservation.Payment.Status = PaymentStatus.Failed;
                reservation.Payment.StatusReason = "Placanje je isteklo jer rezervacija nije placena u predvidjenom roku.";
                reservation.Payment.UpdatedAtUtc = nowUtc;
            }

            expiredReservationNotifications.Add((reservation.UserId, reservation.ReservationCode, reservation.Flight.FlightNumber));
        }

        var reservations = await _dbContext.Reservations
            .Include(x => x.Flight)
            .Include(x => x.Payment)
            .Where(x =>
                x.Status == ReservationStatus.Confirmed &&
                x.Payment != null &&
                x.Payment.Status == PaymentStatus.Paid &&
                x.Flight.ArrivalAtUtc <= nowUtc)
            .ToListAsync(cancellationToken);

        var completedReservations = new List<(string UserId, string ReservationCode, string FlightNumber)>();

        foreach (var reservation in reservations)
        {
            if (_stateMachine.TryAutoCompleteAfterArrival(reservation, SystemActorUserId, nowUtc))
            {
                completedReservations.Add((reservation.UserId, reservation.ReservationCode, reservation.Flight.FlightNumber));
            }
        }

        if (expiredReservationNotifications.Count == 0 && completedReservations.Count == 0)
        {
            return;
        }

        await _dbContext.SaveChangesAsync(cancellationToken);
        _logger.LogInformation(
            "{ExpiredReservationCount} pending reservations expired and {CompletedReservationCount} reservations automatically marked as completed.",
            expiredReservationNotifications.Count,
            completedReservations.Count);

        foreach (var reservation in completedReservations)
        {
            await PublishCompletionNotificationSafelyAsync(
                reservation.UserId,
                reservation.ReservationCode,
                reservation.FlightNumber,
                nowUtc,
                cancellationToken);
        }

        foreach (var reservation in expiredReservationNotifications)
        {
            await PublishExpirationNotificationSafelyAsync(
                reservation.UserId,
                reservation.ReservationCode,
                reservation.FlightNumber,
                nowUtc,
                cancellationToken);
        }
    }

    public ReservationStatus GetEffectiveStatus(
        ReservationStatus status,
        PaymentStatus? paymentStatus,
        DateTime arrivalAtUtc,
        DateTime nowUtc)
    {
        return _stateMachine.GetEffectiveStatus(status, paymentStatus, arrivalAtUtc, nowUtc);
    }

    private async Task PublishCompletionNotificationSafelyAsync(
        string userId,
        string reservationCode,
        string flightNumber,
        DateTime occurredAtUtc,
        CancellationToken cancellationToken)
    {
        var message = new NotificationRequestedMessage
        {
            UserId = userId,
            Title = "Putovanje zavrseno",
            Body = $"Rezervacija {reservationCode} za let {flightNumber} je automatski oznacena kao zavrsena jer je let stigao.",
            OccurredAtUtc = occurredAtUtc
        };

        try
        {
            await _notificationEventPublisher.PublishAsync(message, cancellationToken);
        }
        catch (Exception exception)
        {
            _logger.LogError(
                exception,
                "Failed to publish reservation completion notification for reservation {ReservationCode}.",
                reservationCode);
        }
    }

    private async Task PublishExpirationNotificationSafelyAsync(
        string userId,
        string reservationCode,
        string flightNumber,
        DateTime occurredAtUtc,
        CancellationToken cancellationToken)
    {
        var message = new NotificationRequestedMessage
        {
            UserId = userId,
            Title = "Rezervacija istekla",
            Body = $"Rezervacija {reservationCode} za let {flightNumber} je otkazana jer placanje nije zavrseno na vrijeme.",
            OccurredAtUtc = occurredAtUtc
        };

        try
        {
            await _notificationEventPublisher.PublishAsync(message, cancellationToken);
        }
        catch (Exception exception)
        {
            _logger.LogError(
                exception,
                "Failed to publish reservation expiration notification for reservation {ReservationCode}.",
                reservationCode);
        }
    }
}
