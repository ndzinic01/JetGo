using System.Globalization;
using System.Security.Claims;
using JetGo.Application.Configuration;
using JetGo.Application.Constants;
using JetGo.Application.Contracts.Messaging;
using JetGo.Application.Contracts.Services;
using JetGo.Application.DTOs.Common;
using JetGo.Application.DTOs.Payments;
using JetGo.Application.Exceptions;
using JetGo.Application.Messaging.Notifications;
using JetGo.Application.Requests.Payments;
using JetGo.Domain.Entities;
using JetGo.Domain.Enums;
using JetGo.Infrastructure.Payments;
using JetGo.Infrastructure.Persistence;
using JetGo.Infrastructure.Services.Common;
using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace JetGo.Infrastructure.Services;

public sealed class PaymentService : IPaymentService
{
    private const string DefaultProvider = "PayPal";
    private const int RefundLeadTimeHours = 48;

    private readonly JetGoDbContext _dbContext;
    private readonly IHttpContextAccessor _httpContextAccessor;
    private readonly INotificationEventPublisher _notificationEventPublisher;
    private readonly ReservationStateMachine _stateMachine;
    private readonly ReservationStatusSyncService _reservationStatusSyncService;
    private readonly PayPalCheckoutClient _payPalCheckoutClient;
    private readonly PayPalSettings _payPalSettings;
    private readonly ILogger<PaymentService> _logger;

    public PaymentService(
        JetGoDbContext dbContext,
        IHttpContextAccessor httpContextAccessor,
        INotificationEventPublisher notificationEventPublisher,
        ReservationStateMachine stateMachine,
        ReservationStatusSyncService reservationStatusSyncService,
        PayPalCheckoutClient payPalCheckoutClient,
        PayPalSettings payPalSettings,
        ILogger<PaymentService> logger)
    {
        _dbContext = dbContext;
        _httpContextAccessor = httpContextAccessor;
        _notificationEventPublisher = notificationEventPublisher;
        _stateMachine = stateMachine;
        _reservationStatusSyncService = reservationStatusSyncService;
        _payPalCheckoutClient = payPalCheckoutClient;
        _payPalSettings = payPalSettings;
        _logger = logger;
    }

    public async Task<PaymentDetailsDto> InitializeAsync(int reservationId, CancellationToken cancellationToken = default)
    {
        EnsurePayPalConfigured();

        var currentUserId = GetRequiredCurrentUserId();
        var isAdmin = CurrentUserIsAdmin();
        var nowUtc = DateTime.UtcNow;
        await _reservationStatusSyncService.SyncCompletedReservationsAsync(nowUtc, cancellationToken);

        var reservation = await _dbContext.Reservations
            .Include(x => x.Payment)
                .ThenInclude(x => x!.Transactions)
            .Include(x => x.Flight)
                .ThenInclude(x => x.Destination)
            .SingleOrDefaultAsync(x => x.Id == reservationId, cancellationToken);

        if (reservation is null)
        {
            throw new NotFoundException($"Rezervacija sa ID vrijednoscu {reservationId} nije pronadjena.");
        }

        if (!isAdmin && reservation.UserId != currentUserId)
        {
            throw new ForbiddenException("Mozete inicirati placanje samo za vlastitu rezervaciju.");
        }

        EnsureReservationCanReceivePayment(reservation);

        if (reservation.Payment is not null)
        {
            switch (reservation.Payment.Status)
            {
                case PaymentStatus.Paid:
                    throw new ConflictException("Placanje za odabranu rezervaciju je vec uspjesno zavrseno.");
                case PaymentStatus.Pending:
                {
                    var approvalUrl = await TryResolveApprovalUrlAsync(reservation.Payment.ProviderReference, cancellationToken);
                    return await GetByIdInternalAsync(reservation.Payment.Id, approvalUrl, cancellationToken);
                }
                case PaymentStatus.Refunded:
                    throw new ConflictException("Placanje za odabranu rezervaciju je refundirano i ne moze se ponovo inicirati.");
                case PaymentStatus.Failed:
                {
                    var providerPricing = ConvertReservationAmountToProviderAmount(reservation.TotalAmount, reservation.Currency);
                    var order = await _payPalCheckoutClient.CreateOrderAsync(
                        providerPricing.Amount,
                        providerPricing.CurrencyCode,
                        reservation.ReservationCode,
                        BuildPaymentDescription(reservation),
                        BuildPayPalCallbackUrl(_payPalSettings.ReturnUrl, reservation.Id),
                        BuildPayPalCallbackUrl(_payPalSettings.CancelUrl, reservation.Id),
                        cancellationToken);

                    reservation.Payment.Status = PaymentStatus.Pending;
                    reservation.Payment.Provider = DefaultProvider;
                    reservation.Payment.ProviderReference = order.Id;
                    reservation.Payment.Amount = providerPricing.Amount;
                    reservation.Payment.Currency = providerPricing.CurrencyCode;
                    reservation.Payment.StatusReason = BuildInitializedStatusReason(reservation.Currency, providerPricing.CurrencyCode);
                    reservation.Payment.PaidAtUtc = null;
                    reservation.Payment.RefundedAtUtc = null;
                    reservation.Payment.UpdatedAtUtc = nowUtc;
                    reservation.Payment.Transactions.Add(CreatePendingChargeTransaction(
                        PaymentLedger.GetNextChargeType(reservation.Payment),
                        order.Id,
                        providerPricing.Amount,
                        providerPricing.CurrencyCode,
                        "Placanje je ponovo inicirano kroz PayPal.",
                        nowUtc));
                    await _dbContext.SaveChangesAsync(cancellationToken);

                    _logger.LogInformation("Payment {PaymentId} re-initialized through PayPal for reservation {ReservationId}.", reservation.Payment.Id, reservation.Id);

                    return await GetByIdInternalAsync(reservation.Payment.Id, GetApprovalUrl(order), cancellationToken);
                }
            }
        }

        var pricing = ConvertReservationAmountToProviderAmount(reservation.TotalAmount, reservation.Currency);
        var createdOrder = await _payPalCheckoutClient.CreateOrderAsync(
            pricing.Amount,
            pricing.CurrencyCode,
            reservation.ReservationCode,
            BuildPaymentDescription(reservation),
            BuildPayPalCallbackUrl(_payPalSettings.ReturnUrl, reservation.Id),
            BuildPayPalCallbackUrl(_payPalSettings.CancelUrl, reservation.Id),
            cancellationToken);

        var payment = new Payment
        {
            ReservationId = reservation.Id,
            Provider = DefaultProvider,
            ProviderReference = createdOrder.Id,
            Amount = pricing.Amount,
            Currency = pricing.CurrencyCode,
            Status = PaymentStatus.Pending,
            StatusReason = BuildInitializedStatusReason(reservation.Currency, pricing.CurrencyCode)
        };
        payment.Transactions.Add(CreatePendingChargeTransaction(
            PaymentTransactionType.InitialPayment,
            createdOrder.Id,
            pricing.Amount,
            pricing.CurrencyCode,
            "Inicijalno placanje rezervacije je pokrenuto kroz PayPal.",
            nowUtc));


        await _dbContext.Payments.AddAsync(payment, cancellationToken);
        await _dbContext.SaveChangesAsync(cancellationToken);

        _logger.LogInformation("Payment {PaymentId} initialized through PayPal for reservation {ReservationId}.", payment.Id, reservation.Id);

        return await GetByIdInternalAsync(payment.Id, GetApprovalUrl(createdOrder), cancellationToken);
    }

