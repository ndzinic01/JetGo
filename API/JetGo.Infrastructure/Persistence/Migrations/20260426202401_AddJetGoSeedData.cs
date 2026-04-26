using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

#pragma warning disable CA1814 // Prefer jagged arrays over multidimensional

namespace JetGo.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddJetGoSeedData : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.InsertData(
                table: "Airlines",
                columns: new[] { "Id", "Code", "CreatedAtUtc", "IsActive", "LogoUrl", "Name", "UpdatedAtUtc" },
                values: new object[,]
                {
                    { 1, "OU", new DateTime(2026, 4, 26, 12, 0, 0, 0, DateTimeKind.Utc), true, null, "Croatia Airlines", null },
                    { 2, "OS", new DateTime(2026, 4, 26, 12, 0, 0, 0, DateTimeKind.Utc), true, null, "Austrian Airlines", null },
                    { 3, "JU", new DateTime(2026, 4, 26, 12, 0, 0, 0, DateTimeKind.Utc), true, null, "Air Serbia", null },
                    { 4, "TK", new DateTime(2026, 4, 26, 12, 0, 0, 0, DateTimeKind.Utc), true, null, "Turkish Airlines", null },
                    { 5, "LH", new DateTime(2026, 4, 26, 12, 0, 0, 0, DateTimeKind.Utc), true, null, "Lufthansa", null }
                });

            migrationBuilder.InsertData(
                table: "Countries",
                columns: new[] { "Id", "CreatedAtUtc", "IsoCode", "Name", "UpdatedAtUtc" },
                values: new object[,]
                {
                    { 1, new DateTime(2026, 4, 26, 12, 0, 0, 0, DateTimeKind.Utc), "BA", "Bosna i Hercegovina", null },
                    { 2, new DateTime(2026, 4, 26, 12, 0, 0, 0, DateTimeKind.Utc), "HR", "Hrvatska", null },
                    { 3, new DateTime(2026, 4, 26, 12, 0, 0, 0, DateTimeKind.Utc), "AT", "Austrija", null },
                    { 4, new DateTime(2026, 4, 26, 12, 0, 0, 0, DateTimeKind.Utc), "RS", "Srbija", null },
                    { 5, new DateTime(2026, 4, 26, 12, 0, 0, 0, DateTimeKind.Utc), "TR", "Turska", null },
                    { 6, new DateTime(2026, 4, 26, 12, 0, 0, 0, DateTimeKind.Utc), "DE", "Njemacka", null }
                });

            migrationBuilder.InsertData(
                table: "Cities",
                columns: new[] { "Id", "CountryId", "CreatedAtUtc", "Name", "UpdatedAtUtc" },
                values: new object[,]
                {
                    { 1, 1, new DateTime(2026, 4, 26, 12, 0, 0, 0, DateTimeKind.Utc), "Sarajevo", null },
                    { 2, 1, new DateTime(2026, 4, 26, 12, 0, 0, 0, DateTimeKind.Utc), "Mostar", null },
                    { 3, 1, new DateTime(2026, 4, 26, 12, 0, 0, 0, DateTimeKind.Utc), "Banja Luka", null },
                    { 4, 2, new DateTime(2026, 4, 26, 12, 0, 0, 0, DateTimeKind.Utc), "Zagreb", null },
                    { 5, 3, new DateTime(2026, 4, 26, 12, 0, 0, 0, DateTimeKind.Utc), "Bec", null },
                    { 6, 4, new DateTime(2026, 4, 26, 12, 0, 0, 0, DateTimeKind.Utc), "Beograd", null },
                    { 7, 5, new DateTime(2026, 4, 26, 12, 0, 0, 0, DateTimeKind.Utc), "Istanbul", null },
                    { 8, 6, new DateTime(2026, 4, 26, 12, 0, 0, 0, DateTimeKind.Utc), "Frankfurt", null }
                });

            migrationBuilder.InsertData(
                table: "Airports",
                columns: new[] { "Id", "CityId", "CreatedAtUtc", "IataCode", "Latitude", "Longitude", "Name", "UpdatedAtUtc" },
                values: new object[,]
                {
                    { 1, 1, new DateTime(2026, 4, 26, 12, 0, 0, 0, DateTimeKind.Utc), "SJJ", 43.8246m, 18.3315m, "Sarajevo International Airport", null },
                    { 2, 2, new DateTime(2026, 4, 26, 12, 0, 0, 0, DateTimeKind.Utc), "OMO", 43.2829m, 17.8459m, "Mostar International Airport", null },
                    { 3, 3, new DateTime(2026, 4, 26, 12, 0, 0, 0, DateTimeKind.Utc), "BNX", 44.9414m, 17.2975m, "Banja Luka International Airport", null },
                    { 4, 4, new DateTime(2026, 4, 26, 12, 0, 0, 0, DateTimeKind.Utc), "ZAG", 45.7429m, 16.0688m, "Zagreb Franjo Tudman Airport", null },
                    { 5, 5, new DateTime(2026, 4, 26, 12, 0, 0, 0, DateTimeKind.Utc), "VIE", 48.1103m, 16.5697m, "Vienna International Airport", null },
                    { 6, 6, new DateTime(2026, 4, 26, 12, 0, 0, 0, DateTimeKind.Utc), "BEG", 44.8184m, 20.3091m, "Belgrade Nikola Tesla Airport", null },
                    { 7, 7, new DateTime(2026, 4, 26, 12, 0, 0, 0, DateTimeKind.Utc), "IST", 41.2753m, 28.7519m, "Istanbul Airport", null },
                    { 8, 8, new DateTime(2026, 4, 26, 12, 0, 0, 0, DateTimeKind.Utc), "FRA", 50.0379m, 8.5622m, "Frankfurt Airport", null }
                });

            migrationBuilder.InsertData(
                table: "Destinations",
                columns: new[] { "Id", "ArrivalAirportId", "CreatedAtUtc", "DepartureAirportId", "IsActive", "RouteCode", "UpdatedAtUtc" },
                values: new object[,]
                {
                    { 1, 4, new DateTime(2026, 4, 26, 12, 0, 0, 0, DateTimeKind.Utc), 1, true, "SJJ-ZAG", null },
                    { 2, 5, new DateTime(2026, 4, 26, 12, 0, 0, 0, DateTimeKind.Utc), 1, true, "SJJ-VIE", null },
                    { 3, 6, new DateTime(2026, 4, 26, 12, 0, 0, 0, DateTimeKind.Utc), 3, true, "BNX-BEG", null },
                    { 4, 7, new DateTime(2026, 4, 26, 12, 0, 0, 0, DateTimeKind.Utc), 2, true, "OMO-IST", null },
                    { 5, 8, new DateTime(2026, 4, 26, 12, 0, 0, 0, DateTimeKind.Utc), 1, true, "SJJ-FRA", null },
                    { 6, 5, new DateTime(2026, 4, 26, 12, 0, 0, 0, DateTimeKind.Utc), 3, true, "BNX-VIE", null }
                });

            migrationBuilder.InsertData(
                table: "Flights",
                columns: new[] { "Id", "AirlineId", "ArrivalAtUtc", "AvailableSeats", "BasePrice", "CreatedAtUtc", "DepartureAtUtc", "DestinationId", "FlightNumber", "Status", "TotalSeats", "UpdatedAtUtc" },
                values: new object[,]
                {
                    { 1, 1, new DateTime(2026, 5, 10, 9, 10, 0, 0, DateTimeKind.Utc), 6, 129.00m, new DateTime(2026, 4, 26, 12, 0, 0, 0, DateTimeKind.Utc), new DateTime(2026, 5, 10, 8, 0, 0, 0, DateTimeKind.Utc), 1, "JG100", 1, 6, null },
                    { 2, 2, new DateTime(2026, 5, 10, 13, 55, 0, 0, DateTimeKind.Utc), 6, 149.00m, new DateTime(2026, 4, 26, 12, 0, 0, 0, DateTimeKind.Utc), new DateTime(2026, 5, 10, 12, 30, 0, 0, DateTimeKind.Utc), 2, "JG101", 1, 6, null },
                    { 3, 3, new DateTime(2026, 5, 11, 8, 50, 0, 0, DateTimeKind.Utc), 6, 99.00m, new DateTime(2026, 4, 26, 12, 0, 0, 0, DateTimeKind.Utc), new DateTime(2026, 5, 11, 7, 45, 0, 0, DateTimeKind.Utc), 3, "JG102", 1, 6, null },
                    { 4, 4, new DateTime(2026, 5, 11, 17, 50, 0, 0, DateTimeKind.Utc), 6, 179.00m, new DateTime(2026, 4, 26, 12, 0, 0, 0, DateTimeKind.Utc), new DateTime(2026, 5, 11, 15, 20, 0, 0, DateTimeKind.Utc), 4, "JG103", 1, 6, null },
                    { 5, 5, new DateTime(2026, 5, 12, 8, 30, 0, 0, DateTimeKind.Utc), 6, 199.00m, new DateTime(2026, 4, 26, 12, 0, 0, 0, DateTimeKind.Utc), new DateTime(2026, 5, 12, 6, 10, 0, 0, DateTimeKind.Utc), 5, "JG104", 1, 6, null },
                    { 6, 2, new DateTime(2026, 5, 12, 19, 20, 0, 0, DateTimeKind.Utc), 6, 139.00m, new DateTime(2026, 4, 26, 12, 0, 0, 0, DateTimeKind.Utc), new DateTime(2026, 5, 12, 18, 0, 0, 0, DateTimeKind.Utc), 6, "JG105", 1, 6, null }
                });

            migrationBuilder.InsertData(
                table: "FlightSeats",
                columns: new[] { "Id", "FlightId", "IsReserved", "SeatNumber" },
                values: new object[,]
                {
                    { 1, 1, false, "1A" },
                    { 2, 1, false, "1B" },
                    { 3, 1, false, "1C" },
                    { 4, 1, false, "2A" },
                    { 5, 1, false, "2B" },
                    { 6, 1, false, "2C" },
                    { 7, 2, false, "1A" },
                    { 8, 2, false, "1B" },
                    { 9, 2, false, "1C" },
                    { 10, 2, false, "2A" },
                    { 11, 2, false, "2B" },
                    { 12, 2, false, "2C" },
                    { 13, 3, false, "1A" },
                    { 14, 3, false, "1B" },
                    { 15, 3, false, "1C" },
                    { 16, 3, false, "2A" },
                    { 17, 3, false, "2B" },
                    { 18, 3, false, "2C" },
                    { 19, 4, false, "1A" },
                    { 20, 4, false, "1B" },
                    { 21, 4, false, "1C" },
                    { 22, 4, false, "2A" },
                    { 23, 4, false, "2B" },
                    { 24, 4, false, "2C" },
                    { 25, 5, false, "1A" },
                    { 26, 5, false, "1B" },
                    { 27, 5, false, "1C" },
                    { 28, 5, false, "2A" },
                    { 29, 5, false, "2B" },
                    { 30, 5, false, "2C" },
                    { 31, 6, false, "1A" },
                    { 32, 6, false, "1B" },
                    { 33, 6, false, "1C" },
                    { 34, 6, false, "2A" },
                    { 35, 6, false, "2B" },
                    { 36, 6, false, "2C" }
                });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DeleteData(
                table: "FlightSeats",
                keyColumn: "Id",
                keyValue: 1);

            migrationBuilder.DeleteData(
                table: "FlightSeats",
                keyColumn: "Id",
                keyValue: 2);

            migrationBuilder.DeleteData(
                table: "FlightSeats",
                keyColumn: "Id",
                keyValue: 3);

            migrationBuilder.DeleteData(
                table: "FlightSeats",
                keyColumn: "Id",
                keyValue: 4);

            migrationBuilder.DeleteData(
                table: "FlightSeats",
                keyColumn: "Id",
                keyValue: 5);

            migrationBuilder.DeleteData(
                table: "FlightSeats",
                keyColumn: "Id",
                keyValue: 6);

            migrationBuilder.DeleteData(
                table: "FlightSeats",
                keyColumn: "Id",
                keyValue: 7);

            migrationBuilder.DeleteData(
                table: "FlightSeats",
                keyColumn: "Id",
                keyValue: 8);

            migrationBuilder.DeleteData(
                table: "FlightSeats",
                keyColumn: "Id",
                keyValue: 9);

            migrationBuilder.DeleteData(
                table: "FlightSeats",
                keyColumn: "Id",
                keyValue: 10);

            migrationBuilder.DeleteData(
                table: "FlightSeats",
                keyColumn: "Id",
                keyValue: 11);

            migrationBuilder.DeleteData(
                table: "FlightSeats",
                keyColumn: "Id",
                keyValue: 12);

            migrationBuilder.DeleteData(
                table: "FlightSeats",
                keyColumn: "Id",
                keyValue: 13);

            migrationBuilder.DeleteData(
                table: "FlightSeats",
                keyColumn: "Id",
                keyValue: 14);

            migrationBuilder.DeleteData(
                table: "FlightSeats",
                keyColumn: "Id",
                keyValue: 15);

            migrationBuilder.DeleteData(
                table: "FlightSeats",
                keyColumn: "Id",
                keyValue: 16);

            migrationBuilder.DeleteData(
                table: "FlightSeats",
                keyColumn: "Id",
                keyValue: 17);

            migrationBuilder.DeleteData(
                table: "FlightSeats",
                keyColumn: "Id",
                keyValue: 18);

            migrationBuilder.DeleteData(
                table: "FlightSeats",
                keyColumn: "Id",
                keyValue: 19);

            migrationBuilder.DeleteData(
                table: "FlightSeats",
                keyColumn: "Id",
                keyValue: 20);

            migrationBuilder.DeleteData(
                table: "FlightSeats",
                keyColumn: "Id",
                keyValue: 21);

            migrationBuilder.DeleteData(
                table: "FlightSeats",
                keyColumn: "Id",
                keyValue: 22);

            migrationBuilder.DeleteData(
                table: "FlightSeats",
                keyColumn: "Id",
                keyValue: 23);

            migrationBuilder.DeleteData(
                table: "FlightSeats",
                keyColumn: "Id",
                keyValue: 24);

            migrationBuilder.DeleteData(
                table: "FlightSeats",
                keyColumn: "Id",
                keyValue: 25);

            migrationBuilder.DeleteData(
                table: "FlightSeats",
                keyColumn: "Id",
                keyValue: 26);

            migrationBuilder.DeleteData(
                table: "FlightSeats",
                keyColumn: "Id",
                keyValue: 27);

            migrationBuilder.DeleteData(
                table: "FlightSeats",
                keyColumn: "Id",
                keyValue: 28);

            migrationBuilder.DeleteData(
                table: "FlightSeats",
                keyColumn: "Id",
                keyValue: 29);

            migrationBuilder.DeleteData(
                table: "FlightSeats",
                keyColumn: "Id",
                keyValue: 30);

            migrationBuilder.DeleteData(
                table: "FlightSeats",
                keyColumn: "Id",
                keyValue: 31);

            migrationBuilder.DeleteData(
                table: "FlightSeats",
                keyColumn: "Id",
                keyValue: 32);

            migrationBuilder.DeleteData(
                table: "FlightSeats",
                keyColumn: "Id",
                keyValue: 33);

            migrationBuilder.DeleteData(
                table: "FlightSeats",
                keyColumn: "Id",
                keyValue: 34);

            migrationBuilder.DeleteData(
                table: "FlightSeats",
                keyColumn: "Id",
                keyValue: 35);

            migrationBuilder.DeleteData(
                table: "FlightSeats",
                keyColumn: "Id",
                keyValue: 36);

            migrationBuilder.DeleteData(
                table: "Flights",
                keyColumn: "Id",
                keyValue: 1);

            migrationBuilder.DeleteData(
                table: "Flights",
                keyColumn: "Id",
                keyValue: 2);

            migrationBuilder.DeleteData(
                table: "Flights",
                keyColumn: "Id",
                keyValue: 3);

            migrationBuilder.DeleteData(
                table: "Flights",
                keyColumn: "Id",
                keyValue: 4);

            migrationBuilder.DeleteData(
                table: "Flights",
                keyColumn: "Id",
                keyValue: 5);

            migrationBuilder.DeleteData(
                table: "Flights",
                keyColumn: "Id",
                keyValue: 6);

            migrationBuilder.DeleteData(
                table: "Airlines",
                keyColumn: "Id",
                keyValue: 1);

            migrationBuilder.DeleteData(
                table: "Airlines",
                keyColumn: "Id",
                keyValue: 2);

            migrationBuilder.DeleteData(
                table: "Airlines",
                keyColumn: "Id",
                keyValue: 3);

            migrationBuilder.DeleteData(
                table: "Airlines",
                keyColumn: "Id",
                keyValue: 4);

            migrationBuilder.DeleteData(
                table: "Airlines",
                keyColumn: "Id",
                keyValue: 5);

            migrationBuilder.DeleteData(
                table: "Destinations",
                keyColumn: "Id",
                keyValue: 1);

            migrationBuilder.DeleteData(
                table: "Destinations",
                keyColumn: "Id",
                keyValue: 2);

            migrationBuilder.DeleteData(
                table: "Destinations",
                keyColumn: "Id",
                keyValue: 3);

            migrationBuilder.DeleteData(
                table: "Destinations",
                keyColumn: "Id",
                keyValue: 4);

            migrationBuilder.DeleteData(
                table: "Destinations",
                keyColumn: "Id",
                keyValue: 5);

            migrationBuilder.DeleteData(
                table: "Destinations",
                keyColumn: "Id",
                keyValue: 6);

            migrationBuilder.DeleteData(
                table: "Airports",
                keyColumn: "Id",
                keyValue: 1);

            migrationBuilder.DeleteData(
                table: "Airports",
                keyColumn: "Id",
                keyValue: 2);

            migrationBuilder.DeleteData(
                table: "Airports",
                keyColumn: "Id",
                keyValue: 3);

            migrationBuilder.DeleteData(
                table: "Airports",
                keyColumn: "Id",
                keyValue: 4);

            migrationBuilder.DeleteData(
                table: "Airports",
                keyColumn: "Id",
                keyValue: 5);

            migrationBuilder.DeleteData(
                table: "Airports",
                keyColumn: "Id",
                keyValue: 6);

            migrationBuilder.DeleteData(
                table: "Airports",
                keyColumn: "Id",
                keyValue: 7);

            migrationBuilder.DeleteData(
                table: "Airports",
                keyColumn: "Id",
                keyValue: 8);

            migrationBuilder.DeleteData(
                table: "Cities",
                keyColumn: "Id",
                keyValue: 1);

            migrationBuilder.DeleteData(
                table: "Cities",
                keyColumn: "Id",
                keyValue: 2);

            migrationBuilder.DeleteData(
                table: "Cities",
                keyColumn: "Id",
                keyValue: 3);

            migrationBuilder.DeleteData(
                table: "Cities",
                keyColumn: "Id",
                keyValue: 4);

            migrationBuilder.DeleteData(
                table: "Cities",
                keyColumn: "Id",
                keyValue: 5);

            migrationBuilder.DeleteData(
                table: "Cities",
                keyColumn: "Id",
                keyValue: 6);

            migrationBuilder.DeleteData(
                table: "Cities",
                keyColumn: "Id",
                keyValue: 7);

            migrationBuilder.DeleteData(
                table: "Cities",
                keyColumn: "Id",
                keyValue: 8);

            migrationBuilder.DeleteData(
                table: "Countries",
                keyColumn: "Id",
                keyValue: 1);

            migrationBuilder.DeleteData(
                table: "Countries",
                keyColumn: "Id",
                keyValue: 2);

            migrationBuilder.DeleteData(
                table: "Countries",
                keyColumn: "Id",
                keyValue: 3);

            migrationBuilder.DeleteData(
                table: "Countries",
                keyColumn: "Id",
                keyValue: 4);

            migrationBuilder.DeleteData(
                table: "Countries",
                keyColumn: "Id",
                keyValue: 5);

            migrationBuilder.DeleteData(
                table: "Countries",
                keyColumn: "Id",
                keyValue: 6);
        }
    }
}
