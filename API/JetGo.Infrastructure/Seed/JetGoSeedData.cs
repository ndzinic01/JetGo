using JetGo.Domain.Entities;
using JetGo.Domain.Enums;

namespace JetGo.Infrastructure.Seed;

internal static class JetGoSeedData
{
    private static readonly DateTime SeedTimestampUtc = new(2026, 4, 26, 12, 0, 0, DateTimeKind.Utc);
    private static readonly string[] StandardSeatNumbers = ["1A", "1B", "1C", "2A", "2B", "2C"];

    internal static Country[] Countries { get; } =
    [
        new Country
        {
            Id = 1,
            Name = "Bosna i Hercegovina",
            IsoCode = "BA",
            CreatedAtUtc = SeedTimestampUtc
        },
        new Country
        {
            Id = 2,
            Name = "Hrvatska",
            IsoCode = "HR",
            CreatedAtUtc = SeedTimestampUtc
        },
        new Country
        {
            Id = 3,
            Name = "Austrija",
            IsoCode = "AT",
            CreatedAtUtc = SeedTimestampUtc
        },
        new Country
        {
            Id = 4,
            Name = "Srbija",
            IsoCode = "RS",
            CreatedAtUtc = SeedTimestampUtc
        },
        new Country
        {
            Id = 5,
            Name = "Turska",
            IsoCode = "TR",
            CreatedAtUtc = SeedTimestampUtc
        },
        new Country
        {
            Id = 6,
            Name = "Njemacka",
            IsoCode = "DE",
            CreatedAtUtc = SeedTimestampUtc
        }
    ];

    internal static City[] Cities { get; } =
    [
        new City
        {
            Id = 1,
            CountryId = 1,
            Name = "Sarajevo",
            CreatedAtUtc = SeedTimestampUtc
        },
        new City
        {
            Id = 2,
            CountryId = 1,
            Name = "Mostar",
            CreatedAtUtc = SeedTimestampUtc
        },
        new City
        {
            Id = 3,
            CountryId = 1,
            Name = "Banja Luka",
            CreatedAtUtc = SeedTimestampUtc
        },
        new City
        {
            Id = 4,
            CountryId = 2,
            Name = "Zagreb",
            CreatedAtUtc = SeedTimestampUtc
        },
        new City
        {
            Id = 5,
            CountryId = 3,
            Name = "Bec",
            CreatedAtUtc = SeedTimestampUtc
        },
        new City
        {
            Id = 6,
            CountryId = 4,
            Name = "Beograd",
            CreatedAtUtc = SeedTimestampUtc
        },
        new City
        {
            Id = 7,
            CountryId = 5,
            Name = "Istanbul",
            CreatedAtUtc = SeedTimestampUtc
        },
        new City
        {
            Id = 8,
            CountryId = 6,
            Name = "Frankfurt",
            CreatedAtUtc = SeedTimestampUtc
        }
    ];

    internal static Airport[] Airports { get; } =
    [
        new Airport
        {
            Id = 1,
            CityId = 1,
            Name = "Sarajevo International Airport",
            IataCode = "SJJ",
            Latitude = 43.8246m,
            Longitude = 18.3315m,
            CreatedAtUtc = SeedTimestampUtc
        },
        new Airport
        {
            Id = 2,
            CityId = 2,
            Name = "Mostar International Airport",
            IataCode = "OMO",
            Latitude = 43.2829m,
            Longitude = 17.8459m,
            CreatedAtUtc = SeedTimestampUtc
        },
        new Airport
        {
            Id = 3,
            CityId = 3,
            Name = "Banja Luka International Airport",
            IataCode = "BNX",
            Latitude = 44.9414m,
            Longitude = 17.2975m,
            CreatedAtUtc = SeedTimestampUtc
        },
        new Airport
        {
            Id = 4,
            CityId = 4,
            Name = "Zagreb Franjo Tudman Airport",
            IataCode = "ZAG",
            Latitude = 45.7429m,
            Longitude = 16.0688m,
            CreatedAtUtc = SeedTimestampUtc
        },
        new Airport
        {
            Id = 5,
            CityId = 5,
            Name = "Vienna International Airport",
            IataCode = "VIE",
            Latitude = 48.1103m,
            Longitude = 16.5697m,
            CreatedAtUtc = SeedTimestampUtc
        },
        new Airport
        {
            Id = 6,
            CityId = 6,
            Name = "Belgrade Nikola Tesla Airport",
            IataCode = "BEG",
            Latitude = 44.8184m,
            Longitude = 20.3091m,
            CreatedAtUtc = SeedTimestampUtc
        },
        new Airport
        {
            Id = 7,
            CityId = 7,
            Name = "Istanbul Airport",
            IataCode = "IST",
            Latitude = 41.2753m,
            Longitude = 28.7519m,
            CreatedAtUtc = SeedTimestampUtc
        },
        new Airport
        {
            Id = 8,
            CityId = 8,
            Name = "Frankfurt Airport",
            IataCode = "FRA",
            Latitude = 50.0379m,
            Longitude = 8.5622m,
            CreatedAtUtc = SeedTimestampUtc
        }
    ];

