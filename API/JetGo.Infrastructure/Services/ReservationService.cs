using System.Globalization;
using System.Security.Claims;
using JetGo.Application.Configuration;
using JetGo.Application.Constants;
using JetGo.Application.Contracts.Messaging;
using JetGo.Application.Contracts.Services;
using JetGo.Application.DTOs.Common;
using JetGo.Application.DTOs.Reservations;
using JetGo.Application.Exceptions;
using JetGo.Application.Messaging.Notifications;
using JetGo.Application.Requests.Reservations;
using JetGo.Domain.Entities;
using JetGo.Domain.Enums;
using JetGo.Infrastructure.Payments;
using JetGo.Infrastructure.Persistence;
using JetGo.Infrastructure.Services.Common;
using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace JetGo.Infrastructure.Services;

public sealed class ReservationService : IReservationService
{
    private const int RefundLeadTimeHours = 48;

    private readonly JetGoDbContext _dbContext;
    private readonly IHttpContextAccessor _httpContextAccessor;
    private readonly ReservationStateMachine _stateMachine;
    private readonly ReservationStatusSyncService _reservationStatusSyncService;
    private readonly INotificationEventPublisher _notificationEventPublisher;
    private readonly PayPalCheckoutClient _payPalCheckoutClient;
    private readonly PayPalSettings _payPalSettings;
    private readonly ILogger<ReservationService> _logger;

    public ReservationService(
        JetGoDbContext dbContext,
        IHttpContextAccessor httpContextAccessor,
        ReservationStateMachine stateMachine,
        ReservationStatusSyncService reservationStatusSyncService,
        INotificationEventPublisher notificationEventPublisher,
        PayPalCheckoutClient payPalCheckoutClient,
        PayPalSettings payPalSettings,
        ILogger<ReservationService> logger)
    {
        _dbContext = dbContext;
        _httpContextAccessor = httpContextAccessor;
        _stateMachine = stateMachine;
        _reservationStatusSyncService = reservationStatusSyncService;
        _notificationEventPublisher = notificationEventPublisher;
        _payPalCheckoutClient = payPalCheckoutClient;
        _payPalSettings = payPalSettings;
        _logger = logger;
    }

    public async Task<ReservationDetailsDto> CreateAsync(CreateReservationRequest request, CancellationToken cancellationToken = default)
    {
        var currentUserId = GetRequiredCurrentUserId();
        var nowUtc = DateTime.UtcNow;
        await _reservationStatusSyncService.SyncCompletedReservationsAsync(nowUtc, cancellationToken);
        var normalizedSeatNumbers = NormalizeSeatNumbers(request.SeatNumbers);

        var flight = await _dbContext.Flights
            .Include(x => x.Airline)
            .Include(x => x.Destination)
                .ThenInclude(x => x.DepartureAirport)
            .Include(x => x.Destination)
                .ThenInclude(x => x.ArrivalAirport)
            .Include(x => x.Seats)
            .SingleOrDefaultAsync(x => x.Id == request.FlightId, cancellationToken);

        if (flight is null)
        {
            throw new NotFoundException($"Let sa ID vrijednoscu {request.FlightId} nije pronadjen.");
        }

        var reservationAvailability = FlightLifecycleService.GetReservationAvailability(flight, nowUtc);
        if (!reservationAvailability.IsAllowed)
        {
            throw new ValidationException(
                "Odabrani let trenutno nije dostupan za rezervaciju.",
                new Dictionary<string, string[]>
                {
                    ["flight"] = [reservationAvailability.Reason ?? "Rezervacija je dozvoljena samo za aktivan let prije vremena polaska."]
                });
        }

        var selectedSeats = flight.Seats
            .Where(x => normalizedSeatNumbers.Contains(x.SeatNumber))
            .ToList();

        if (selectedSeats.Count != normalizedSeatNumbers.Length)
        {
            throw new ValidationException(
                "Neka od odabranih sjedista nisu pronadjena za odabrani let.",
                new Dictionary<string, string[]>
                {
                    ["seatNumbers"] = ["Provjerite oznake sjedista i pokusajte ponovo."]
                });
        }

        var reservedSeats = selectedSeats
            .Where(x => x.IsReserved)
            .Select(x => x.SeatNumber)
            .OrderBy(x => x)
            .ToArray();

        if (reservedSeats.Length > 0)
        {
            throw new ConflictException($"Sjedista su vec rezervisana: {string.Join(", ", reservedSeats)}.");
        }

        if (flight.AvailableSeats < selectedSeats.Count)
        {
            throw new ValidationException(
                "Na odabranom letu nema dovoljno raspolozivih sjedista.",
                new Dictionary<string, string[]>
                {
                    ["flight"] = ["Broj raspolozivih sjedista se promijenio. Osvjezite podatke i pokusajte ponovo."]
                });
        }

        var reservation = new Reservation
        {
            ReservationCode = GenerateReservationCode(),
            UserId = currentUserId,
            FlightId = flight.Id,
            AdditionalBaggageCount = request.AdditionalBaggageCount,
            AdditionalBaggageUnitPrice = ReservationPricingConstants.AdditionalBaggagePricePerPiece,
            AdditionalBaggageTotalPrice = CalculateAdditionalBaggageTotal(request.AdditionalBaggageCount),
            Currency = "BAM"
        };

        reservation.TotalAmount =
            (flight.BasePrice * selectedSeats.Count) + reservation.AdditionalBaggageTotalPrice;

        _stateMachine.MarkCreated(reservation, currentUserId, nowUtc);

        foreach (var seat in selectedSeats)
        {
            reservation.Items.Add(new ReservationItem
            {
                FlightSeatId = seat.Id,
                Price = flight.BasePrice
            });

            seat.IsReserved = true;
        }

        flight.AvailableSeats -= selectedSeats.Count;

        await _dbContext.Reservations.AddAsync(reservation, cancellationToken);
        await _dbContext.SaveChangesAsync(cancellationToken);
        await PublishNotificationSafelyAsync(
            currentUserId,
            "Rezervacija kreirana",
            $"Rezervacija {reservation.ReservationCode} za let {flight.FlightNumber} je uspjesno kreirana i ceka zavrsetak placanja.",
            nowUtc,
            cancellationToken,
            NotificationType.ReservationCreated,
            flight.Id,
            flight.FlightNumber,
            reservation.Id,
            reservation.ReservationCode);

        _logger.LogInformation("Reservation {ReservationCode} created for user {UserId}.", reservation.ReservationCode, currentUserId);

        return await GetByIdAsync(reservation.Id, cancellationToken);
    }

