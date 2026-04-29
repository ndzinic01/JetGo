using System.Security.Claims;
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
using JetGo.Infrastructure.Persistence;
using JetGo.Infrastructure.Services.Common;
using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace JetGo.Infrastructure.Services;

public sealed class ReservationService : IReservationService
{
    private readonly JetGoDbContext _dbContext;
    private readonly IHttpContextAccessor _httpContextAccessor;
    private readonly ReservationStateMachine _stateMachine;
    private readonly INotificationEventPublisher _notificationEventPublisher;
    private readonly ILogger<ReservationService> _logger;

    public ReservationService(
        JetGoDbContext dbContext,
        IHttpContextAccessor httpContextAccessor,
        ReservationStateMachine stateMachine,
        INotificationEventPublisher notificationEventPublisher,
        ILogger<ReservationService> logger)
    {
        _dbContext = dbContext;
        _httpContextAccessor = httpContextAccessor;
        _stateMachine = stateMachine;
        _notificationEventPublisher = notificationEventPublisher;
        _logger = logger;
    }

    public async Task<ReservationDetailsDto> CreateAsync(CreateReservationRequest request, CancellationToken cancellationToken = default)
    {
        var currentUserId = GetRequiredCurrentUserId();
        var nowUtc = DateTime.UtcNow;
        var normalizedSeatNumbers = NormalizeSeatNumbers(request.SeatNumbers);

        var hasActiveReservation = await _dbContext.Reservations
            .AsNoTracking()
            .AnyAsync(
                x => x.UserId == currentUserId
                    && x.FlightId == request.FlightId
                    && (x.Status == ReservationStatus.Pending || x.Status == ReservationStatus.Confirmed),
                cancellationToken);

        if (hasActiveReservation)
        {
            throw new ConflictException("Vec imate aktivnu rezervaciju za odabrani let.");
        }

        var flight = await _dbContext.Flights
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

        if (flight.Status != FlightStatus.Scheduled)
        {
            throw new ValidationException(
                "Rezervacija je moguca samo za letove u statusu Scheduled.",
                new Dictionary<string, string[]>
                {
                    ["flight"] = ["Odabrani let trenutno nije dostupan za rezervaciju."]
                });
        }

        if (flight.DepartureAtUtc <= nowUtc)
        {
            throw new ValidationException(
                "Nije moguce rezervisati let koji je vec poceo ili zavrsio.",
                new Dictionary<string, string[]>
                {
                    ["flight"] = ["Polazak odabranog leta je vec prosao."]
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
            TotalAmount = flight.BasePrice * selectedSeats.Count,
            Currency = "BAM"
        };

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
            $"Rezervacija {reservation.ReservationCode} za let {flight.FlightNumber} je uspjesno kreirana i ceka potvrdu.",
            nowUtc,
            cancellationToken);

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

        reservation.CanBeCancelled = _stateMachine.CanCancel(reservation.Status);
        reservation.CanBeConfirmed = isAdmin && _stateMachine.CanConfirm(reservation.Status);
        reservation.CanBeCompleted = isAdmin && _stateMachine.CanComplete(reservation.Status);
        reservation.CanInitiatePayment = reservation.Status == ReservationStatus.Confirmed && !reservation.IsPaid;
        reservation.CanBeRefunded = isAdmin && reservation.PaymentStatus == PaymentStatus.Paid && reservation.Status != ReservationStatus.Completed;

        return reservation;
    }

    public async Task<ReservationDetailsDto> ConfirmAsync(int id, UpdateReservationStatusRequest request, CancellationToken cancellationToken = default)
    {
        EnsureCurrentUserIsAdmin();
        var actorUserId = GetRequiredCurrentUserId();
        var nowUtc = DateTime.UtcNow;

        var reservation = await _dbContext.Reservations
            .SingleOrDefaultAsync(x => x.Id == id, cancellationToken);

        if (reservation is null)
        {
            throw new NotFoundException($"Rezervacija sa ID vrijednoscu {id} nije pronadjena.");
        }

        _stateMachine.Confirm(reservation, actorUserId, request.Reason, nowUtc);

        await _dbContext.SaveChangesAsync(cancellationToken);
        await PublishNotificationSafelyAsync(
            reservation.UserId,
            "Rezervacija potvrdjena",
            $"Rezervacija {reservation.ReservationCode} je potvrdjena.",
            nowUtc,
            cancellationToken);

        _logger.LogInformation("Reservation {ReservationCode} confirmed by {UserId}.", reservation.ReservationCode, actorUserId);

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

        var reservation = await _dbContext.Reservations
            .Include(x => x.Payment)
            .Include(x => x.Items)
                .ThenInclude(x => x.FlightSeat)
            .Include(x => x.Flight)
            .SingleOrDefaultAsync(x => x.Id == id, cancellationToken);

        if (reservation is null)
        {
            throw new NotFoundException($"Rezervacija sa ID vrijednoscu {id} nije pronadjena.");
        }

        if (!isAdmin && reservation.UserId != actorUserId)
        {
            throw new ForbiddenException("Mozete otkazati samo vlastitu rezervaciju.");
        }

        var hasCompletedPayment = reservation.Payment?.Status == PaymentStatus.Paid;
        _stateMachine.Cancel(reservation, actorUserId, request.Reason, nowUtc, hasCompletedPayment);

        foreach (var item in reservation.Items)
        {
            item.FlightSeat.IsReserved = false;
        }

        reservation.Flight.AvailableSeats += reservation.Items.Count;

        await _dbContext.SaveChangesAsync(cancellationToken);
        await PublishNotificationSafelyAsync(
            reservation.UserId,
            "Rezervacija otkazana",
            $"Rezervacija {reservation.ReservationCode} je otkazana. Razlog: {request.Reason.Trim()}",
            nowUtc,
            cancellationToken);

        _logger.LogInformation("Reservation {ReservationCode} cancelled by {UserId}.", reservation.ReservationCode, actorUserId);

        return await GetByIdAsync(id, cancellationToken);
    }

    public async Task<ReservationDetailsDto> CompleteAsync(int id, UpdateReservationStatusRequest request, CancellationToken cancellationToken = default)
    {
        EnsureCurrentUserIsAdmin();
        var actorUserId = GetRequiredCurrentUserId();
        var nowUtc = DateTime.UtcNow;

        var reservation = await _dbContext.Reservations
            .Include(x => x.Flight)
            .SingleOrDefaultAsync(x => x.Id == id, cancellationToken);

        if (reservation is null)
        {
            throw new NotFoundException($"Rezervacija sa ID vrijednoscu {id} nije pronadjena.");
        }

        _stateMachine.Complete(reservation, actorUserId, request.Reason, nowUtc);

        await _dbContext.SaveChangesAsync(cancellationToken);
        await PublishNotificationSafelyAsync(
            reservation.UserId,
            "Rezervacija zavrsena",
            $"Rezervacija {reservation.ReservationCode} je oznacena kao zavrsena.",
            nowUtc,
            cancellationToken);

        _logger.LogInformation("Reservation {ReservationCode} completed by {UserId}.", reservation.ReservationCode, actorUserId);

        return await GetByIdAsync(id, cancellationToken);
    }

    private async Task<PagedResponseDto<ReservationListItemDto>> GetPagedInternalAsync(
        ReservationSearchRequest request,
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
                Status = x.Status,
                TotalAmount = x.TotalAmount,
                Currency = x.Currency,
                PaymentId = x.Payment != null ? x.Payment.Id : null,
                PaymentStatus = x.Payment != null ? x.Payment.Status : null,
                IsPaid = x.Payment != null && x.Payment.Status == PaymentStatus.Paid,
                SeatsCount = x.Items.Count,
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
        var query = _dbContext.Reservations.AsNoTracking().AsQueryable();

        if (!includeAllUsers && !string.IsNullOrWhiteSpace(userIdFilter))
        {
            query = query.Where(x => x.UserId == userIdFilter);
        }

        if (request.Status.HasValue)
        {
            query = query.Where(x => x.Status == request.Status.Value);
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
                Status = x.Status,
                TotalAmount = x.TotalAmount,
                Currency = x.Currency,
                PaymentId = x.Payment != null ? x.Payment.Id : null,
                PaymentStatus = x.Payment != null ? x.Payment.Status : null,
                IsPaid = x.Payment != null && x.Payment.Status == PaymentStatus.Paid,
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
}
