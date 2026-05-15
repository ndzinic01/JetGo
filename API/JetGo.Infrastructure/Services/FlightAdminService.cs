using JetGo.Application.Contracts.Services;
using JetGo.Application.DTOs.Common;
using JetGo.Application.DTOs.Flights;
using JetGo.Application.Exceptions;
using JetGo.Application.Requests.Flights;
using JetGo.Domain.Entities;
using JetGo.Infrastructure.Persistence;
using JetGo.Infrastructure.Services.Common;
using Microsoft.EntityFrameworkCore;

namespace JetGo.Infrastructure.Services;

public sealed class FlightAdminService : IFlightAdminService
{
    private readonly JetGoDbContext _dbContext;

    public FlightAdminService(JetGoDbContext dbContext)
    {
        _dbContext = dbContext;
    }

    public async Task<PagedResponseDto<FlightListItemDto>> GetPagedAsync(FlightSearchRequest request, CancellationToken cancellationToken = default)
    {
        ValidateRequest(request);

        var query = BuildQuery(request);
        var totalCount = await query.CountAsync(cancellationToken);

        var items = await query
            .OrderBy(x => x.DepartureAtUtc)
            .ThenBy(x => x.FlightNumber)
            .Skip((request.Page - 1) * request.PageSize)
            .Take(request.PageSize)
            .Select(x => new FlightListItemDto
            {
                Id = x.Id,
                FlightNumber = x.FlightNumber,
                RouteCode = x.Destination.RouteCode,
                Airline = new AirlineSummaryDto
                {
                    Id = x.Airline.Id,
                    Name = x.Airline.Name,
                    Code = x.Airline.Code,
                    LogoUrl = x.Airline.LogoUrl
                },
                DepartureAirport = new AirportSummaryDto
                {
                    Id = x.Destination.DepartureAirport.Id,
                    Name = x.Destination.DepartureAirport.Name,
                    IataCode = x.Destination.DepartureAirport.IataCode,
                    CityName = x.Destination.DepartureAirport.City.Name,
                    CountryName = x.Destination.DepartureAirport.City.Country.Name
                },
                ArrivalAirport = new AirportSummaryDto
                {
                    Id = x.Destination.ArrivalAirport.Id,
                    Name = x.Destination.ArrivalAirport.Name,
                    IataCode = x.Destination.ArrivalAirport.IataCode,
                    CityName = x.Destination.ArrivalAirport.City.Name,
                    CountryName = x.Destination.ArrivalAirport.City.Country.Name
                },
                DepartureAtUtc = x.DepartureAtUtc,
                ArrivalAtUtc = x.ArrivalAtUtc,
                DurationMinutes = EF.Functions.DateDiffMinute(x.DepartureAtUtc, x.ArrivalAtUtc),
                BasePrice = x.BasePrice,
                AvailableSeats = x.AvailableSeats,
                TotalSeats = x.TotalSeats,
                Status = x.Status
            })
            .ToListAsync(cancellationToken);

        return PagedResponseBuilder.Build(items, request.Page, request.PageSize, totalCount);
    }