    public async Task<PagedResponseDto<PaymentListItemDto>> GetMineAsync(PaymentSearchRequest request, CancellationToken cancellationToken = default)
    {
        ValidateSearchRequest(request);
        return await GetPagedInternalAsync(request, GetRequiredCurrentUserId(), false, cancellationToken);
    }

    public async Task<PagedResponseDto<PaymentListItemDto>> GetAdminPagedAsync(PaymentSearchRequest request, CancellationToken cancellationToken = default)
    {
        ValidateSearchRequest(request);
        EnsureCurrentUserIsAdmin();
        return await GetPagedInternalAsync(request, null, true, cancellationToken);
    }

    public async Task<PaymentDetailsDto> GetByIdAsync(int id, CancellationToken cancellationToken = default)
    {
        var currentUserId = GetRequiredCurrentUserId();
        var isAdmin = CurrentUserIsAdmin();
        await _reservationStatusSyncService.SyncCompletedReservationsAsync(DateTime.UtcNow, cancellationToken);

        var ownership = await _dbContext.Payments
            .AsNoTracking()
            .Where(x => x.Id == id)
            .Select(x => new
            {
                x.Reservation.UserId
            })
            .SingleOrDefaultAsync(cancellationToken);

        if (ownership is null)
        {
            throw new NotFoundException($"Placanje sa ID vrijednoscu {id} nije pronadjeno.");
        }

        if (!isAdmin && ownership.UserId != currentUserId)
        {
            throw new ForbiddenException("Nemate pravo pristupa trazenom placanju.");
        }

        return await GetByIdInternalAsync(id, null, cancellationToken);
    }

