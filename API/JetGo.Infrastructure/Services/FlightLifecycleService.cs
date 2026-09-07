using System.Globalization;
using JetGo.Application.Contracts.Messaging;
using JetGo.Application.Exceptions;
using JetGo.Application.Messaging.Notifications;
using JetGo.Domain.Entities;
using JetGo.Domain.Enums;
using JetGo.Infrastructure.Payments;
using Microsoft.Extensions.Logging;

namespace JetGo.Infrastructure.Services;

public sealed class FlightLifecycleService
{
    private readonly INotificationEventPublisher _notificationEventPublisher;
    private readonly PayPalCheckoutClient _payPalCheckoutClient;
    private readonly ReservationStateMachine _reservationStateMachine;
    private readonly ILogger<FlightLifecycleService> _logger;

    public FlightLifecycleService(
        INotificationEventPublisher notificationEventPublisher,
        PayPalCheckoutClient payPalCheckoutClient,
        ReservationStateMachine reservationStateMachine,
        ILogger<FlightLifecycleService> logger)
    {
        _notificationEventPublisher = notificationEventPublisher;
        _payPalCheckoutClient = payPalCheckoutClient;
        _reservationStateMachine = reservationStateMachine;
        _logger = logger;
    }

    public async Task<IReadOnlyCollection<NotificationRequestedMessage>> ChangeStatusAsync(
        Flight flight,
        FlightStatus requestedStatus,
        string actorUserId,
        DateTime nowUtc,
        CancellationToken cancellationToken)
    {
        var currentEffectiveStatus = GetEffectiveStatus(flight.Status, flight.ArrivalAtUtc, nowUtc);
        ValidateTransition(flight, currentEffectiveStatus, requestedStatus, nowUtc);

        if (flight.Status == requestedStatus)
        {
            return requestedStatus switch
            {
                FlightStatus.Cancelled => await CancelActiveReservationsAsync(flight, actorUserId, nowUtc, cancellationToken),
                FlightStatus.Completed => CompleteActiveReservationsAsync(flight, actorUserId, nowUtc),
                _ => []
            };
        }

        flight.Status = requestedStatus;
        flight.UpdatedAtUtc = nowUtc;

        return requestedStatus switch
        {
            FlightStatus.Cancelled => await CancelActiveReservationsAsync(flight, actorUserId, nowUtc, cancellationToken),
            FlightStatus.Completed => CompleteActiveReservationsAsync(flight, actorUserId, nowUtc),
            FlightStatus.Delayed => BuildStatusChangeNotifications(flight, "Let odgodjen", "Let je oznacen kao odgodjen.", nowUtc),
            FlightStatus.Scheduled => BuildStatusChangeNotifications(flight, "Let zakazan", "Let je oznacen kao zakazan.", nowUtc),
            _ => []
        };
    }

    public IReadOnlyCollection<NotificationRequestedMessage> BuildTimeChangeNotifications(
        Flight flight,
        DateTime previousDepartureAtUtc,
        DateTime previousArrivalAtUtc,
        DateTime occurredAtUtc)
    {
        if (previousDepartureAtUtc == flight.DepartureAtUtc && previousArrivalAtUtc == flight.ArrivalAtUtc)
        {
            return [];
        }

        var body =
            $"Vrijeme leta {flight.FlightNumber} je promijenjeno. " +
            $"Prethodni polazak: {FormatUtc(previousDepartureAtUtc)}, novi polazak: {FormatUtc(flight.DepartureAtUtc)}. " +
            $"Prethodni dolazak: {FormatUtc(previousArrivalAtUtc)}, novi dolazak: {FormatUtc(flight.ArrivalAtUtc)}.";

        return flight.Reservations
            .Where(x => x.Status is ReservationStatus.Pending or ReservationStatus.Confirmed)
            .Select(x => CreateFlightNotification(
                x,
                flight,
                NotificationType.FlightTimeChanged,
                "Promjena vremena leta",
                $"{body} Rezervacija: {x.ReservationCode}.",
                occurredAtUtc))
            .ToArray();
    }

    public async Task PublishNotificationsSafelyAsync(
        IEnumerable<NotificationRequestedMessage> notifications,
        CancellationToken cancellationToken)
    {
        foreach (var notification in notifications)
        {
            try
            {
                await _notificationEventPublisher.PublishAsync(notification, cancellationToken);
            }
            catch (Exception exception)
            {
                _logger.LogError(
                    exception,
                    "Failed to publish flight lifecycle notification {Title} for user {UserId}.",
                    notification.Title,
                    notification.UserId);
            }
        }
    }