    internal static Airline[] Airlines { get; } =
    [
        new Airline
        {
            Id = 1,
            Name = "Croatia Airlines",
            Code = "OU",
            IsActive = true,
            CreatedAtUtc = SeedTimestampUtc
        },
        new Airline
        {
            Id = 2,
            Name = "Austrian Airlines",
            Code = "OS",
            IsActive = true,
            CreatedAtUtc = SeedTimestampUtc
        },
        new Airline
        {
            Id = 3,
            Name = "Air Serbia",
            Code = "JU",
            IsActive = true,
            CreatedAtUtc = SeedTimestampUtc
        },
        new Airline
        {
            Id = 4,
            Name = "Turkish Airlines",
            Code = "TK",
            IsActive = true,
            CreatedAtUtc = SeedTimestampUtc
        },
        new Airline
        {
            Id = 5,
            Name = "Lufthansa",
            Code = "LH",
            IsActive = true,
            CreatedAtUtc = SeedTimestampUtc
        }
    ];

    internal static Destination[] Destinations { get; } =
    [
        new Destination
        {
            Id = 1,
            DepartureAirportId = 1,
            ArrivalAirportId = 4,
            RouteCode = "SJJ-ZAG",
            IsActive = true,
            CreatedAtUtc = SeedTimestampUtc
        },
        new Destination
        {
            Id = 2,
            DepartureAirportId = 1,
            ArrivalAirportId = 5,
            RouteCode = "SJJ-VIE",
            IsActive = true,
            CreatedAtUtc = SeedTimestampUtc
        },
        new Destination
        {
            Id = 3,
            DepartureAirportId = 3,
            ArrivalAirportId = 6,
            RouteCode = "BNX-BEG",
            IsActive = true,
            CreatedAtUtc = SeedTimestampUtc
        },
        new Destination
        {
            Id = 4,
            DepartureAirportId = 2,
            ArrivalAirportId = 7,
            RouteCode = "OMO-IST",
            IsActive = true,
            CreatedAtUtc = SeedTimestampUtc
        },
        new Destination
        {
            Id = 5,
            DepartureAirportId = 1,
            ArrivalAirportId = 8,
            RouteCode = "SJJ-FRA",
            IsActive = true,
            CreatedAtUtc = SeedTimestampUtc
        },
        new Destination
        {
            Id = 6,
            DepartureAirportId = 3,
            ArrivalAirportId = 5,
            RouteCode = "BNX-VIE",
            IsActive = true,
            CreatedAtUtc = SeedTimestampUtc
        }
    ];