    public async Task<PagedResponseDto<ReservationListItemDto>> GetMineAsync(ReservationSearchRequest request, CancellationToken cancellationToken = default)
    {
        ValidateSearchRequest(request);
        var currentUserId = GetRequiredCurrentUserId();
        return await GetPagedInternalAsync(request, currentUserId, false, cancellationToken);
    }

    public async Task<PagedResponseDto<ReservationListItemDto>> GetAdminPagedAsync(ReservationSearchRequest request, CancellationToken cancellationToken = default)
    {
        ValidateSearchRequest(request);
        EnsureCurrentUserIsAdmin();
        return await GetPagedInternalAsync(request, null, true, cancellationToken);
    }

    public async Task<ReservationDetailsDto> GetByIdAsync(int id, CancellationToken cancellationToken = default)
    {
        var isAdmin = CurrentUserIsAdmin();
        var currentUserId = GetRequiredCurrentUserId();
        await _reservationStatusSyncService.SyncCompletedReservationsAsync(DateTime.UtcNow, cancellationToken);

        var reservation = await BuildDetailsQuery()
            .SingleOrDefaultAsync(x => x.Id == id, cancellationToken);

        if (reservation is null)
        {
            throw new NotFoundException($"Rezervacija sa ID vrijednoscu {id} nije pronadjena.");
        }

        if (!isAdmin && reservation.Customer.UserId != currentUserId)
        {
            throw new ForbiddenException("Nemate pravo pristupa trazenoj rezervaciji.");
        }

        return BuildVisibleReservationDetails(reservation, isAdmin);
    }