    public async Task<PayPalPaymentVerificationDto> GetPayPalVerificationAsync(int id, string? callbackToken, CancellationToken cancellationToken = default)
    {
        EnsureCurrentUserIsAdmin();
        EnsurePayPalConfigured();
        var nowUtc = DateTime.UtcNow;
        await _reservationStatusSyncService.SyncCompletedReservationsAsync(nowUtc, cancellationToken);

        var payment = await _dbContext.Payments
            .AsNoTracking()
            .Include(x => x.Reservation)
                .ThenInclude(x => x.Flight)
            .SingleOrDefaultAsync(x => x.Id == id, cancellationToken);

        if (payment is null)
        {
            throw new NotFoundException($"Placanje sa ID vrijednoscu {id} nije pronadjeno.");
        }

        if (string.IsNullOrWhiteSpace(payment.ProviderReference))
        {
            throw new ConflictException("Placanje nema evidentiranu PayPal referencu za provjeru.");
        }

        var normalizedCallbackToken = string.IsNullOrWhiteSpace(callbackToken)
            ? null
            : callbackToken.Trim();

        if (payment.Status is PaymentStatus.Paid or PaymentStatus.Refunded)
        {
            var capture = await _payPalCheckoutClient.GetCaptureAsync(payment.ProviderReference, cancellationToken);
            var effectiveReservationStatus = _reservationStatusSyncService.GetEffectiveStatus(
                payment.Reservation.Status,
                payment.Status,
                payment.Reservation.Flight.ArrivalAtUtc,
                nowUtc);

            return new PayPalPaymentVerificationDto
            {
                PaymentId = payment.Id,
                ReservationId = payment.ReservationId,
                ReservationCode = payment.Reservation.ReservationCode,
                FlightNumber = payment.Reservation.Flight.FlightNumber,
                StoredProviderReference = payment.ProviderReference,
                CallbackToken = normalizedCallbackToken,
                CallbackTokenMatchesStoredReference =
                    normalizedCallbackToken is not null &&
                    string.Equals(normalizedCallbackToken, payment.ProviderReference, StringComparison.Ordinal),
                PaymentStatus = payment.Status,
                ReservationStatus = effectiveReservationStatus,
                PayPalResourceType = "Capture",
                PayPalOrderId = capture.Id,
                PayPalOrderStatus = capture.Status,
                ApprovalUrl = null,
                VerificationNote =
                    "Placanje je vec finalizovano, pa sacuvani provider reference sada pokazuje na PayPal capture zapis umjesto na originalni order token.",
                Links = capture.Links
                    .Select(x => new PayPalVerificationLinkDto
                    {
                        Rel = x.Rel,
                        Method = x.Method,
                        Href = x.Href
                    })
                    .ToArray(),
                Captures =
                [
                    new PayPalVerificationCaptureDto
                    {
                        Id = capture.Id,
                        Status = capture.Status,
                        Amount = ParseAmount(capture.Amount.Value),
                        Currency = capture.Amount.CurrencyCode,
                        CreateTimeUtc = capture.CreateTime?.ToUniversalTime()
                    }
                ]
            };
        }

        var order = await _payPalCheckoutClient.GetOrderAsync(payment.ProviderReference, cancellationToken);
        var approvalUrl = GetApprovalUrl(order);
        var effectiveStatus = _reservationStatusSyncService.GetEffectiveStatus(
            payment.Reservation.Status,
            payment.Status,
            payment.Reservation.Flight.ArrivalAtUtc,
            nowUtc);

        return new PayPalPaymentVerificationDto
        {
            PaymentId = payment.Id,
            ReservationId = payment.ReservationId,
            ReservationCode = payment.Reservation.ReservationCode,
            FlightNumber = payment.Reservation.Flight.FlightNumber,
            StoredProviderReference = payment.ProviderReference,
            CallbackToken = normalizedCallbackToken,
            CallbackTokenMatchesStoredReference =
                normalizedCallbackToken is not null &&
                string.Equals(normalizedCallbackToken, payment.ProviderReference, StringComparison.Ordinal),
            PaymentStatus = payment.Status,
            ReservationStatus = effectiveStatus,
            PayPalResourceType = "Order",
            PayPalOrderId = order.Id,
            PayPalOrderStatus = order.Status,
            ApprovalUrl = approvalUrl,
            VerificationNote = null,
            Links = order.Links
                .Select(x => new PayPalVerificationLinkDto
                {
                    Rel = x.Rel,
                    Method = x.Method,
                    Href = x.Href
                })
                .ToArray(),
            Captures = order.PurchaseUnits
                .SelectMany(x => x.Payments?.Captures ?? [])
                .Select(x => new PayPalVerificationCaptureDto
                {
                    Id = x.Id,
                    Status = x.Status,
                    Amount = ParseAmount(x.Amount.Value),
                    Currency = x.Amount.CurrencyCode,
                    CreateTimeUtc = x.CreateTime?.ToUniversalTime()
                })
                .ToArray()
        };
    }