    internal static Flight[] Flights { get; } =
    [
        new Flight
        {
            Id = 1,
            AirlineId = 1,
            DestinationId = 1,
            FlightNumber = "JG100",
            DepartureAtUtc = Utc(2026, 5, 10, 8, 0),
            ArrivalAtUtc = Utc(2026, 5, 10, 9, 10),
            BasePrice = 129.00m,
            TotalSeats = 6,
            AvailableSeats = 6,
            Status = FlightStatus.Scheduled,
            CreatedAtUtc = SeedTimestampUtc
        },
        new Flight
        {
            Id = 2,
            AirlineId = 2,
            DestinationId = 2,
            FlightNumber = "JG101",
            DepartureAtUtc = Utc(2026, 5, 10, 12, 30),
            ArrivalAtUtc = Utc(2026, 5, 10, 13, 55),
            BasePrice = 149.00m,
            TotalSeats = 6,
            AvailableSeats = 6,
            Status = FlightStatus.Scheduled,
            CreatedAtUtc = SeedTimestampUtc
        },
        new Flight
        {
            Id = 3,
            AirlineId = 3,
            DestinationId = 3,
            FlightNumber = "JG102",
            DepartureAtUtc = Utc(2026, 5, 11, 7, 45),
            ArrivalAtUtc = Utc(2026, 5, 11, 8, 50),
            BasePrice = 99.00m,
            TotalSeats = 6,
            AvailableSeats = 6,
            Status = FlightStatus.Scheduled,
            CreatedAtUtc = SeedTimestampUtc
        },
        new Flight
        {
            Id = 4,
            AirlineId = 4,
            DestinationId = 4,
            FlightNumber = "JG103",
            DepartureAtUtc = Utc(2026, 5, 11, 15, 20),
            ArrivalAtUtc = Utc(2026, 5, 11, 17, 50),
            BasePrice = 179.00m,
            TotalSeats = 6,
            AvailableSeats = 6,
            Status = FlightStatus.Scheduled,
            CreatedAtUtc = SeedTimestampUtc
        },
        new Flight
        {
            Id = 5,
            AirlineId = 5,
            DestinationId = 5,
            FlightNumber = "JG104",
            DepartureAtUtc = Utc(2026, 5, 12, 6, 10),
            ArrivalAtUtc = Utc(2026, 5, 12, 8, 30),
            BasePrice = 199.00m,
            TotalSeats = 6,
            AvailableSeats = 6,
            Status = FlightStatus.Scheduled,
            CreatedAtUtc = SeedTimestampUtc
        },
        new Flight
        {
            Id = 6,
            AirlineId = 2,
            DestinationId = 6,
            FlightNumber = "JG105",
            DepartureAtUtc = Utc(2026, 5, 12, 18, 0),
            ArrivalAtUtc = Utc(2026, 5, 12, 19, 20),
            BasePrice = 139.00m,
            TotalSeats = 6,
            AvailableSeats = 6,
            Status = FlightStatus.Scheduled,
            CreatedAtUtc = SeedTimestampUtc
        }
    ];

    internal static FlightSeat[] FlightSeats { get; } = BuildFlightSeats(
        (1, StandardSeatNumbers),
        (2, StandardSeatNumbers),
        (3, StandardSeatNumbers),
        (4, StandardSeatNumbers),
        (5, StandardSeatNumbers),
        (6, StandardSeatNumbers));

    internal static NewsArticle[] NewsArticles { get; } =
    [
        new NewsArticle
        {
            Id = 1,
            Title = "JetGo uvodi novu liniju Sarajevo - Bec",
            Content = "Od maja 2026. godine dostupna je nova linija iz Sarajeva prema Becu sa vise termina tokom sedmice.",
            ImageUrl = "https://images.unsplash.com/photo-1436491865332-7a61a109cc05?auto=format&fit=crop&w=1200&q=80",
            IsPublished = true,
            PublishedAtUtc = Utc(2026, 4, 20, 9, 0),
            CreatedAtUtc = SeedTimestampUtc
        },
        new NewsArticle
        {
            Id = 2,
            Title = "Savjeti za brzi check-in prije putovanja",
            Content = "Pripremite pasos, provjerite vrijeme polaska i dodjite na aerodrom najmanje dva sata prije medjunarodnog leta.",
            ImageUrl = "https://images.unsplash.com/photo-1529074963764-98f45c47344b?auto=format&fit=crop&w=1200&q=80",
            IsPublished = true,
            PublishedAtUtc = Utc(2026, 4, 22, 14, 30),
            CreatedAtUtc = SeedTimestampUtc
        }
    ];

    private static DateTime Utc(int year, int month, int day, int hour, int minute)
    {
        return new DateTime(year, month, day, hour, minute, 0, DateTimeKind.Utc);
    }

    private static FlightSeat[] BuildFlightSeats(params (int FlightId, string[] SeatNumbers)[] flightSeats)
    {
        var seats = new List<FlightSeat>();
        var id = 1;

        foreach (var flightSeatGroup in flightSeats)
        {
            foreach (var seatNumber in flightSeatGroup.SeatNumbers)
            {
                seats.Add(new FlightSeat
                {
                    Id = id++,
                    FlightId = flightSeatGroup.FlightId,
                    SeatNumber = seatNumber,
                    IsReserved = false
                });
            }
        }

        return seats.ToArray();
    }
}