    public async Task<ReservationDetailsDto> ChangeAsync(int id, ChangeReservationRequest request, CancellationToken cancellationToken = default)
    {
        EnsureCurrentUserIsAdmin();

        var actorUserId = GetRequiredCurrentUserId();
        var nowUtc = DateTime.UtcNow;
        var reason = NormalizeRequiredReason(
            request.Reason,
            "reason",
            "Unesite razlog izmjene rezervacije.");
        var normalizedSeatNumbers = NormalizeSeatNumbers(request.SeatNumbers);

        await _reservationStatusSyncService.SyncCompletedReservationsAsync(nowUtc, cancellationToken);

        var reservation = await _dbContext.Reservations
            .Include(x => x.Payment)
                .ThenInclude(x => x!.Transactions)
            .Include(x => x.Items)
                .ThenInclude(x => x.FlightSeat)
            .Include(x => x.Flight)
                .ThenInclude(x => x.Airline)
            .Include(x => x.Flight)
                .ThenInclude(x => x.Destination)
            .SingleOrDefaultAsync(x => x.Id == id, cancellationToken);

        if (reservation is null)
        {
            throw new NotFoundException($"Rezervacija sa ID vrijednoscu {id} nije pronadjena.");
        }

        var targetFlight = await _dbContext.Flights
            .Include(x => x.Airline)
            .Include(x => x.Destination)
            .Include(x => x.Seats)
            .SingleOrDefaultAsync(x => x.Id == request.FlightId, cancellationToken);

        if (targetFlight is null)
        {
            throw new NotFoundException($"Let sa ID vrijednoscu {request.FlightId} nije pronadjen.");
        }

        ValidateReservationCanBeChanged(reservation, nowUtc);
        ValidateTargetFlightForChange(reservation, targetFlight, nowUtc);

        var selectedSeats = GetSelectedSeatsForChange(reservation, targetFlight, normalizedSeatNumbers);
        var previousFlightNumber = reservation.Flight.FlightNumber;
        var previousTotalAmount = reservation.TotalAmount;
        var newBaggageTotalAmount = CalculateAdditionalBaggageTotal(request.AdditionalBaggageCount);
        var newTotalAmount = decimal.Round(
            (targetFlight.BasePrice * selectedSeats.Count) + newBaggageTotalAmount,
            2,
            MidpointRounding.AwayFromZero);

        var payment = reservation.Payment;

        if (payment?.Status == PaymentStatus.Refunded)
        {
            throw new ConflictException("Refundirana rezervacija se ne moze mijenjati.");
        }

        if (payment is not null)
        {
            PaymentService.EnsureLedgerHasCurrentPaidCapture(payment, nowUtc);
            PaymentService.FailPendingChargeTransactions(
                payment,
                "Prethodno pokrenuto placanje je zaustavljeno jer je administrator izmijenio rezervaciju.",
                nowUtc);
        }

        ApplyReservationChange(
            reservation,
            targetFlight,
            selectedSeats,
            request.AdditionalBaggageCount,
            newBaggageTotalAmount,
            newTotalAmount,
            nowUtc);

        var notificationTitle = "Rezervacija izmijenjena";
        var notificationBody =
            $"Rezervacija {reservation.ReservationCode} je izmijenjena. Novi let: {targetFlight.FlightNumber}, ukupan iznos: {newTotalAmount.ToString("0.00", CultureInfo.InvariantCulture)} {reservation.Currency}.";

        if (payment is null)
        {
            _stateMachine.MarkChangeRequiresPayment(
                reservation,
                actorUserId,
                $"Rezervacija je izmijenjena i ceka placanje. Razlog: {reason}",
                nowUtc);
        }
        else
        {
            var providerTotal = ConvertReservationAmountToProviderAmount(newTotalAmount, reservation.Currency);
            var netPaidAmount = PaymentLedger.CalculateNetPaidAmount(payment);
            var paymentDifference = decimal.Round(
                providerTotal.Amount - netPaidAmount,
                2,
                MidpointRounding.AwayFromZero);

            if (netPaidAmount <= 0m)
            {
                payment.Status = PaymentStatus.Failed;
                payment.Amount = 0m;
                payment.Currency = providerTotal.CurrencyCode;
                payment.StatusReason = "Placanje je potrebno ponovo pokrenuti jer je rezervacija izmijenjena prije naplate.";
                payment.UpdatedAtUtc = nowUtc;
                _stateMachine.MarkChangeRequiresPayment(
                    reservation,
                    actorUserId,
                    $"Rezervacija je izmijenjena i ceka placanje. Razlog: {reason}",
                    nowUtc);
            }
            else if (paymentDifference > 0m)
            {
                EnsurePayPalConfigured();
                var order = await _payPalCheckoutClient.CreateOrderAsync(
                    paymentDifference,
                    providerTotal.CurrencyCode,
                    reservation.ReservationCode,
                    BuildReservationChangePaymentDescription(reservation, paymentDifference, providerTotal.CurrencyCode),
                    BuildPayPalCallbackUrl(_payPalSettings.ReturnUrl, reservation.Id),
                    BuildPayPalCallbackUrl(_payPalSettings.CancelUrl, reservation.Id),
                    cancellationToken);

                payment.Status = PaymentStatus.Pending;
                payment.Provider = "PayPal";
                payment.ProviderReference = order.Id;
                payment.Amount = paymentDifference;
                payment.Currency = providerTotal.CurrencyCode;
                payment.StatusReason = $"Izmjena rezervacije zahtijeva doplatu {paymentDifference.ToString("0.00", CultureInfo.InvariantCulture)} {providerTotal.CurrencyCode}.";
                payment.RefundedAtUtc = null;
                payment.UpdatedAtUtc = nowUtc;
                payment.Transactions.Add(PaymentService.CreatePendingChargeTransaction(
                    PaymentTransactionType.AdditionalCharge,
                    order.Id,
                    paymentDifference,
                    providerTotal.CurrencyCode,
                    $"Doplata nakon izmjene rezervacije. Razlog: {reason}",
                    nowUtc));

                _stateMachine.MarkChangeRequiresPayment(
                    reservation,
                    actorUserId,
                    $"Rezervacija je izmijenjena i ceka doplatu. Razlog: {reason}",
                    nowUtc);
                notificationTitle = "Rezervacija izmijenjena - potrebna doplata";
                notificationBody += $" Potrebna je doplata {paymentDifference.ToString("0.00", CultureInfo.InvariantCulture)} {providerTotal.CurrencyCode} kroz PayPal.";
            }
            else if (paymentDifference < 0m)
            {
                EnsurePayPalConfigured();
                var refundAmount = Math.Abs(paymentDifference);
                var refundReason = $"Djelimicni refund nakon izmjene rezervacije. Razlog: {reason}";
                var refundedAtUtc = await RefundPaymentDifferenceAsync(
                    payment,
                    refundAmount,
                    refundReason,
                    nowUtc,
                    cancellationToken);

                payment.Status = PaymentStatus.Paid;
                payment.Amount = PaymentLedger.CalculateNetPaidAmount(payment);
                payment.Currency = providerTotal.CurrencyCode;
                payment.RefundedAtUtc = refundedAtUtc;
                payment.StatusReason = refundReason;
                payment.UpdatedAtUtc = nowUtc;
                _stateMachine.MarkChanged(
                    reservation,
                    actorUserId,
                    $"Rezervacija je izmijenjena i razlika cijene je refundirana. Razlog: {reason}",
                    nowUtc);
                notificationTitle = "Rezervacija izmijenjena - razlika refundirana";
                notificationBody += $" Razlika {refundAmount.ToString("0.00", CultureInfo.InvariantCulture)} {providerTotal.CurrencyCode} je refundirana kroz PayPal.";
            }
            else
            {
                payment.Status = PaymentStatus.Paid;
                payment.Amount = netPaidAmount;
                payment.Currency = providerTotal.CurrencyCode;
                payment.StatusReason = $"Rezervacija je izmijenjena bez razlike za doplatu ili refund. Razlog: {reason}";
                payment.UpdatedAtUtc = nowUtc;
                _stateMachine.MarkChanged(
                    reservation,
                    actorUserId,
                    $"Rezervacija je izmijenjena bez razlike u placanju. Razlog: {reason}",
                    nowUtc);
            }
        }

        await _dbContext.SaveChangesAsync(cancellationToken);
        await PublishNotificationSafelyAsync(
            reservation.UserId,
            notificationTitle,
            notificationBody,
            nowUtc,
            cancellationToken,
            NotificationType.ReservationChanged,
            targetFlight.Id,
            targetFlight.FlightNumber,
            reservation.Id,
            reservation.ReservationCode);

        _logger.LogInformation(
            "Reservation {ReservationCode} changed by admin {AdminUserId}: {PreviousFlightNumber} -> {NewFlightNumber}, {PreviousAmount} -> {NewAmount} {Currency}.",
            reservation.ReservationCode,
            actorUserId,
            previousFlightNumber,
            targetFlight.FlightNumber,
            previousTotalAmount,
            newTotalAmount,
            reservation.Currency);

        return await GetByIdAsync(reservation.Id, cancellationToken);
    }
    public async Task<ReservationDetailsDto> UpdateBaggageAsync(int id, UpdateReservationBaggageRequest request, CancellationToken cancellationToken = default)
    {
        var actorUserId = GetRequiredCurrentUserId();
        var isAdmin = CurrentUserIsAdmin();
        var nowUtc = DateTime.UtcNow;
        await _reservationStatusSyncService.SyncCompletedReservationsAsync(nowUtc, cancellationToken);

        var reservation = await _dbContext.Reservations
            .Include(x => x.Payment)
                .ThenInclude(x => x!.Transactions)
            .Include(x => x.Items)
            .Include(x => x.Flight)
                .ThenInclude(x => x.Airline)
            .Include(x => x.Flight)
                .ThenInclude(x => x.Destination)
            .SingleOrDefaultAsync(x => x.Id == id, cancellationToken);

        if (reservation is null)
        {
            throw new NotFoundException($"Rezervacija sa ID vrijednoscu {id} nije pronadjena.");
        }

        if (!isAdmin && reservation.UserId != actorUserId)
        {
            throw new ForbiddenException("Mozete mijenjati dodatni prtljag samo na vlastitoj rezervaciji.");
        }

        var effectiveStatus = GetEffectiveReservationStatus(
            reservation.Status,
            reservation.Payment?.Status,
            reservation.Flight.ArrivalAtUtc,
            nowUtc);

        if (effectiveStatus is ReservationStatus.Cancelled or ReservationStatus.Completed)
        {
            throw new ValidationException(
                "Dodatni prtljag nije moguce mijenjati za zavrsenu ili otkazanu rezervaciju.",
                new Dictionary<string, string[]>
                {
                    ["additionalBaggageCount"] = ["Dodatni prtljag mozete mijenjati samo dok je rezervacija aktivna."]
                });
        }

        var flightActionAvailability = FlightLifecycleService.GetCustomerActionAvailability(reservation.Flight, nowUtc);
        if (!flightActionAvailability.IsAllowed)
        {
            throw new ValidationException(
                "Dodatni prtljag trenutno nije moguce mijenjati.",
                new Dictionary<string, string[]>
                {
                    ["flight"] = [flightActionAvailability.Reason ?? "Izmjena dodatnog prtljaga je dozvoljena samo prije vremena polaska leta."]
                });
        }

        if (reservation.Payment is not null)
        {
            PaymentService.EnsureLedgerHasCurrentPaidCapture(reservation.Payment, nowUtc);
        }

        var hasCapturedPayment = reservation.Payment is not null &&
            PaymentLedger.CalculateNetPaidAmount(reservation.Payment) > 0m;

        if (hasCapturedPayment || reservation.Payment?.Status is PaymentStatus.Paid or PaymentStatus.Refunded)
        {
            throw new ConflictException("Dodatni prtljag nije moguce mijenjati nakon uspjesnog placanja ili refundacije.");
        }

        reservation.AdditionalBaggageCount = request.AdditionalBaggageCount;
        reservation.AdditionalBaggageUnitPrice = ReservationPricingConstants.AdditionalBaggagePricePerPiece;
        reservation.AdditionalBaggageTotalPrice = CalculateAdditionalBaggageTotal(request.AdditionalBaggageCount);
        reservation.TotalAmount = CalculateSeatsTotalAmount(reservation) + reservation.AdditionalBaggageTotalPrice;
        reservation.UpdatedAtUtc = nowUtc;

        if (reservation.Payment?.Status == PaymentStatus.Pending)
        {
            PaymentService.FailPendingChargeTransactions(
                reservation.Payment,
                "Prethodno PayPal placanje je ponisteno jer je izmijenjen dodatni prtljag.",
                nowUtc);
            reservation.Payment.Status = PaymentStatus.Failed;
            reservation.Payment.StatusReason =
                "Prethodno PayPal placanje je ponisteno jer je izmijenjen dodatni prtljag. Pokrenite placanje ponovo za novi iznos.";
            reservation.Payment.PaidAtUtc = null;
            reservation.Payment.RefundedAtUtc = null;
            reservation.Payment.UpdatedAtUtc = nowUtc;
        }

        await _dbContext.SaveChangesAsync(cancellationToken);
        await PublishNotificationSafelyAsync(
            reservation.UserId,
            "Dodatni prtljag azuriran",
            $"Rezervacija {reservation.ReservationCode} sada ima {request.AdditionalBaggageCount} dodatnih komada prtljaga.",
            nowUtc,
            cancellationToken,
            NotificationType.ReservationChanged,
            reservation.FlightId,
            reservation.Flight.FlightNumber,
            reservation.Id,
            reservation.ReservationCode);

        return await GetByIdAsync(id, cancellationToken);
    }