    public static FlightStatus GetEffectiveStatus(FlightStatus status, DateTime arrivalAtUtc, DateTime nowUtc)
    {
        if (status is FlightStatus.Cancelled or FlightStatus.Completed)
        {
            return status;
        }

        return arrivalAtUtc <= nowUtc ? FlightStatus.Completed : status;
    }

    public static FlightActionAvailability GetReservationAvailability(Flight flight, DateTime nowUtc)
    {
        var customerActionAvailability = GetCustomerActionAvailability(flight, nowUtc);

        if (!customerActionAvailability.IsAllowed)
        {
            return customerActionAvailability;
        }

        if (flight.AvailableSeats <= 0)
        {
            return FlightActionAvailability.Blocked("Na letu vise nema slobodnih sjedista.");
        }

        return FlightActionAvailability.Allowed;
    }

    public static FlightActionAvailability GetCustomerActionAvailability(Flight flight, DateTime nowUtc)
    {
        return GetCustomerActionAvailability(
            flight.Status,
            flight.DepartureAtUtc,
            flight.ArrivalAtUtc,
            nowUtc,
            flight.Airline?.IsActive ?? true,
            flight.Destination?.IsActive ?? true);
    }

    public static FlightActionAvailability GetCustomerActionAvailability(
        FlightStatus status,
        DateTime departureAtUtc,
        DateTime arrivalAtUtc,
        DateTime nowUtc,
        bool airlineIsActive,
        bool destinationIsActive)
    {
        if (!airlineIsActive)
        {
            return FlightActionAvailability.Blocked("Let nije dostupan jer aviokompanija vise nije aktivna.");
        }

        if (!destinationIsActive)
        {
            return FlightActionAvailability.Blocked("Let nije dostupan jer destinacija vise nije aktivna.");
        }

        var effectiveStatus = GetEffectiveStatus(status, arrivalAtUtc, nowUtc);

        if (effectiveStatus == FlightStatus.Cancelled)
        {
            return FlightActionAvailability.Blocked("Otkazan let se ne moze rezervisati niti platiti.");
        }

        if (effectiveStatus == FlightStatus.Completed)
        {
            return FlightActionAvailability.Blocked("Zavrsen let se ne moze rezervisati niti platiti.");
        }

        if (effectiveStatus is not (FlightStatus.Scheduled or FlightStatus.Delayed))
        {
            return FlightActionAvailability.Blocked("Let trenutno nije dostupan za rezervaciju.");
        }

        if (departureAtUtc <= nowUtc)
        {
            return FlightActionAvailability.Blocked("Rezervacija i placanje nisu dostupni nakon vremena polaska leta.");
        }

        if (arrivalAtUtc <= nowUtc)
        {
            return FlightActionAvailability.Blocked("Let je zavrsen i vise nije dostupan za rezervaciju.");
        }

        return FlightActionAvailability.Allowed;
    }

    private async Task<IReadOnlyCollection<NotificationRequestedMessage>> CancelActiveReservationsAsync(
        Flight flight,
        string actorUserId,
        DateTime nowUtc,
        CancellationToken cancellationToken)
    {
        var notifications = new List<NotificationRequestedMessage>();

        foreach (var reservation in flight.Reservations.Where(x => x.Status is not ReservationStatus.Cancelled and not ReservationStatus.Completed))
        {
            var reason = $"Let {flight.FlightNumber} je otkazan.";
            var payment = reservation.Payment;
            var notificationBody = $"Let {flight.FlightNumber} za rezervaciju {reservation.ReservationCode} je otkazan.";

            if (payment is not null)
            {
                PaymentService.EnsureLedgerHasCurrentPaidCapture(payment, nowUtc);
            }

            var refundableAmount = payment is null ? 0m : PaymentLedger.CalculateNetPaidAmount(payment);

            if (payment is not null && refundableAmount > 0m)
            {
                await RefundPaidReservationAsync(payment, refundableAmount, reservation.ReservationCode, reason, nowUtc, cancellationToken);
                _reservationStateMachine.CancelAfterRefund(reservation, actorUserId, reason, nowUtc);
                notificationBody += " Placanje je automatski refundirano kroz PayPal sandbox.";
            }
            else
            {
                _reservationStateMachine.Cancel(reservation, actorUserId, reason, nowUtc, hasCompletedPayment: false);

                if (payment?.Status == PaymentStatus.Pending)
                {
                    PaymentService.FailPendingChargeTransactions(payment, "Placanje je zaustavljeno jer je let otkazan.", nowUtc);
                    payment.Status = PaymentStatus.Failed;
                    payment.StatusReason = "Placanje je zaustavljeno jer je let otkazan.";
                    payment.UpdatedAtUtc = nowUtc;
                    notificationBody += " Pokrenuto placanje je zaustavljeno jer let vise nije dostupan.";
                }
            }

            var releasedSeats = ReleaseReservedSeats(flight, reservation);
            _logger.LogInformation(
                "Flight {FlightId} cancellation released {ReleasedSeatCount} seats for reservation {ReservationId}.",
                flight.Id,
                releasedSeats,
                reservation.Id);

            notifications.Add(CreateFlightNotification(
                reservation,
                flight,
                NotificationType.FlightStatusChanged,
                "Let otkazan",
                notificationBody,
                nowUtc));
        }

        return notifications;
    }