    public async Task<PaymentDetailsDto> ConfirmAsync(int id, ConfirmPaymentRequest request, CancellationToken cancellationToken = default)
    {
        EnsurePayPalConfigured();

        var currentUserId = GetRequiredCurrentUserId();
        var isAdmin = CurrentUserIsAdmin();
        var nowUtc = DateTime.UtcNow;
        await _reservationStatusSyncService.SyncCompletedReservationsAsync(nowUtc, cancellationToken);

        var payment = await _dbContext.Payments
            .Include(x => x.Transactions)
            .Include(x => x.Reservation)
                .ThenInclude(x => x.Flight)
            .SingleOrDefaultAsync(x => x.Id == id, cancellationToken);

        if (payment is null)
        {
            throw new NotFoundException($"Placanje sa ID vrijednoscu {id} nije pronadjeno.");
        }

        if (!isAdmin && payment.Reservation.UserId != currentUserId)
        {
            throw new ForbiddenException("Mozete potvrditi placanje samo za vlastitu rezervaciju.");
        }

        if (payment.Status == PaymentStatus.Paid)
        {
            return await GetByIdInternalAsync(id, null, cancellationToken);
        }

        if (payment.Status == PaymentStatus.Refunded)
        {
            throw new ConflictException("Refundirano placanje se ne moze ponovo potvrditi.");
        }

        EnsureFlightCanReceivePayment(payment.Reservation.Flight, nowUtc);

        if (payment.Reservation.Status != ReservationStatus.Pending)
        {
            throw new ValidationException(
                "Placanje je moguce potvrditi samo za rezervaciju koja ceka placanje.",
                new Dictionary<string, string[]>
                {
                    ["reservation"] = ["Rezervacija mora biti u statusu Pending prije PayPal potvrde."]
                });
        }

        if (!string.IsNullOrWhiteSpace(request.ProviderReference) &&
            !string.Equals(payment.ProviderReference, request.ProviderReference.Trim(), StringComparison.Ordinal))
        {
            throw new ValidationException(
                "Provider reference ne odgovara iniciranom PayPal placanju.",
                new Dictionary<string, string[]>
                {
                    ["providerReference"] = ["Provider reference mora odgovarati PayPal narudzbi koja je inicirana za ovu rezervaciju."]
                });
        }

        if (string.IsNullOrWhiteSpace(payment.ProviderReference))
        {
            throw new ConflictException("Placanje nema iniciranu PayPal narudzbu za potvrdu.");
        }

        var orderReference = payment.ProviderReference;
        var orderSnapshot = await _payPalCheckoutClient.GetOrderAsync(orderReference, cancellationToken);

        if (string.Equals(orderSnapshot.Status, "CREATED", StringComparison.OrdinalIgnoreCase))
        {
            throw new ValidationException(
                "PayPal placanje jos nije odobreno od strane korisnika.",
                new Dictionary<string, string[]>
                {
                    ["payment"] = ["Prvo odobrite PayPal placanje, pa zatim ponovo pozovite potvrdu na serveru."]
                });
        }

        if (!string.Equals(orderSnapshot.Status, "COMPLETED", StringComparison.OrdinalIgnoreCase))
        {
            orderSnapshot = await _payPalCheckoutClient.CaptureOrderAsync(
                orderReference,
                payment.Reservation.ReservationCode,
                cancellationToken);
        }

        var capturedPayment = ExtractCompletedCapture(orderSnapshot);
        var capturedAmount = ParseAmount(capturedPayment.Amount.Value);
        var paidAtUtc = capturedPayment.CreateTime?.ToUniversalTime() ?? nowUtc;
        var statusReason = string.IsNullOrWhiteSpace(request.Reason)
            ? "Placanje je uspjesno potvrdjeno server-side PayPal capture verifikacijom."
            : request.Reason.Trim();

        CompletePendingChargeTransaction(
            payment,
            orderReference,
            capturedPayment.Id,
            capturedAmount,
            capturedPayment.Amount.CurrencyCode,
            paidAtUtc,
            statusReason,
            nowUtc);

        payment.ProviderReference = capturedPayment.Id;
        payment.Status = PaymentStatus.Paid;
        payment.Amount = PaymentLedger.CalculateNetPaidAmount(payment);
        payment.Currency = capturedPayment.Amount.CurrencyCode;
        payment.PaidAtUtc ??= paidAtUtc;
        payment.RefundedAtUtc = null;
        payment.StatusReason = statusReason;
        payment.UpdatedAtUtc = nowUtc;

        _stateMachine.MarkPaymentConfirmed(payment.Reservation, currentUserId, nowUtc);
        payment.Reservation.UpdatedAtUtc = nowUtc;

        await _dbContext.SaveChangesAsync(cancellationToken);
        await PublishNotificationSafelyAsync(
            payment.Reservation.UserId,
            "Placanje potvrdjeno",
            $"Placanje za rezervaciju {payment.Reservation.ReservationCode} je uspjesno evidentirano kroz PayPal sandbox.",
            nowUtc,
            cancellationToken);

        _logger.LogInformation("Payment {PaymentId} captured through PayPal for reservation {ReservationId}.", payment.Id, payment.ReservationId);

        return await GetByIdInternalAsync(id, null, cancellationToken);
    }