    public async Task<FlightDetailsDto> GetByIdAsync(int id, CancellationToken cancellationToken = default)
    {
        var flight = await _dbContext.Flights
            .AsNoTracking()
            .Where(x => x.Id == id)
            .Select(x => new FlightDetailsDto
            {
                Id = x.Id,
                DestinationId = x.DestinationId,
                FlightNumber = x.FlightNumber,
                RouteCode = x.Destination.RouteCode,
                Airline = new AirlineSummaryDto
                {
                    Id = x.Airline.Id,
                    Name = x.Airline.Name,
                    Code = x.Airline.Code,
                    LogoUrl = x.Airline.LogoUrl
                },
                DepartureAirport = new AirportSummaryDto
                {
                    Id = x.Destination.DepartureAirport.Id,
                    Name = x.Destination.DepartureAirport.Name,
                    IataCode = x.Destination.DepartureAirport.IataCode,
                    CityName = x.Destination.DepartureAirport.City.Name,
                    CountryName = x.Destination.DepartureAirport.City.Country.Name
                },
                ArrivalAirport = new AirportSummaryDto
                {
                    Id = x.Destination.ArrivalAirport.Id,
                    Name = x.Destination.ArrivalAirport.Name,
                    IataCode = x.Destination.ArrivalAirport.IataCode,
                    CityName = x.Destination.ArrivalAirport.City.Name,
                    CountryName = x.Destination.ArrivalAirport.City.Country.Name
                },
                DepartureAtUtc = x.DepartureAtUtc,
                ArrivalAtUtc = x.ArrivalAtUtc,
                DurationMinutes = EF.Functions.DateDiffMinute(x.DepartureAtUtc, x.ArrivalAtUtc),
                BasePrice = x.BasePrice,
                Currency = "BAM",
                AvailableSeats = x.AvailableSeats,
                TotalSeats = x.TotalSeats,
                ReservedSeats = x.TotalSeats - x.AvailableSeats,
                Status = x.Status,
                AvailableSeatNumbers = x.Seats
                    .Where(s => !s.IsReserved)
                    .OrderBy(s => s.SeatNumber)
                    .Select(s => s.SeatNumber)
                    .ToArray()
            })
            .SingleOrDefaultAsync(cancellationToken);

        return flight ?? throw new NotFoundException($"Let sa ID vrijednoscu {id} nije pronadjen.");
    }

    public async Task<FlightDetailsDto> CreateAsync(UpsertFlightRequest request, CancellationToken cancellationToken = default)
    {
        ValidateRequest(request);
        await EnsureReferencesExistAsync(request.AirlineId, request.DestinationId, cancellationToken);
        await EnsureFlightNumberUniqueAsync(request.FlightNumber.Trim(), null, cancellationToken);

        var flight = new Flight
        {
            AirlineId = request.AirlineId,
            DestinationId = request.DestinationId,
            FlightNumber = request.FlightNumber.Trim().ToUpperInvariant(),
            DepartureAtUtc = request.DepartureAtUtc,
            ArrivalAtUtc = request.ArrivalAtUtc,
            BasePrice = decimal.Round(request.BasePrice, 2, MidpointRounding.AwayFromZero),
            TotalSeats = request.TotalSeats,
            AvailableSeats = request.TotalSeats,
            Status = request.Status,
            Seats = GenerateSeats(request.TotalSeats)
        };

        await _dbContext.Flights.AddAsync(flight, cancellationToken);
        await _dbContext.SaveChangesAsync(cancellationToken);

        return await GetByIdAsync(flight.Id, cancellationToken);
    }

    public async Task<FlightDetailsDto> UpdateAsync(int id, UpsertFlightRequest request, CancellationToken cancellationToken = default)
    {
        ValidateRequest(request);

        var flight = await _dbContext.Flights
            .Include(x => x.Seats)
            .Include(x => x.Reservations)
            .SingleOrDefaultAsync(x => x.Id == id, cancellationToken);

        if (flight is null)
        {
            throw new NotFoundException($"Let sa ID vrijednoscu {id} nije pronadjen.");
        }

        await EnsureReferencesExistAsync(request.AirlineId, request.DestinationId, cancellationToken);
        await EnsureFlightNumberUniqueAsync(request.FlightNumber.Trim(), id, cancellationToken);

        var hasReservations = flight.Reservations.Count > 0;
        var sensitiveDataChanged =
            flight.AirlineId != request.AirlineId ||
            flight.DestinationId != request.DestinationId ||
            !string.Equals(flight.FlightNumber, request.FlightNumber.Trim().ToUpperInvariant(), StringComparison.Ordinal) ||
            flight.DepartureAtUtc != request.DepartureAtUtc ||
            flight.ArrivalAtUtc != request.ArrivalAtUtc ||
            flight.TotalSeats != request.TotalSeats;

        if (hasReservations && sensitiveDataChanged)
        {
            throw new ConflictException("Osnovni podaci leta ne mogu se mijenjati jer vec postoje rezervacije povezane sa ovim letom.");
        }

        flight.AirlineId = request.AirlineId;
        flight.DestinationId = request.DestinationId;
        flight.FlightNumber = request.FlightNumber.Trim().ToUpperInvariant();
        flight.DepartureAtUtc = request.DepartureAtUtc;
        flight.ArrivalAtUtc = request.ArrivalAtUtc;
        flight.BasePrice = decimal.Round(request.BasePrice, 2, MidpointRounding.AwayFromZero);
        flight.Status = request.Status;
        flight.UpdatedAtUtc = DateTime.UtcNow;

        if (!hasReservations && flight.TotalSeats != request.TotalSeats)
        {
            _dbContext.FlightSeats.RemoveRange(flight.Seats);
            flight.Seats = GenerateSeats(request.TotalSeats);
            flight.TotalSeats = request.TotalSeats;
            flight.AvailableSeats = request.TotalSeats;
        }

        await _dbContext.SaveChangesAsync(cancellationToken);

        return await GetByIdAsync(flight.Id, cancellationToken);
    }