    public async Task<ReservationDetailsDto> CancelAsync(int id, UpdateReservationStatusRequest request, CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(request.Reason))
        {
            throw new ValidationException(
                "Razlog otkazivanja je obavezan.",
                new Dictionary<string, string[]>
                {
                    ["reason"] = ["Unesite razlog otkazivanja rezervacije."]
                });
        }

        var actorUserId = GetRequiredCurrentUserId();
        var isAdmin = CurrentUserIsAdmin();
        var nowUtc = DateTime.UtcNow;
        await _reservationStatusSyncService.SyncCompletedReservationsAsync(nowUtc, cancellationToken);

        var reservation = await _dbContext.Reservations
            .Include(x => x.Payment)
                .ThenInclude(x => x!.Transactions)
            .Include(x => x.Items)
                .ThenInclude(x => x.FlightSeat)
            .Include(x => x.Flight)
                .ThenInclude(x => x.Airline)
            .Include(x => x.Flight)
                .ThenInclude(x => x.Destination)
            .SingleOrDefaultAsync(x => x.Id == id, cancellationToken);

        if (reservation is null)
        {
            throw new NotFoundException($"Rezervacija sa ID vrijednoscu {id} nije pronadjena.");
        }

        if (!isAdmin && reservation.UserId != actorUserId)
        {
            throw new ForbiddenException("Mozete otkazati samo vlastitu rezervaciju.");
        }

        var effectiveStatus = GetEffectiveReservationStatus(
            reservation.Status,
            reservation.Payment?.Status,
            reservation.Flight.ArrivalAtUtc,
            nowUtc);

        if (effectiveStatus == ReservationStatus.Completed)
        {
            throw new ValidationException(
                "Rezervacija se ne moze otkazati nakon sto je let zavrsen.",
                new Dictionary<string, string[]>
                {
                    ["reservation"] = ["Otkazivanje nije dozvoljeno nakon planiranog dolaska leta."]
                });
        }

        var flightActionAvailability = FlightLifecycleService.GetCustomerActionAvailability(reservation.Flight, nowUtc);
        var flightAllowsUserActions = flightActionAvailability.IsAllowed;

        if (reservation.Payment is not null)
        {
            PaymentService.EnsureLedgerHasCurrentPaidCapture(reservation.Payment, nowUtc);
        }

        var hasCompletedPayment = reservation.Payment is not null &&
            PaymentLedger.CalculateNetPaidAmount(reservation.Payment) > 0m;

        if (!CanCancelReservation(
            effectiveStatus,
            flightAllowsUserActions,
            hasCompletedPayment,
            reservation.Payment?.Status))
        {
            throw new ValidationException(
                "Rezervaciju nije moguce otkazati u trenutnom stanju.",
                new Dictionary<string, string[]>
                {
                    ["reservation"] = ["Otkazivanje je dozvoljeno samo za aktivnu rezervaciju bez evidentiranog PayPal capture placanja. Za placenu rezervaciju koristite refund tok."]
                });
        }

        _stateMachine.Cancel(reservation, actorUserId, request.Reason, nowUtc, hasCompletedPayment);

        foreach (var item in reservation.Items)
        {
            item.FlightSeat.IsReserved = false;
        }

        reservation.Flight.AvailableSeats += reservation.Items.Count;

        if (reservation.Payment?.Status == PaymentStatus.Pending)
        {
            PaymentService.FailPendingChargeTransactions(
                reservation.Payment,
                "Rezervacija je otkazana prije finalizacije placanja.",
                nowUtc);
            reservation.Payment.Status = PaymentStatus.Failed;
            reservation.Payment.StatusReason = "Rezervacija je otkazana prije finalizacije placanja.";
            reservation.Payment.UpdatedAtUtc = nowUtc;
        }

        await _dbContext.SaveChangesAsync(cancellationToken);
        await PublishNotificationSafelyAsync(
            reservation.UserId,
            "Rezervacija otkazana",
            $"Rezervacija {reservation.ReservationCode} je otkazana. Razlog: {request.Reason.Trim()}",
            nowUtc,
            cancellationToken,
            NotificationType.ReservationCancelled,
            reservation.FlightId,
            reservation.Flight.FlightNumber,
            reservation.Id,
            reservation.ReservationCode);

        _logger.LogInformation("Reservation {ReservationCode} cancelled by {UserId}.", reservation.ReservationCode, actorUserId);