    public async Task<PaymentDetailsDto> RefundAsync(int id, RefundPaymentRequest request, CancellationToken cancellationToken = default)
    {
        EnsureCurrentUserIsAdmin();
        var currentUserId = GetRequiredCurrentUserId();
        EnsurePayPalConfigured();
        var nowUtc = DateTime.UtcNow;
        await _reservationStatusSyncService.SyncCompletedReservationsAsync(nowUtc, cancellationToken);

        var payment = await _dbContext.Payments
            .Include(x => x.Transactions)
            .Include(x => x.Reservation)
                .ThenInclude(x => x.Flight)
            .Include(x => x.Reservation)
                .ThenInclude(x => x.Items)
                    .ThenInclude(x => x.FlightSeat)
            .SingleOrDefaultAsync(x => x.Id == id, cancellationToken);

        if (payment is null)
        {
            throw new NotFoundException($"Placanje sa ID vrijednoscu {id} nije pronadjeno.");
        }

        if (string.IsNullOrWhiteSpace(request.Reason))
        {
            throw new ValidationException(
                "Razlog refundiranja je obavezan.",
                new Dictionary<string, string[]>
                {
                    ["reason"] = ["Unesite razlog refundiranja placanja."]
                });
        }

        var refundReason = request.Reason.Trim();

        EnsureLedgerHasCurrentPaidCapture(payment, nowUtc);

        if (payment.Status == PaymentStatus.Refunded)
        {
            throw new ConflictException("Placanje je vec refundirano.");
        }

        var refundableAmount = PaymentLedger.CalculateNetPaidAmount(payment);

        if (payment.Status is not (PaymentStatus.Paid or PaymentStatus.Pending) || refundableAmount <= 0m)
        {
            throw new ValidationException(
                "Refund je moguc samo za placanje koje ima stvarno evidentiran naplaceni iznos.",
                new Dictionary<string, string[]>
                {
                    ["status"] = ["Refund mozete uraditi samo za placanje koje ima PayPal capture zapis i pozitivan preostali iznos."]
                });
        }

        var effectiveReservationStatus = _reservationStatusSyncService.GetEffectiveStatus(
            payment.Reservation.Status,
            payment.Status,
            payment.Reservation.Flight.ArrivalAtUtc,
            nowUtc);

        if (effectiveReservationStatus == ReservationStatus.Completed)
        {
            throw new ValidationException(
                "Placanje vezano za zavrsenu rezervaciju se ne moze refundirati ovim tokom.",
                new Dictionary<string, string[]>
                {
                    ["reservation"] = ["Refund nije dozvoljen za rezervacije u statusu Completed."]
                });
        }

        if (payment.Reservation.Status is not (ReservationStatus.Confirmed or ReservationStatus.Pending))
        {
            throw new ValidationException(
                "Refund je moguc samo za aktivnu rezervaciju.",
                new Dictionary<string, string[]>
                {
                    ["reservation"] = ["Rezervacija mora biti u statusu Pending ili Confirmed prije refundacije placanja."]
                });
        }

        if (!CanBeRefunded(payment.Status, payment.Reservation.Status, refundableAmount, payment.Reservation.Flight.DepartureAtUtc, nowUtc))
        {
            throw new ValidationException(
                "Refund je moguc najkasnije 48 sati prije polaska leta.",
                new Dictionary<string, string[]>
                {
                    ["departureAtUtc"] = ["Refund vise nije dozvoljen jer je ostalo manje od 48 sati do polaska leta."]
                });
        }

        var refundedAtUtc = await RefundPaymentAmountAsync(
            payment,
            refundableAmount,
            PaymentTransactionType.FullRefund,
            refundReason,
            nowUtc,
            cancellationToken);

        payment.Status = PaymentStatus.Refunded;
        payment.Amount = 0m;
        payment.RefundedAtUtc = refundedAtUtc;
        payment.StatusReason = refundReason;
        payment.UpdatedAtUtc = nowUtc;

        _stateMachine.CancelAfterRefund(payment.Reservation, currentUserId, refundReason, nowUtc);
        var releasedSeats = ReleaseReservedSeats(payment.Reservation);

        await _dbContext.SaveChangesAsync(cancellationToken);
        await PublishNotificationSafelyAsync(
            payment.Reservation.UserId,
            "Placanje refundirano",
            $"Placanje za rezervaciju {payment.Reservation.ReservationCode} je refundirano kroz PayPal sandbox i rezervacija je otkazana. Razlog: {refundReason}",
            refundedAtUtc,
            cancellationToken);

        _logger.LogInformation(
            "Payment {PaymentId} refunded through PayPal for reservation {ReservationId}; {ReleasedSeatCount} seats released.",
            payment.Id,
            payment.ReservationId,
            releasedSeats);

        return await GetByIdInternalAsync(id, null, cancellationToken);
    }

    internal async Task<DateTime> RefundPaymentAmountAsync(
        Payment payment,
        decimal amount,
        PaymentTransactionType transactionType,
        string reason,
        DateTime nowUtc,
        CancellationToken cancellationToken)
    {
        if (amount <= 0m)
        {
            throw new ValidationException(
                "Iznos refundacije mora biti veci od 0.",
                new Dictionary<string, string[]>
                {
                    ["amount"] = ["Refund je moguc samo za pozitivan evidentirani iznos."]
                });
        }

        var refundableCaptures = PaymentLedger.GetRefundableCaptures(payment);

        if (refundableCaptures.Count == 0)
        {
            throw new ConflictException("Placanje nema PayPal capture zapis koji se moze refundirati.");
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
                Type = transactionType,
                Status = PaymentTransactionStatus.Completed,
                Provider = DefaultProvider,
                ProviderReference = refundResponse.Id,
                RelatedProviderReference = capture.CaptureId,
                Amount = refundAmount,
                Currency = capture.Currency,
                CompletedAtUtc = refundedAtUtc,
                Note = reason.Trim(),
                CreatedAtUtc = nowUtc,
                UpdatedAtUtc = nowUtc
            });