    public async Task DeleteAsync(int id, CancellationToken cancellationToken = default)
    {
        var flight = await _dbContext.Flights
            .Include(x => x.Seats)
            .SingleOrDefaultAsync(x => x.Id == id, cancellationToken);

        if (flight is null)
        {
            throw new NotFoundException($"Let sa ID vrijednoscu {id} nije pronadjen.");
        }

        var hasReservations = await _dbContext.Reservations.AnyAsync(x => x.FlightId == id, cancellationToken);

        if (hasReservations)
        {
            throw new ConflictException("Brisanje leta nije moguce jer postoje rezervacije povezane sa ovim letom.");
        }

        _dbContext.FlightSeats.RemoveRange(flight.Seats);
        _dbContext.Flights.Remove(flight);
        await _dbContext.SaveChangesAsync(cancellationToken);
    }

    private IQueryable<Flight> BuildQuery(FlightSearchRequest request)
    {
        var query = _dbContext.Flights.AsNoTracking().AsQueryable();

        if (request.DepartureAirportId.HasValue)
        {
            query = query.Where(x => x.Destination.DepartureAirportId == request.DepartureAirportId.Value);
        }

        if (request.ArrivalAirportId.HasValue)
        {
            query = query.Where(x => x.Destination.ArrivalAirportId == request.ArrivalAirportId.Value);
        }

        if (request.AirlineId.HasValue)
        {
            query = query.Where(x => x.AirlineId == request.AirlineId.Value);
        }

        if (request.DepartureFromUtc.HasValue)
        {
            query = query.Where(x => x.DepartureAtUtc >= request.DepartureFromUtc.Value);
        }

        if (request.DepartureToUtc.HasValue)
        {
            query = query.Where(x => x.DepartureAtUtc <= request.DepartureToUtc.Value);
        }

        if (request.MinPrice.HasValue)
        {
            query = query.Where(x => x.BasePrice >= request.MinPrice.Value);
        }

        if (request.MaxPrice.HasValue)
        {
            query = query.Where(x => x.BasePrice <= request.MaxPrice.Value);
        }

        if (request.Status.HasValue)
        {
            query = query.Where(x => x.Status == request.Status.Value);
        }

        if (!string.IsNullOrWhiteSpace(request.SearchText))
        {
            var searchText = request.SearchText.Trim();
            query = query.Where(x =>
                x.FlightNumber.Contains(searchText) ||
                x.Destination.RouteCode.Contains(searchText) ||
                x.Airline.Name.Contains(searchText) ||
                x.Airline.Code.Contains(searchText) ||
                x.Destination.DepartureAirport.Name.Contains(searchText) ||
                x.Destination.DepartureAirport.IataCode.Contains(searchText) ||
                x.Destination.DepartureAirport.City.Name.Contains(searchText) ||
                x.Destination.ArrivalAirport.Name.Contains(searchText) ||
                x.Destination.ArrivalAirport.IataCode.Contains(searchText) ||
                x.Destination.ArrivalAirport.City.Name.Contains(searchText));
        }

        return query;
    }