    private IReadOnlyCollection<NotificationRequestedMessage> CompleteActiveReservationsAsync(
        Flight flight,
        string actorUserId,
        DateTime nowUtc)
    {
        var notifications = new List<NotificationRequestedMessage>();

        foreach (var reservation in flight.Reservations.Where(x => x.Status is not ReservationStatus.Cancelled and not ReservationStatus.Completed))
        {
            if (reservation.Payment?.Status == PaymentStatus.Paid)
            {
                _reservationStateMachine.Complete(
                    reservation,
                    actorUserId,
                    $"Rezervacija je zavrsena jer je let {flight.FlightNumber} oznacen kao zavrsen.",
                    nowUtc);
                reservation.UpdatedAtUtc = nowUtc;

                notifications.Add(CreateFlightNotification(
                    reservation,
                    flight,
                    NotificationType.FlightStatusChanged,
                    "Putovanje zavrseno",
                    $"Rezervacija {reservation.ReservationCode} za let {flight.FlightNumber} je oznacena kao zavrsena.",
                    nowUtc));

                continue;
            }

            _reservationStateMachine.Cancel(
                reservation,
                actorUserId,
                $"Rezervacija je otkazana jer je let {flight.FlightNumber} zavrsen prije placanja.",
                nowUtc,
                hasCompletedPayment: false);

            if (reservation.Payment?.Status == PaymentStatus.Pending)
            {
                PaymentService.FailPendingChargeTransactions(
                    reservation.Payment,
                    "Placanje je zaustavljeno jer je let zavrsen prije finalizacije placanja.",
                    nowUtc);
                reservation.Payment.Status = PaymentStatus.Failed;
                reservation.Payment.StatusReason = "Placanje je zaustavljeno jer je let zavrsen prije finalizacije placanja.";
                reservation.Payment.UpdatedAtUtc = nowUtc;
            }

            ReleaseReservedSeats(flight, reservation);

            notifications.Add(CreateFlightNotification(
                reservation,
                flight,
                NotificationType.FlightStatusChanged,
                "Rezervacija otkazana",
                $"Rezervacija {reservation.ReservationCode} za let {flight.FlightNumber} je otkazana jer let vise nije aktivan.",
                nowUtc));
        }

        return notifications;
    }

    private IReadOnlyCollection<NotificationRequestedMessage> BuildStatusChangeNotifications(
        Flight flight,
        string title,
        string body,
        DateTime occurredAtUtc)
    {
        return flight.Reservations
            .Where(x => x.Status is ReservationStatus.Pending or ReservationStatus.Confirmed)
            .Select(x => CreateFlightNotification(
                x,
                flight,
                NotificationType.FlightStatusChanged,
                title,
                $"{body} Rezervacija: {x.ReservationCode}, let: {flight.FlightNumber}.",
                occurredAtUtc))
            .ToArray();
    }