            remainingAmount = decimal.Round(remainingAmount - refundAmount, 2, MidpointRounding.AwayFromZero);
        }

        if (remainingAmount > 0m)
        {
            throw new ConflictException("Nije moguce refundirati trazeni iznos jer evidentirani capture zapisi nemaju dovoljan preostali iznos.");
        }

        return refundedAtUtc;
    }

    internal static PaymentTransaction CreatePendingChargeTransaction(
        PaymentTransactionType type,
        string providerReference,
        decimal amount,
        string currency,
        string note,
        DateTime nowUtc)
    {
        return new PaymentTransaction
        {
            Type = type,
            Status = PaymentTransactionStatus.Pending,
            Provider = DefaultProvider,
            ProviderReference = providerReference,
            Amount = amount,
            Currency = currency,
            Note = note,
            CreatedAtUtc = nowUtc
        };
    }

    internal static void FailPendingChargeTransactions(Payment payment, string reason, DateTime nowUtc)
    {
        foreach (var transaction in payment.Transactions.Where(x =>
            x.Status == PaymentTransactionStatus.Pending &&
            (x.Type == PaymentTransactionType.InitialPayment || x.Type == PaymentTransactionType.AdditionalCharge)))
        {
            transaction.Status = PaymentTransactionStatus.Failed;
            transaction.Note = reason;
            transaction.UpdatedAtUtc = nowUtc;
        }
    }

    internal static void EnsureLedgerHasCurrentPaidCapture(Payment payment, DateTime nowUtc)
    {
        var hasCompletedCharge = payment.Transactions.Any(x =>
            x.Status == PaymentTransactionStatus.Completed &&
            (x.Type == PaymentTransactionType.InitialPayment || x.Type == PaymentTransactionType.AdditionalCharge));

        if (hasCompletedCharge ||
            payment.Status != PaymentStatus.Paid ||
            payment.Amount <= 0m ||
            string.IsNullOrWhiteSpace(payment.ProviderReference))
        {
            return;
        }

        payment.Transactions.Add(new PaymentTransaction
        {
            Type = PaymentTransactionType.InitialPayment,
            Status = PaymentTransactionStatus.Completed,
            Provider = DefaultProvider,
            ProviderReference = payment.ProviderReference,
            Amount = payment.Amount,
            Currency = payment.Currency,
            CompletedAtUtc = payment.PaidAtUtc ?? payment.CreatedAtUtc,
            Note = "Postojeci PayPal capture je evidentiran u ledger nakon uvodjenja payment transakcija.",
            CreatedAtUtc = nowUtc,
            UpdatedAtUtc = nowUtc
        });
    }
    private static void CompletePendingChargeTransaction(
        Payment payment,
        string orderReference,
        string captureReference,
        decimal amount,
        string currency,
        DateTime completedAtUtc,
        string note,
        DateTime nowUtc)
    {
        var transaction = payment.Transactions
            .Where(x =>
                x.Status == PaymentTransactionStatus.Pending &&
                (x.Type == PaymentTransactionType.InitialPayment || x.Type == PaymentTransactionType.AdditionalCharge))
            .OrderByDescending(x => x.CreatedAtUtc)
            .FirstOrDefault(x => string.Equals(x.ProviderReference, orderReference, StringComparison.Ordinal))
            ?? PaymentLedger.FindPendingCharge(payment);

        if (transaction is null)
        {
            payment.Transactions.Add(new PaymentTransaction
            {
                Type = PaymentLedger.GetNextChargeType(payment),
                Status = PaymentTransactionStatus.Completed,
                Provider = DefaultProvider,
                ProviderReference = captureReference,
                RelatedProviderReference = orderReference,
                Amount = amount,
                Currency = currency,
                CompletedAtUtc = completedAtUtc,
                Note = note,
                CreatedAtUtc = nowUtc,
                UpdatedAtUtc = nowUtc
            });
            return;
        }

        transaction.Status = PaymentTransactionStatus.Completed;
        transaction.ProviderReference = captureReference;
        transaction.RelatedProviderReference = orderReference;
        transaction.Amount = amount;
        transaction.Currency = currency;
        transaction.CompletedAtUtc = completedAtUtc;
        transaction.Note = note;
        transaction.UpdatedAtUtc = nowUtc;
    }
    private async Task<PagedResponseDto<PaymentListItemDto>> GetPagedInternalAsync(
        PaymentSearchRequest request,
        string? userIdFilter,
        bool includeAllUsers,
        CancellationToken cancellationToken)
    {
        await _reservationStatusSyncService.SyncCompletedReservationsAsync(DateTime.UtcNow, cancellationToken);
        var query = BuildListQuery(request, userIdFilter, includeAllUsers);
        var totalCount = await query.CountAsync(cancellationToken);

        var items = await query
            .OrderByDescending(x => x.CreatedAtUtc)
            .ThenByDescending(x => x.Id)
            .Skip((request.Page - 1) * request.PageSize)
            .Take(request.PageSize)
            .Select(x => new PaymentListItemDto
            {
                Id = x.Id,
                ReservationId = x.ReservationId,
                ReservationCode = x.Reservation.ReservationCode,
                FlightNumber = x.Reservation.Flight.FlightNumber,
                RouteCode = x.Reservation.Flight.Destination.RouteCode,
                Provider = x.Provider,
                Amount = x.Amount,
                Currency = x.Currency,
                Status = x.Status,
                IsPaid = x.Status == PaymentStatus.Paid,
                CreatedAtUtc = x.CreatedAtUtc,
                PaidAtUtc = x.PaidAtUtc,
                RefundedAtUtc = x.RefundedAtUtc,
                CustomerName = _dbContext.UserProfiles
                    .Where(p => p.UserId == x.Reservation.UserId)
                    .Select(p => p.FirstName + " " + p.LastName)
                    .FirstOrDefault() ?? string.Empty
            })
            .ToListAsync(cancellationToken);

        return PagedResponseBuilder.Build(items, request.Page, request.PageSize, totalCount);
    }

    private IQueryable<Payment> BuildListQuery(PaymentSearchRequest request, string? userIdFilter, bool includeAllUsers)
    {
        var query = _dbContext.Payments.AsNoTracking().AsQueryable();

        if (!includeAllUsers && !string.IsNullOrWhiteSpace(userIdFilter))
        {
            query = query.Where(x => x.Reservation.UserId == userIdFilter);
        }

        if (request.Status.HasValue)
        {
            query = query.Where(x => x.Status == request.Status.Value);
        }

        if (request.ReservationId.HasValue)
        {
            query = query.Where(x => x.ReservationId == request.ReservationId.Value);
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
                x.Provider.Contains(searchText) ||
                (x.ProviderReference != null && x.ProviderReference.Contains(searchText)) ||
                x.Reservation.ReservationCode.Contains(searchText) ||
                x.Reservation.Flight.FlightNumber.Contains(searchText) ||
                x.Reservation.Flight.Destination.RouteCode.Contains(searchText) ||
                (includeAllUsers && _dbContext.UserProfiles.Any(p =>
                    p.UserId == x.Reservation.UserId &&
                    ((p.FirstName + " " + p.LastName).Contains(searchText) || p.Email.Contains(searchText)))));
        }

        return query;
    }

    private IQueryable<PaymentDetailsDto> BuildDetailsQuery()
    {
        var nowUtc = DateTime.UtcNow;

        return _dbContext.Payments
            .AsNoTracking()
            .Select(x => new PaymentDetailsDto
            {
                Id = x.Id,
                ReservationId = x.ReservationId,
                ReservationCode = x.Reservation.ReservationCode,
                FlightNumber = x.Reservation.Flight.FlightNumber,
                RouteCode = x.Reservation.Flight.Destination.RouteCode,
                Provider = x.Provider,
                ProviderReference = x.ProviderReference,
                Amount = x.Amount,
                Currency = x.Currency,
                Status = x.Status,
                IsPaid = x.Status == PaymentStatus.Paid,
                CreatedAtUtc = x.CreatedAtUtc,
                UpdatedAtUtc = x.UpdatedAtUtc,
                PaidAtUtc = x.PaidAtUtc,
                RefundedAtUtc = x.RefundedAtUtc,
                StatusReason = x.StatusReason,
                CanBeConfirmed = x.Status == PaymentStatus.Pending &&
                    x.Reservation.Status == ReservationStatus.Pending &&
                    (x.Reservation.Flight.Status == FlightStatus.Scheduled || x.Reservation.Flight.Status == FlightStatus.Delayed) &&
                    x.Reservation.Flight.DepartureAtUtc > nowUtc &&
                    x.Reservation.Flight.ArrivalAtUtc > nowUtc,
                CanBeRefunded =
                    (x.Status == PaymentStatus.Paid ||
                        (x.Status == PaymentStatus.Pending && x.Transactions.Any(t =>
                            t.Status == PaymentTransactionStatus.Completed &&
                            (t.Type == PaymentTransactionType.InitialPayment || t.Type == PaymentTransactionType.AdditionalCharge)))) &&
                    (x.Reservation.Status == ReservationStatus.Confirmed || x.Reservation.Status == ReservationStatus.Pending) &&
                    (x.Reservation.Flight.Status == FlightStatus.Scheduled || x.Reservation.Flight.Status == FlightStatus.Delayed) &&
                    x.Reservation.Flight.DepartureAtUtc >= nowUtc.AddHours(RefundLeadTimeHours),
                Customer = new PaymentCustomerDto
                {
                    UserId = x.Reservation.UserId,
                    Username = _dbContext.Users
                        .Where(u => u.Id == x.Reservation.UserId)
                        .Select(u => u.UserName ?? string.Empty)
                        .FirstOrDefault() ?? string.Empty,
                    FullName = _dbContext.UserProfiles
                        .Where(p => p.UserId == x.Reservation.UserId)
                        .Select(p => p.FirstName + " " + p.LastName)
                        .FirstOrDefault() ?? string.Empty,
                    Email = _dbContext.UserProfiles
                        .Where(p => p.UserId == x.Reservation.UserId)
                        .Select(p => p.Email)
                        .FirstOrDefault() ?? string.Empty
                }
            });
    }

    private async Task<PaymentDetailsDto> GetByIdInternalAsync(int id, string? approvalUrl, CancellationToken cancellationToken)
    {
        var payment = await BuildDetailsQuery()
            .SingleOrDefaultAsync(x => x.Id == id, cancellationToken);

        if (payment is null)
        {
            throw new NotFoundException($"Placanje sa ID vrijednoscu {id} nije pronadjeno.");
        }

        payment.ApprovalUrl = approvalUrl;
        return payment;
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

    private void EnsureReservationCanReceivePayment(Reservation reservation)
    {
        var nowUtc = DateTime.UtcNow;

        if (reservation.Status != ReservationStatus.Pending)
        {
            throw new ValidationException(
                "Placanje je moguce pokrenuti samo za rezervaciju koja ceka placanje.",
                new Dictionary<string, string[]>
                {
                    ["reservation"] = ["Placanje mozete pokrenuti samo za rezervaciju u statusu Pending."]
                });
        }

        EnsureFlightCanReceivePayment(reservation.Flight, nowUtc);
    }

    private static void EnsureFlightCanReceivePayment(Flight flight, DateTime nowUtc)
    {
        if (FlightLifecycleService.CanReceivePayment(flight, nowUtc))
        {
            return;
        }

        throw new ValidationException(
            "Placanje za ovaj let trenutno nije moguce.",
            new Dictionary<string, string[]>
            {
                ["flight"] = ["Placanje je dozvoljeno samo za aktivan let prije vremena polaska. Otkazan ili zavrsen let se ne moze platiti."]
            });
    }

    private static int ReleaseReservedSeats(Reservation reservation)
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

        reservation.Flight.AvailableSeats = Math.Min(
            reservation.Flight.TotalSeats,
            reservation.Flight.AvailableSeats + releasedSeats);

        return releasedSeats;
    }

    private static bool CanBeRefunded(
        PaymentStatus paymentStatus,
        ReservationStatus reservationStatus,
        decimal refundableAmount,
        DateTime departureAtUtc,
        DateTime nowUtc)
    {
        return (paymentStatus is PaymentStatus.Paid or PaymentStatus.Pending) &&
            (reservationStatus is ReservationStatus.Confirmed or ReservationStatus.Pending) &&
            refundableAmount > 0m &&
            departureAtUtc >= nowUtc.AddHours(RefundLeadTimeHours);
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

    private static string BuildPaymentDescription(Reservation reservation)
    {
        if (reservation.AdditionalBaggageCount > 0)
        {
            return $"Reservation {reservation.ReservationCode} for flight {reservation.Flight.FlightNumber} with {reservation.AdditionalBaggageCount} extra baggage item(s)";
        }

        return $"Reservation {reservation.ReservationCode} for flight {reservation.Flight.FlightNumber}";
    }

    private static string BuildInitializedStatusReason(string reservationCurrency, string providerCurrency)
    {
        if (string.Equals(reservationCurrency, providerCurrency, StringComparison.OrdinalIgnoreCase))
        {
            return "Placanje je inicirano i ceka PayPal odobrenje i serverski capture.";
        }

        return $"Placanje je inicirano u valuti {providerCurrency} nakon konverzije iz valute {reservationCurrency} i ceka PayPal odobrenje i serverski capture.";
    }

    private async Task<string?> TryResolveApprovalUrlAsync(string? orderId, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(orderId))
        {
            return null;
        }

        try
        {
            var order = await _payPalCheckoutClient.GetOrderAsync(orderId, cancellationToken);
            return GetApprovalUrl(order);
        }
        catch (Exception exception)
        {
            _logger.LogWarning(exception, "Unable to resolve PayPal approval URL for order {OrderId}.", orderId);
            return null;
        }
    }

    private static string? GetApprovalUrl(PayPalCheckoutClient.PayPalOrderResponse order)
    {
        return order.Links
            .FirstOrDefault(x =>
                string.Equals(x.Rel, "approve", StringComparison.OrdinalIgnoreCase) ||
                string.Equals(x.Rel, "payer-action", StringComparison.OrdinalIgnoreCase))
            ?.Href;
    }

    private static PayPalCheckoutClient.PayPalCapture ExtractCompletedCapture(PayPalCheckoutClient.PayPalOrderResponse order)
    {
        var capture = order.PurchaseUnits
            .SelectMany(x => x.Payments?.Captures ?? [])
            .FirstOrDefault(x => string.Equals(x.Status, "COMPLETED", StringComparison.OrdinalIgnoreCase));

        return capture ?? throw new ValidationException(
            "PayPal nije vratio uspjesan capture zapis za ovu narudzbu.",
            new Dictionary<string, string[]>
            {
                ["payment"] = ["PayPal narudzba nije u stanju koje dozvoljava finalizaciju placanja."]
            });
    }

    private static decimal ParseAmount(string rawValue)
    {
        if (decimal.TryParse(rawValue, NumberStyles.Number, CultureInfo.InvariantCulture, out var amount))
        {
            return amount;
        }

        throw new ValidationException(
            "PayPal je vratio neispravan format iznosa.",
            new Dictionary<string, string[]>
            {
                ["payment"] = ["Nije moguce procitati iznos iz PayPal odgovora."]
            });
    }

    private static void ValidateSearchRequest(PaymentSearchRequest request)
    {
        if (request.CreatedFromUtc.HasValue && request.CreatedFromUtc.Value.Kind == DateTimeKind.Unspecified)
        {
            throw new ValidationException(
                "Datum pocetka pretrage mora biti u UTC formatu.",
                new Dictionary<string, string[]>
                {
                    ["createdFromUtc"] = ["Koristite UTC datum za CreatedFromUtc vrijednost."]
                });
        }

        if (request.CreatedToUtc.HasValue && request.CreatedToUtc.Value.Kind == DateTimeKind.Unspecified)
        {
            throw new ValidationException(
                "Datum kraja pretrage mora biti u UTC formatu.",
                new Dictionary<string, string[]>
                {
                    ["createdToUtc"] = ["Koristite UTC datum za CreatedToUtc vrijednost."]
                });
        }

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

    private async Task PublishNotificationSafelyAsync(
        string userId,
        string title,
        string body,
        DateTime occurredAtUtc,
        CancellationToken cancellationToken)
    {
        var message = new NotificationRequestedMessage
        {
            UserId = userId,
            Title = title,
            Body = body,
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
                "Failed to publish notification event {Title} for user {UserId}.",
                title,
                userId);
        }
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

    private readonly record struct ProviderPricing(decimal Amount, string CurrencyCode);
}