    private static void ValidateRequest(FlightSearchRequest request)
    {
        if (request.DepartureFromUtc.HasValue && request.DepartureToUtc.HasValue && request.DepartureFromUtc > request.DepartureToUtc)
        {
            throw new ValidationException(
                "Raspon datuma polaska nije validan.",
                new Dictionary<string, string[]>
                {
                    ["departureToUtc"] = ["Datum 'DepartureToUtc' mora biti veci ili jednak datumu 'DepartureFromUtc'."]
                });
        }

        if (request.MinPrice.HasValue && request.MaxPrice.HasValue && request.MinPrice > request.MaxPrice)
        {
            throw new ValidationException(
                "Raspon cijena nije validan.",
                new Dictionary<string, string[]>
                {
                    ["maxPrice"] = ["Maksimalna cijena mora biti veca ili jednaka minimalnoj cijeni."]
                });
        }
    }

    private static void ValidateRequest(UpsertFlightRequest request)
    {
        if (request.DepartureAtUtc.Kind == DateTimeKind.Unspecified || request.ArrivalAtUtc.Kind == DateTimeKind.Unspecified)
        {
            throw new ValidationException(
                "Datumi leta moraju biti u UTC formatu.",
                new Dictionary<string, string[]>
                {
                    ["departureAtUtc"] = ["Koristite UTC datum za DepartureAtUtc vrijednost."],
                    ["arrivalAtUtc"] = ["Koristite UTC datum za ArrivalAtUtc vrijednost."]
                });
        }

        if (request.ArrivalAtUtc <= request.DepartureAtUtc)
        {
            throw new ValidationException(
                "Dolazak mora biti nakon polaska.",
                new Dictionary<string, string[]>
                {
                    ["arrivalAtUtc"] = ["Vrijeme dolaska mora biti nakon vremena polaska."]
                });
        }
    }

    private async Task EnsureReferencesExistAsync(int airlineId, int destinationId, CancellationToken cancellationToken)
    {
        var airlineExists = await _dbContext.Airlines.AnyAsync(x => x.Id == airlineId, cancellationToken);

        if (!airlineExists)
        {
            throw new ValidationException(
                "Odabrana aviokompanija ne postoji.",
                new Dictionary<string, string[]>
                {
                    ["airlineId"] = ["Odabrana aviokompanija ne postoji."]
                });
        }

        var destinationExists = await _dbContext.Destinations.AnyAsync(x => x.Id == destinationId, cancellationToken);

        if (!destinationExists)
        {
            throw new ValidationException(
                "Odabrana destinacija ne postoji.",
                new Dictionary<string, string[]>
                {
                    ["destinationId"] = ["Odabrana destinacija ne postoji."]
                });
        }
    }

    private async Task EnsureFlightNumberUniqueAsync(string flightNumber, int? currentId, CancellationToken cancellationToken)
    {
        var normalizedFlightNumber = flightNumber.ToUpperInvariant();

        var exists = await _dbContext.Flights.AnyAsync(
            x => x.FlightNumber == normalizedFlightNumber && (!currentId.HasValue || x.Id != currentId.Value),
            cancellationToken);

        if (exists)
        {
            throw new ConflictException("Let sa istim brojem leta vec postoji.");
        }
    }

    private static List<FlightSeat> GenerateSeats(int totalSeats)
    {
        var seats = new List<FlightSeat>(totalSeats);
        var seatLetters = new[] { "A", "B", "C", "D", "E", "F" };
        var row = 1;

        while (seats.Count < totalSeats)
        {
            foreach (var seatLetter in seatLetters)
            {
                if (seats.Count == totalSeats)
                {
                    break;
                }

                seats.Add(new FlightSeat
                {
                    SeatNumber = $"{row}{seatLetter}",
                    IsReserved = false
                });
            }

            row++;
        }

        return seats;
    }
}
