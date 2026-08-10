using JetGo.Application.Contracts.Messaging;
using JetGo.Application.Messaging.Notifications;
using JetGo.Domain.Enums;
using JetGo.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace JetGo.Infrastructure.Services;

public sealed class ReservationStatusSyncService
{
    private const string SystemActorUserId = "system:auto-complete";

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
        var reservations = await _dbContext.Reservations
            .Include(x => x.Flight)
            .Where(x =>
                (x.Status == ReservationStatus.Pending || x.Status == ReservationStatus.Confirmed) &&
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

        if (completedReservations.Count == 0)
        {
            return;
        }

        await _dbContext.SaveChangesAsync(cancellationToken);
        _logger.LogInformation("{ReservationCount} reservations automatically marked as completed.", completedReservations.Count);

        foreach (var reservation in completedReservations)
        {
            await PublishCompletionNotificationSafelyAsync(
                reservation.UserId,
                reservation.ReservationCode,
                reservation.FlightNumber,
                nowUtc,
                cancellationToken);
        }
    }

    public ReservationStatus GetEffectiveStatus(ReservationStatus status, DateTime arrivalAtUtc, DateTime nowUtc)
    {
        return _stateMachine.GetEffectiveStatus(status, arrivalAtUtc, nowUtc);
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
}
