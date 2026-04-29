using System.Security.Claims;
using JetGo.Application.Constants;
using JetGo.Application.Contracts.Services;
using JetGo.Application.DTOs.Common;
using JetGo.Application.DTOs.Payments;
using JetGo.Application.Exceptions;
using JetGo.Application.Requests.Payments;
using JetGo.Domain.Entities;
using JetGo.Domain.Enums;
using JetGo.Infrastructure.Persistence;
using JetGo.Infrastructure.Services.Common;
using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace JetGo.Infrastructure.Services;

public sealed class PaymentService : IPaymentService
{
    private const string DefaultProvider = "PayPal";

    private readonly JetGoDbContext _dbContext;
    private readonly IHttpContextAccessor _httpContextAccessor;
    private readonly ILogger<PaymentService> _logger;

    public PaymentService(
        JetGoDbContext dbContext,
        IHttpContextAccessor httpContextAccessor,
        ILogger<PaymentService> logger)
    {
        _dbContext = dbContext;
        _httpContextAccessor = httpContextAccessor;
        _logger = logger;
    }

    public async Task<PaymentDetailsDto> InitializeAsync(int reservationId, CancellationToken cancellationToken = default)
    {
        var currentUserId = GetRequiredCurrentUserId();
        var isAdmin = CurrentUserIsAdmin();

        var reservation = await _dbContext.Reservations
            .Include(x => x.Payment)
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
                    return await GetByIdAsync(reservation.Payment.Id, cancellationToken);
                case PaymentStatus.Refunded:
                    throw new ConflictException("Placanje za odabranu rezervaciju je refundirano i ne moze se ponovo inicirati.");
                case PaymentStatus.Failed:
                    reservation.Payment.Status = PaymentStatus.Pending;
                    reservation.Payment.Provider = DefaultProvider;
                    reservation.Payment.ProviderReference = GeneratePendingProviderReference();
                    reservation.Payment.StatusReason = "Placanje je ponovo inicirano nakon prethodnog neuspjelog pokusaja.";
                    reservation.Payment.PaidAtUtc = null;
                    reservation.Payment.RefundedAtUtc = null;
                    reservation.Payment.UpdatedAtUtc = DateTime.UtcNow;
                    await _dbContext.SaveChangesAsync(cancellationToken);

                    _logger.LogInformation("Payment {PaymentId} re-initialized for reservation {ReservationId}.", reservation.Payment.Id, reservation.Id);
                    return await GetByIdAsync(reservation.Payment.Id, cancellationToken);
            }
        }

        var payment = new Payment
        {
            ReservationId = reservation.Id,
            Provider = DefaultProvider,
            ProviderReference = GeneratePendingProviderReference(),
            Amount = reservation.TotalAmount,
            Currency = reservation.Currency,
            Status = PaymentStatus.Pending,
            StatusReason = "Placanje je inicirano i ceka serversku potvrdu."
        };

        await _dbContext.Payments.AddAsync(payment, cancellationToken);
        await _dbContext.SaveChangesAsync(cancellationToken);

        _logger.LogInformation("Payment {PaymentId} initialized for reservation {ReservationId}.", payment.Id, reservation.Id);

        return await GetByIdAsync(payment.Id, cancellationToken);
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

        var payment = await BuildDetailsQuery()
            .SingleOrDefaultAsync(x => x.Id == id, cancellationToken);

        return payment ?? throw new NotFoundException($"Placanje sa ID vrijednoscu {id} nije pronadjeno.");
    }

    public async Task<PaymentDetailsDto> ConfirmAsync(int id, ConfirmPaymentRequest request, CancellationToken cancellationToken = default)
    {
        EnsureCurrentUserIsAdmin();

        var payment = await _dbContext.Payments
            .Include(x => x.Reservation)
            .ThenInclude(x => x.Flight)
            .SingleOrDefaultAsync(x => x.Id == id, cancellationToken);

        if (payment is null)
        {
            throw new NotFoundException($"Placanje sa ID vrijednoscu {id} nije pronadjeno.");
        }

        if (payment.Status == PaymentStatus.Paid)
        {
            return await GetByIdAsync(id, cancellationToken);
        }

        if (payment.Status == PaymentStatus.Refunded)
        {
            throw new ConflictException("Refundirano placanje se ne moze ponovo potvrditi.");
        }

        if (payment.Reservation.Status != ReservationStatus.Confirmed)
        {
            throw new ValidationException(
                "Placanje je moguce potvrditi samo za rezervaciju u statusu Confirmed.",
                new Dictionary<string, string[]>
                {
                    ["reservation"] = ["Prije potvrde placanja rezervacija mora biti potvrdjena."]
                });
        }

        var nowUtc = DateTime.UtcNow;
        payment.ProviderReference = request.ProviderReference.Trim();
        payment.Status = PaymentStatus.Paid;
        payment.PaidAtUtc = nowUtc;
        payment.RefundedAtUtc = null;
        payment.StatusReason = string.IsNullOrWhiteSpace(request.Reason)
            ? "Placanje je uspjesno potvrdjeno serverskom verifikacijom."
            : request.Reason.Trim();
        payment.UpdatedAtUtc = nowUtc;

        await AddNotificationAsync(
            payment.Reservation.UserId,
            "Placanje potvrdjeno",
            $"Placanje za rezervaciju {payment.Reservation.ReservationCode} je uspjesno evidentirano.",
            cancellationToken);

        await _dbContext.SaveChangesAsync(cancellationToken);

        _logger.LogInformation("Payment {PaymentId} confirmed for reservation {ReservationId}.", payment.Id, payment.ReservationId);

        return await GetByIdAsync(id, cancellationToken);
    }

    public async Task<PaymentDetailsDto> RefundAsync(int id, RefundPaymentRequest request, CancellationToken cancellationToken = default)
    {
        EnsureCurrentUserIsAdmin();

        var payment = await _dbContext.Payments
            .Include(x => x.Reservation)
            .ThenInclude(x => x.Flight)
            .SingleOrDefaultAsync(x => x.Id == id, cancellationToken);

        if (payment is null)
        {
            throw new NotFoundException($"Placanje sa ID vrijednoscu {id} nije pronadjeno.");
        }

        if (payment.Status == PaymentStatus.Refunded)
        {
            return await GetByIdAsync(id, cancellationToken);
        }

        if (payment.Status != PaymentStatus.Paid)
        {
            throw new ValidationException(
                "Refund je moguc samo za uspjesno naplaceno placanje.",
                new Dictionary<string, string[]>
                {
                    ["status"] = ["Refund mozete uraditi samo za placanje u statusu Paid."]
                });
        }

        if (payment.Reservation.Status == ReservationStatus.Completed)
        {
            throw new ValidationException(
                "Placanje vezano za zavrsenu rezervaciju se ne moze refundirati ovim tokom.",
                new Dictionary<string, string[]>
                {
                    ["reservation"] = ["Refund nije dozvoljen za rezervacije u statusu Completed."]
                });
        }

        var nowUtc = DateTime.UtcNow;
        payment.Status = PaymentStatus.Refunded;
        payment.RefundedAtUtc = nowUtc;
        payment.StatusReason = request.Reason.Trim();
        payment.UpdatedAtUtc = nowUtc;

        await AddNotificationAsync(
            payment.Reservation.UserId,
            "Placanje refundirano",
            $"Placanje za rezervaciju {payment.Reservation.ReservationCode} je refundirano. Razlog: {request.Reason.Trim()}",
            cancellationToken);

        await _dbContext.SaveChangesAsync(cancellationToken);

        _logger.LogInformation("Payment {PaymentId} refunded for reservation {ReservationId}.", payment.Id, payment.ReservationId);

        return await GetByIdAsync(id, cancellationToken);
    }

    private async Task<PagedResponseDto<PaymentListItemDto>> GetPagedInternalAsync(
        PaymentSearchRequest request,
        string? userIdFilter,
        bool includeAllUsers,
        CancellationToken cancellationToken)
    {
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
                CanBeConfirmed = x.Status == PaymentStatus.Pending && x.Reservation.Status == ReservationStatus.Confirmed,
                CanBeRefunded = x.Status == PaymentStatus.Paid && x.Reservation.Status != ReservationStatus.Completed,
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

    private static void EnsureReservationCanReceivePayment(Reservation reservation)
    {
        if (reservation.Status != ReservationStatus.Confirmed)
        {
            throw new ValidationException(
                "Placanje je moguce inicirati samo za potvrdjenu rezervaciju.",
                new Dictionary<string, string[]>
                {
                    ["reservation"] = ["Placanje mozete pokrenuti tek nakon sto rezervacija bude potvrdjena."]
                });
        }
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

    private async Task AddNotificationAsync(string userId, string title, string body, CancellationToken cancellationToken)
    {
        await _dbContext.Notifications.AddAsync(new Notification
        {
            UserId = userId,
            Title = title,
            Body = body
        }, cancellationToken);
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

    private static string GeneratePendingProviderReference()
    {
        return $"PENDING-{Guid.NewGuid():N}"[..20].ToUpperInvariant();
    }
}