    private async Task RefundPaidReservationAsync(
        Payment payment,
        decimal refundableAmount,
        string reservationCode,
        string reason,
        DateTime nowUtc,
        CancellationToken cancellationToken)
    {
        var refundableCaptures = PaymentLedger.GetRefundableCaptures(payment);

        if (refundableCaptures.Count == 0)
        {
            throw new ConflictException("Let ima placenu rezervaciju bez PayPal capture identifikatora, pa automatski refund nije moguc.");
        }

        var remainingAmount = refundableAmount;
        var refundedAtUtc = nowUtc;

        foreach (var capture in refundableCaptures)
        {
            if (remainingAmount <= 0m)
            {
                break;
            }

            var refundAmount = Math.Min(capture.Amount, remainingAmount);

            if (refundAmount <= 0m)
            {
                continue;
            }

            var refundResponse = await _payPalCheckoutClient.RefundCaptureAsync(
                capture.CaptureId,
                refundAmount,
                capture.Currency,
                reservationCode,
                cancellationToken);

            refundedAtUtc = refundResponse.CreateTime?.ToUniversalTime() ?? nowUtc;
            payment.Transactions.Add(new PaymentTransaction
            {
                Type = PaymentTransactionType.FullRefund,
                Status = PaymentTransactionStatus.Completed,
                Provider = "PayPal",
                ProviderReference = refundResponse.Id,
                RelatedProviderReference = capture.CaptureId,
                Amount = refundAmount,
                Currency = capture.Currency,
                CompletedAtUtc = refundedAtUtc,
                Note = $"Automatski refund zbog otkazivanja leta. Razlog: {reason}",
                CreatedAtUtc = nowUtc,
                UpdatedAtUtc = nowUtc
            });

            remainingAmount = decimal.Round(remainingAmount - refundAmount, 2, MidpointRounding.AwayFromZero);
        }

        if (remainingAmount > 0m)
        {
            throw new ConflictException("Nije moguce automatski refundirati placanje jer capture zapisi nemaju dovoljan preostali iznos.");
        }

        PaymentService.FailPendingChargeTransactions(payment, "Placanje je zaustavljeno jer je let otkazan.", nowUtc);
        payment.Status = PaymentStatus.Refunded;
        payment.Amount = 0m;
        payment.RefundedAtUtc = refundedAtUtc;
        payment.StatusReason = $"Automatski refund zbog otkazivanja leta. Razlog: {reason}";
        payment.UpdatedAtUtc = nowUtc;
    }

    private static NotificationRequestedMessage CreateFlightNotification(
        Reservation reservation,
        Flight flight,
        NotificationType type,
        string title,
        string body,
        DateTime occurredAtUtc)
    {
        return new NotificationRequestedMessage
        {
            UserId = reservation.UserId,
            Type = type,
            Title = title,
            Body = body,
            OccurredAtUtc = occurredAtUtc,
            FlightId = flight.Id,
            FlightNumber = flight.FlightNumber,
            ReservationId = reservation.Id,
            ReservationCode = reservation.ReservationCode
        };
    }

    private static string FormatUtc(DateTime value)
    {
        return value.ToUniversalTime().ToString("dd.MM.yyyy HH:mm 'UTC'", CultureInfo.InvariantCulture);
    }

    private static int ReleaseReservedSeats(Flight flight, Reservation reservation)
    {
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

        flight.AvailableSeats = Math.Min(
            flight.TotalSeats,
            flight.AvailableSeats + releasedSeats);

        return releasedSeats;
    }

    private static void ValidateTransition(
        Flight flight,
        FlightStatus currentEffectiveStatus,
        FlightStatus requestedStatus,
        DateTime nowUtc)
    {
        if (currentEffectiveStatus == FlightStatus.Cancelled && requestedStatus != FlightStatus.Cancelled)
        {
            throw new ValidationException(
                "Otkazan let se ne moze ponovo aktivirati.",
                new Dictionary<string, string[]>
                {
                    ["status"] = ["Kreirajte novi let umjesto ponovnog aktiviranja otkazanog leta."]
                });
        }

        if (currentEffectiveStatus == FlightStatus.Completed && requestedStatus != FlightStatus.Completed)
        {
            throw new ValidationException(
                "Zavrsen let se ne moze vratiti u aktivan status.",
                new Dictionary<string, string[]>
                {
                    ["status"] = ["Let koji je zavrsen vise ne moze biti zakazan ili odgodjen."]
                });
        }

        if (requestedStatus == FlightStatus.Completed && flight.ArrivalAtUtc > nowUtc)
        {
            throw new ValidationException(
                "Let se ne moze oznaciti kao zavrsen prije planiranog dolaska.",
                new Dictionary<string, string[]>
                {
                    ["status"] = ["Status Completed je dozvoljen tek nakon vremena dolaska leta."]
                });
        }
    }
}

public sealed record FlightActionAvailability(bool IsAllowed, string? Reason)
{
    public static FlightActionAvailability Allowed { get; } = new(true, null);

    public static FlightActionAvailability Blocked(string reason) => new(false, reason);
}