        return await GetByIdAsync(id, cancellationToken);
    }

    private async Task<PagedResponseDto<ReservationListItemDto>> GetPagedInternalAsync(
        ReservationSearchRequest request,
        string? userIdFilter,
        bool includeAllUsers,
        CancellationToken cancellationToken)
    {
        var nowUtc = DateTime.UtcNow;
        await _reservationStatusSyncService.SyncCompletedReservationsAsync(nowUtc, cancellationToken);
        var query = BuildListQuery(request, userIdFilter, includeAllUsers);
        var totalCount = await query.CountAsync(cancellationToken);

        var items = await query
            .OrderByDescending(x => x.CreatedAtUtc)
            .ThenByDescending(x => x.Id)
            .Skip((request.Page - 1) * request.PageSize)
            .Take(request.PageSize)
            .Select(x => new ReservationListItemDto
            {
                Id = x.Id,
                ReservationCode = x.ReservationCode,
                FlightId = x.FlightId,
                FlightNumber = x.Flight.FlightNumber,
                RouteCode = x.Flight.Destination.RouteCode,
                DepartureAirportCode = x.Flight.Destination.DepartureAirport.IataCode,
                ArrivalAirportCode = x.Flight.Destination.ArrivalAirport.IataCode,
                DepartureAtUtc = x.Flight.DepartureAtUtc,
                ArrivalAtUtc = x.Flight.ArrivalAtUtc,
                Status = x.Status == ReservationStatus.Confirmed &&
                    x.Payment != null &&
                    x.Payment.Status == PaymentStatus.Paid &&
                    x.Flight.ArrivalAtUtc <= nowUtc
                    ? ReservationStatus.Completed
                    : x.Status,
                TotalAmount = x.TotalAmount,
                Currency = x.Currency,
                PaymentId = x.Payment != null ? x.Payment.Id : null,
                PaymentStatus = x.Payment != null ? x.Payment.Status : null,
                IsPaid = x.Payment != null && x.Payment.Status == PaymentStatus.Paid,
                SeatsCount = x.Items.Count,
                AdditionalBaggageCount = x.AdditionalBaggageCount,
                CreatedAtUtc = x.CreatedAtUtc,
                CustomerName = _dbContext.UserProfiles
                    .Where(p => p.UserId == x.UserId)
                    .Select(p => p.FirstName + " " + p.LastName)
                    .FirstOrDefault() ?? string.Empty
            })
            .ToListAsync(cancellationToken);

        return PagedResponseBuilder.Build(items, request.Page, request.PageSize, totalCount);
    }

    private IQueryable<Reservation> BuildListQuery(ReservationSearchRequest request, string? userIdFilter, bool includeAllUsers)
    {
        var nowUtc = DateTime.UtcNow;
        var query = _dbContext.Reservations.AsNoTracking().AsQueryable();

        if (!includeAllUsers && !string.IsNullOrWhiteSpace(userIdFilter))
        {
            query = query.Where(x => x.UserId == userIdFilter);
        }

        if (request.Status.HasValue)
        {
            query = request.Status.Value switch
            {
                ReservationStatus.Completed => query.Where(x =>
                    x.Status == ReservationStatus.Completed ||
                    (x.Status == ReservationStatus.Confirmed &&
                        x.Payment != null &&
                        x.Payment.Status == PaymentStatus.Paid &&
                        x.Flight.ArrivalAtUtc <= nowUtc)),
                ReservationStatus.Cancelled => query.Where(x => x.Status == ReservationStatus.Cancelled),
                ReservationStatus.Confirmed => query.Where(x =>
                    x.Status == ReservationStatus.Confirmed &&
                    x.Flight.ArrivalAtUtc > nowUtc),
                ReservationStatus.Pending => query.Where(x =>
                    x.Status == ReservationStatus.Pending &&
                    x.Flight.ArrivalAtUtc > nowUtc),
                _ => query.Where(x => x.Status == request.Status.Value)
            };
        }

        if (request.FlightId.HasValue)
        {
            query = query.Where(x => x.FlightId == request.FlightId.Value);
        }

        if (request.CreatedFromUtc.HasValue)
        {
            query = query.Where(x => x.CreatedAtUtc >= request.CreatedFromUtc.Value);
        }

        if (request.CreatedToUtc.HasValue)
        {
            query = query.Where(x => x.CreatedAtUtc <= request.CreatedToUtc.Value);
        }

        if (!string.IsNullOrWhiteSpace(request.SearchText))
        {
            var searchText = request.SearchText.Trim();

            query = query.Where(x =>
                x.ReservationCode.Contains(searchText) ||
                x.Flight.FlightNumber.Contains(searchText) ||
                x.Flight.Destination.RouteCode.Contains(searchText) ||
                x.Flight.Destination.DepartureAirport.IataCode.Contains(searchText) ||
                x.Flight.Destination.ArrivalAirport.IataCode.Contains(searchText) ||
                (includeAllUsers && _dbContext.UserProfiles.Any(p =>
                    p.UserId == x.UserId &&
                    ((p.FirstName + " " + p.LastName).Contains(searchText) || p.Email.Contains(searchText)))));
        }

        return query;
    }

    private IQueryable<ReservationDetailsDto> BuildDetailsQuery()
    {
        return _dbContext.Reservations
            .AsNoTracking()
            .Select(x => new ReservationDetailsDto
            {
                Id = x.Id,
                ReservationCode = x.ReservationCode,
                FlightId = x.FlightId,
                FlightNumber = x.Flight.FlightNumber,
                RouteCode = x.Flight.Destination.RouteCode,
                DepartureAirportCode = x.Flight.Destination.DepartureAirport.IataCode,
                ArrivalAirportCode = x.Flight.Destination.ArrivalAirport.IataCode,
                DepartureAtUtc = x.Flight.DepartureAtUtc,
                ArrivalAtUtc = x.Flight.ArrivalAtUtc,
                FlightStatus = x.Flight.Status,
                FlightAirlineIsActive = x.Flight.Airline.IsActive,
                FlightDestinationIsActive = x.Flight.Destination.IsActive,
                Status = x.Status,
                TotalAmount = x.TotalAmount,
                Currency = x.Currency,
                SeatsTotalAmount = x.Items.Sum(i => i.Price),
                AdditionalBaggageCount = x.AdditionalBaggageCount,
                AdditionalBaggageUnitPrice = x.AdditionalBaggageUnitPrice,
                AdditionalBaggageTotalAmount = x.AdditionalBaggageTotalPrice,
                PaymentId = x.Payment != null ? x.Payment.Id : null,
                PaymentStatus = x.Payment != null ? x.Payment.Status : null,
                IsPaid = x.Payment != null && x.Payment.Status == PaymentStatus.Paid,
                HasCapturedPayment = x.Payment != null &&
                    (x.Payment.Status == PaymentStatus.Paid ||
                        x.Payment.Transactions.Any(t =>
                            t.Status == PaymentTransactionStatus.Completed &&
                            (t.Type == PaymentTransactionType.InitialPayment || t.Type == PaymentTransactionType.AdditionalCharge))),
                CreatedAtUtc = x.CreatedAtUtc,
                StatusChangedAtUtc = x.StatusChangedAtUtc,
                StatusChangedByUserId = x.StatusChangedByUserId,
                StatusReason = x.StatusReason,
                Customer = new ReservationCustomerDto
                {
                    UserId = x.UserId,
                    Username = _dbContext.Users
                        .Where(u => u.Id == x.UserId)
                        .Select(u => u.UserName ?? string.Empty)
                        .FirstOrDefault() ?? string.Empty,
                    FullName = _dbContext.UserProfiles
                        .Where(p => p.UserId == x.UserId)
                        .Select(p => p.FirstName + " " + p.LastName)
                        .FirstOrDefault() ?? string.Empty,
                    Email = _dbContext.UserProfiles
                        .Where(p => p.UserId == x.UserId)
                        .Select(p => p.Email)
                        .FirstOrDefault() ?? string.Empty
                },
                Seats = x.Items
                    .OrderBy(i => i.FlightSeat.SeatNumber)
                    .Select(i => new ReservationSeatDto
                    {
                        FlightSeatId = i.FlightSeatId,
                        SeatNumber = i.FlightSeat.SeatNumber,
                        Price = i.Price
                    })
                    .ToArray()
            });
    }

    private static void ValidateReservationCanBeChanged(Reservation reservation, DateTime nowUtc)
    {
        var effectiveStatus = GetEffectiveReservationStatus(
            reservation.Status,
            reservation.Payment?.Status,
            reservation.Flight.ArrivalAtUtc,
            nowUtc);

        if (effectiveStatus is ReservationStatus.Cancelled or ReservationStatus.Completed)
        {
            throw new ValidationException(
                "Zavrsena ili otkazana rezervacija se ne moze mijenjati.",
                new Dictionary<string, string[]>
                {
                    ["reservation"] = ["Izmjena je dozvoljena samo za aktivne rezervacije. Kreirajte novu rezervaciju ako je prethodna zavrsena ili otkazana."]
                });
        }
    }

    private static void ValidateTargetFlightForChange(Reservation reservation, Flight targetFlight, DateTime nowUtc)
    {
        if (targetFlight.DestinationId != reservation.Flight.DestinationId)
        {
            throw new ValidationException(
                "Rezervaciju je moguce prebaciti samo na drugi let za istu rutu.",
                new Dictionary<string, string[]>
                {
                    ["flightId"] = ["Odaberite let koji pripada istoj ruti kao trenutna rezervacija."]
                });
        }

        var targetFlightAvailability = FlightLifecycleService.GetCustomerActionAvailability(targetFlight, nowUtc);
        if (!targetFlightAvailability.IsAllowed)
        {
            throw new ValidationException(
                "Odabrani let nije dostupan za izmjenu rezervacije.",
                new Dictionary<string, string[]>
                {
                    ["flightId"] = [targetFlightAvailability.Reason ?? "Odaberite aktivan let prije vremena polaska."]
                });
        }
    }

    private static List<FlightSeat> GetSelectedSeatsForChange(
        Reservation reservation,
        Flight targetFlight,
        string[] normalizedSeatNumbers)
    {
        var selectedSeats = targetFlight.Seats
            .Where(x => normalizedSeatNumbers.Contains(x.SeatNumber))
            .ToList();

        if (selectedSeats.Count != normalizedSeatNumbers.Length)
        {
            throw new ValidationException(
                "Neka od odabranih sjedista nisu pronadjena za odabrani let.",
                new Dictionary<string, string[]>
                {
                    ["seatNumbers"] = ["Provjerite oznake sjedista i pokusajte ponovo."]
                });
        }

        var currentSeatIds = reservation.FlightId == targetFlight.Id
            ? reservation.Items.Select(x => x.FlightSeatId).ToHashSet()
            : new HashSet<int>();

        var unavailableSeats = selectedSeats
            .Where(x => x.IsReserved && !currentSeatIds.Contains(x.Id))
            .Select(x => x.SeatNumber)
            .OrderBy(x => x)
            .ToArray();

        if (unavailableSeats.Length > 0)
        {
            throw new ConflictException($"Sjedista su vec rezervisana: {string.Join(", ", unavailableSeats)}.");
        }

        var reusableSeatsCount = reservation.FlightId == targetFlight.Id
            ? reservation.Items.Count
            : 0;

        if (targetFlight.AvailableSeats + reusableSeatsCount < selectedSeats.Count)
        {
            throw new ValidationException(
                "Na odabranom letu nema dovoljno raspolozivih sjedista.",
                new Dictionary<string, string[]>
                {
                    ["seatNumbers"] = ["Broj raspolozivih sjedista se promijenio. Osvjezite podatke i pokusajte ponovo."]
                });
        }

        return selectedSeats;
    }

    private void ApplyReservationChange(
        Reservation reservation,
        Flight targetFlight,
        IReadOnlyCollection<FlightSeat> selectedSeats,
        int additionalBaggageCount,
        decimal additionalBaggageTotalAmount,
        decimal totalAmount,
        DateTime nowUtc)
    {
        var currentItems = reservation.Items.ToArray();
        var oldFlight = reservation.Flight;
        var releasedSeats = 0;

        foreach (var item in currentItems)
        {
            if (!item.FlightSeat.IsReserved)
            {
                continue;
            }

            item.FlightSeat.IsReserved = false;
            releasedSeats++;
        }

        oldFlight.AvailableSeats = Math.Min(oldFlight.TotalSeats, oldFlight.AvailableSeats + releasedSeats);
        _dbContext.ReservationItems.RemoveRange(currentItems);
        reservation.Items.Clear();

        foreach (var seat in selectedSeats)
        {
            reservation.Items.Add(new ReservationItem
            {
                FlightSeatId = seat.Id,
                FlightSeat = seat,
                Price = targetFlight.BasePrice
            });

            seat.IsReserved = true;
        }

        targetFlight.AvailableSeats = Math.Max(0, targetFlight.AvailableSeats - selectedSeats.Count);
        reservation.FlightId = targetFlight.Id;
        reservation.Flight = targetFlight;
        reservation.AdditionalBaggageCount = additionalBaggageCount;
        reservation.AdditionalBaggageUnitPrice = ReservationPricingConstants.AdditionalBaggagePricePerPiece;
        reservation.AdditionalBaggageTotalPrice = additionalBaggageTotalAmount;
        reservation.TotalAmount = totalAmount;
        reservation.Currency = "BAM";
        reservation.UpdatedAtUtc = nowUtc;
    }

    private async Task<DateTime> RefundPaymentDifferenceAsync(
        Payment payment,
        decimal amount,
        string reason,
        DateTime nowUtc,
        CancellationToken cancellationToken)
    {
        var refundableCaptures = PaymentLedger.GetRefundableCaptures(payment);

        if (refundableCaptures.Count == 0)
        {
            throw new ConflictException("Placanje nema PayPal capture zapis koji se moze djelimicno refundirati.");
        }

        var remainingAmount = amount;
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
                payment.Reservation.ReservationCode,
                cancellationToken);

            refundedAtUtc = refundResponse.CreateTime?.ToUniversalTime() ?? nowUtc;
            payment.Transactions.Add(new PaymentTransaction
            {
                Type = PaymentTransactionType.PartialRefund,
                Status = PaymentTransactionStatus.Completed,
                Provider = "PayPal",
                ProviderReference = refundResponse.Id,
                RelatedProviderReference = capture.CaptureId,
                Amount = refundAmount,
                Currency = capture.Currency,
                CompletedAtUtc = refundedAtUtc,
                Note = reason,
                CreatedAtUtc = nowUtc,
                UpdatedAtUtc = nowUtc
            });

            remainingAmount = decimal.Round(remainingAmount - refundAmount, 2, MidpointRounding.AwayFromZero);
        }

        if (remainingAmount > 0m)
        {
            throw new ConflictException("Nije moguce refundirati razliku jer evidentirani capture zapisi nemaju dovoljan preostali iznos.");
        }

        return refundedAtUtc;
    }

    private void EnsurePayPalConfigured()
    {
        if (_payPalSettings.IsConfigured)
        {
            return;
        }

        throw new ValidationException(
            "PayPal sandbox konfiguracija nije kompletna.",
            new Dictionary<string, string[]>
            {
                ["payment"] =
                [
                    "Postavite JETGO_PAYPAL_CLIENT_ID, JETGO_PAYPAL_CLIENT_SECRET, JETGO_PAYPAL_RETURN_URL i JETGO_PAYPAL_CANCEL_URL u .env prije testiranja stvarnog placanja."
                ]
            });
    }

    private ProviderPricing ConvertReservationAmountToProviderAmount(decimal reservationAmount, string reservationCurrency)
    {
        if (string.Equals(reservationCurrency, _payPalSettings.CurrencyCode, StringComparison.OrdinalIgnoreCase))
        {
            return new ProviderPricing(reservationAmount, _payPalSettings.CurrencyCode);
        }

        if (string.Equals(reservationCurrency, "BAM", StringComparison.OrdinalIgnoreCase))
        {
            var convertedAmount = Math.Round(
                reservationAmount / _payPalSettings.BamToCurrencyRate,
                2,
                MidpointRounding.AwayFromZero);

            return new ProviderPricing(convertedAmount, _payPalSettings.CurrencyCode);
        }

        throw new ValidationException(
            "Valuta rezervacije nije podrzana za PayPal sandbox integraciju.",
            new Dictionary<string, string[]>
            {
                ["payment"] = [$"Trenutno je podrzana samo konverzija iz BAM u {_payPalSettings.CurrencyCode} za PayPal sandbox placanja."]
            });
    }

    private static string BuildPayPalCallbackUrl(string baseUrl, int reservationId)
    {
        if (string.IsNullOrWhiteSpace(baseUrl))
        {
            return baseUrl;
        }

        var separator = baseUrl.Contains('?') ? "&" : "?";
        return $"{baseUrl}{separator}reservationId={reservationId}";
    }

    private static string BuildReservationChangePaymentDescription(Reservation reservation, decimal amount, string currency)
    {
        return $"Additional charge for reservation {reservation.ReservationCode}, flight {reservation.Flight.FlightNumber}: {amount.ToString("0.00", CultureInfo.InvariantCulture)} {currency}";
    }

    private static string NormalizeRequiredReason(string? value, string key, string message)
    {
        var trimmed = value?.Trim();

        if (!string.IsNullOrWhiteSpace(trimmed))
        {
            return trimmed;
        }

        throw new ValidationException(
            "Razlog je obavezan.",
            new Dictionary<string, string[]>
            {
                [key] = [message]
            });
    }
    private async Task PublishNotificationSafelyAsync(
        string userId,
        string title,
        string body,
        DateTime occurredAtUtc,
        CancellationToken cancellationToken,
        NotificationType type = NotificationType.System,
        int? flightId = null,
        string? flightNumber = null,
        int? reservationId = null,
        string? reservationCode = null)
    {
        var message = new NotificationRequestedMessage
        {
            UserId = userId,
            Type = type,
            Title = title,
            Body = body,
            OccurredAtUtc = occurredAtUtc,
            FlightId = flightId,
            FlightNumber = flightNumber,
            ReservationId = reservationId,
            ReservationCode = reservationCode
        };

        try
        {
            await _notificationEventPublisher.PublishAsync(message, cancellationToken);
        }
        catch (Exception exception)
        {
            _logger.LogError(
                exception,
                "Failed to publish notification event {Title} for user {UserId}.",
                title,
                userId);
        }
    }

    private static string[] NormalizeSeatNumbers(IEnumerable<string> seatNumbers)
    {
        var normalized = seatNumbers
            .Where(x => !string.IsNullOrWhiteSpace(x))
            .Select(x => x.Trim().ToUpperInvariant())
            .Distinct()
            .ToArray();

        if (normalized.Length == 0)
        {
            throw new ValidationException(
                "Morate odabrati najmanje jedno sjediste.",
                new Dictionary<string, string[]>
                {
                    ["seatNumbers"] = ["Odaberite najmanje jedno sjediste."]
                });
        }

        return normalized;
    }

    private static string GenerateReservationCode()
    {
        return $"RSV-{DateTime.UtcNow:yyyyMMddHHmmss}-{Guid.NewGuid():N}"[..28].ToUpperInvariant();
    }

    private static decimal CalculateAdditionalBaggageTotal(int additionalBaggageCount)
    {
        return additionalBaggageCount * ReservationPricingConstants.AdditionalBaggagePricePerPiece;
    }

    private static decimal CalculateSeatsTotalAmount(Reservation reservation)
    {
        return reservation.Items.Sum(x => x.Price);
    }

    private bool CanCancelReservation(
        ReservationStatus reservationStatus,
        bool flightAllowsUserActions,
        bool hasCapturedPayment,
        PaymentStatus? paymentStatus)
    {
        return flightAllowsUserActions &&
            _stateMachine.CanCancel(reservationStatus) &&
            !hasCapturedPayment &&
            paymentStatus is not PaymentStatus.Refunded;
    }

    private static bool CanInitiateReservationPayment(
        ReservationStatus reservationStatus,
        bool flightAllowsUserActions,
        bool isPaid,
        PaymentStatus? paymentStatus)
    {
        return flightAllowsUserActions &&
            reservationStatus == ReservationStatus.Pending &&
            !isPaid &&
            paymentStatus is not PaymentStatus.Refunded;
    }

    private static bool CanUpdateBaggage(
        ReservationStatus reservationStatus,
        PaymentStatus? paymentStatus,
        bool isPaid)
    {
        if (isPaid || paymentStatus is PaymentStatus.Paid or PaymentStatus.Refunded)
        {
            return false;
        }

        return reservationStatus is ReservationStatus.Pending or ReservationStatus.Confirmed;
    }

    private ReservationDetailsDto BuildVisibleReservationDetails(ReservationDetailsDto reservation, bool isAdmin)
    {
        var nowUtc = DateTime.UtcNow;
        var actualStatus = GetEffectiveReservationStatus(reservation.Status, reservation.PaymentStatus, reservation.ArrivalAtUtc, nowUtc);
        var flightActionAvailability = FlightLifecycleService.GetCustomerActionAvailability(
            reservation.FlightStatus,
            reservation.DepartureAtUtc,
            reservation.ArrivalAtUtc,
            nowUtc,
            reservation.FlightAirlineIsActive,
            reservation.FlightDestinationIsActive);
        var flightAllowsUserActions = flightActionAvailability.IsAllowed;
        var hasCapturedPayment = reservation.HasCapturedPayment || reservation.IsPaid;

        return new ReservationDetailsDto
        {
            Id = reservation.Id,
            ReservationCode = reservation.ReservationCode,
            FlightId = reservation.FlightId,
            FlightNumber = reservation.FlightNumber,
            RouteCode = reservation.RouteCode,
            DepartureAirportCode = reservation.DepartureAirportCode,
            ArrivalAirportCode = reservation.ArrivalAirportCode,
            DepartureAtUtc = reservation.DepartureAtUtc,
            ArrivalAtUtc = reservation.ArrivalAtUtc,
            FlightStatus = reservation.FlightStatus,
            Status = actualStatus,
            TotalAmount = reservation.TotalAmount,
            Currency = reservation.Currency,
            SeatsTotalAmount = reservation.SeatsTotalAmount,
            AdditionalBaggageCount = reservation.AdditionalBaggageCount,
            AdditionalBaggageUnitPrice = reservation.AdditionalBaggageUnitPrice,
            AdditionalBaggageTotalAmount = reservation.AdditionalBaggageTotalAmount,
            PaymentId = reservation.PaymentId,
            PaymentStatus = reservation.PaymentStatus,
            IsPaid = reservation.IsPaid,
            HasCapturedPayment = hasCapturedPayment,
            CreatedAtUtc = reservation.CreatedAtUtc,
            StatusChangedAtUtc = reservation.StatusChangedAtUtc,
            StatusChangedByUserId = reservation.StatusChangedByUserId,
            StatusReason = GetDisplayStatusReason(reservation.Status, actualStatus, reservation.StatusReason),
            Customer = reservation.Customer,
            Seats = reservation.Seats,
            CanBeCancelled = CanCancelReservation(
                actualStatus,
                flightAllowsUserActions,
                hasCapturedPayment,
                reservation.PaymentStatus),
            CanBeConfirmed = false,
            CanBeCompleted = false,
            CanInitiatePayment = CanInitiateReservationPayment(
                actualStatus,
                flightAllowsUserActions,
                reservation.IsPaid,
                reservation.PaymentStatus),
            CanBeRefunded =
                flightAllowsUserActions &&
                hasCapturedPayment &&
                (actualStatus is ReservationStatus.Pending or ReservationStatus.Confirmed) &&
                reservation.DepartureAtUtc >= nowUtc.AddHours(RefundLeadTimeHours),
            CanUpdateBaggage = flightAllowsUserActions &&
                !hasCapturedPayment &&
                CanUpdateBaggage(actualStatus, reservation.PaymentStatus, reservation.IsPaid),
            CanChangeReservation = isAdmin &&
                flightAllowsUserActions &&
                (actualStatus is ReservationStatus.Pending or ReservationStatus.Confirmed) &&
                reservation.PaymentStatus is not PaymentStatus.Refunded
        };
    }

    private static ReservationStatus GetEffectiveReservationStatus(
        ReservationStatus reservationStatus,
        PaymentStatus? paymentStatus,
        DateTime arrivalAtUtc,
        DateTime nowUtc)
    {
        return reservationStatus == ReservationStatus.Confirmed &&
            paymentStatus == PaymentStatus.Paid &&
            arrivalAtUtc <= nowUtc
            ? ReservationStatus.Completed
            : reservationStatus;
    }

    private static string? GetDisplayStatusReason(
        ReservationStatus storedReservationStatus,
        ReservationStatus effectiveReservationStatus,
        string? statusReason)
    {
        if (effectiveReservationStatus == ReservationStatus.Completed &&
            storedReservationStatus != ReservationStatus.Completed)
        {
            return "Putovanje je zavrseno jer je proslo planirano vrijeme dolaska leta.";
        }

        return statusReason;
    }

    private string GetRequiredCurrentUserId()
    {
        var httpContext = _httpContextAccessor.HttpContext ?? throw new UnauthorizedException("Prijava je obavezna za ovu akciju.");
        var userId = httpContext.User.FindFirstValue(ClaimTypes.NameIdentifier);

        if (string.IsNullOrWhiteSpace(userId))
        {
            throw new UnauthorizedException("Nije moguce odrediti trenutnog korisnika.");
        }

        return userId;
    }

    private bool CurrentUserIsAdmin()
    {
        var httpContext = _httpContextAccessor.HttpContext ?? throw new UnauthorizedException("Prijava je obavezna za ovu akciju.");
        return httpContext.User.IsInRole(RoleNames.Admin);
    }

    private void EnsureCurrentUserIsAdmin()
    {
        if (!CurrentUserIsAdmin())
        {
            throw new ForbiddenException("Samo administrator moze izvrsiti ovu akciju.");
        }
    }

    private static void ValidateSearchRequest(ReservationSearchRequest request)
    {
        if (request.CreatedFromUtc.HasValue && request.CreatedToUtc.HasValue && request.CreatedFromUtc > request.CreatedToUtc)
        {
            throw new ValidationException(
                "Raspon datuma kreiranja nije validan.",
                new Dictionary<string, string[]>
                {
                    ["createdToUtc"] = ["Datum 'CreatedToUtc' mora biti veci ili jednak datumu 'CreatedFromUtc'."]
                });
        }
    }

    private readonly record struct ProviderPricing(decimal Amount, string CurrencyCode);
}
