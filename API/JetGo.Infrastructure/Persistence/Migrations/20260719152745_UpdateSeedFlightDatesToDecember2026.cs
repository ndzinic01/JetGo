using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace JetGo.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class UpdateSeedFlightDatesToDecember2026 : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.UpdateData(
                table: "Flights",
                keyColumn: "Id",
                keyValue: 1,
                columns: new[] { "ArrivalAtUtc", "DepartureAtUtc" },
                values: new object[] { new DateTime(2026, 12, 10, 9, 10, 0, 0, DateTimeKind.Utc), new DateTime(2026, 12, 10, 8, 0, 0, 0, DateTimeKind.Utc) });

            migrationBuilder.UpdateData(
                table: "Flights",
                keyColumn: "Id",
                keyValue: 2,
                columns: new[] { "ArrivalAtUtc", "DepartureAtUtc" },
                values: new object[] { new DateTime(2026, 12, 10, 13, 55, 0, 0, DateTimeKind.Utc), new DateTime(2026, 12, 10, 12, 30, 0, 0, DateTimeKind.Utc) });

            migrationBuilder.UpdateData(
                table: "Flights",
                keyColumn: "Id",
                keyValue: 3,
                columns: new[] { "ArrivalAtUtc", "DepartureAtUtc" },
                values: new object[] { new DateTime(2026, 12, 11, 8, 50, 0, 0, DateTimeKind.Utc), new DateTime(2026, 12, 11, 7, 45, 0, 0, DateTimeKind.Utc) });

            migrationBuilder.UpdateData(
                table: "Flights",
                keyColumn: "Id",
                keyValue: 4,
                columns: new[] { "ArrivalAtUtc", "DepartureAtUtc" },
                values: new object[] { new DateTime(2026, 12, 11, 17, 50, 0, 0, DateTimeKind.Utc), new DateTime(2026, 12, 11, 15, 20, 0, 0, DateTimeKind.Utc) });

            migrationBuilder.UpdateData(
                table: "Flights",
                keyColumn: "Id",
                keyValue: 5,
                columns: new[] { "ArrivalAtUtc", "DepartureAtUtc" },
                values: new object[] { new DateTime(2026, 12, 12, 8, 30, 0, 0, DateTimeKind.Utc), new DateTime(2026, 12, 12, 6, 10, 0, 0, DateTimeKind.Utc) });

            migrationBuilder.UpdateData(
                table: "Flights",
                keyColumn: "Id",
                keyValue: 6,
                columns: new[] { "ArrivalAtUtc", "DepartureAtUtc" },
                values: new object[] { new DateTime(2026, 12, 12, 19, 20, 0, 0, DateTimeKind.Utc), new DateTime(2026, 12, 12, 18, 0, 0, 0, DateTimeKind.Utc) });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.UpdateData(
                table: "Flights",
                keyColumn: "Id",
                keyValue: 1,
                columns: new[] { "ArrivalAtUtc", "DepartureAtUtc" },
                values: new object[] { new DateTime(2026, 5, 10, 9, 10, 0, 0, DateTimeKind.Utc), new DateTime(2026, 5, 10, 8, 0, 0, 0, DateTimeKind.Utc) });

            migrationBuilder.UpdateData(
                table: "Flights",
                keyColumn: "Id",
                keyValue: 2,
                columns: new[] { "ArrivalAtUtc", "DepartureAtUtc" },
                values: new object[] { new DateTime(2026, 5, 10, 13, 55, 0, 0, DateTimeKind.Utc), new DateTime(2026, 5, 10, 12, 30, 0, 0, DateTimeKind.Utc) });

            migrationBuilder.UpdateData(
                table: "Flights",
                keyColumn: "Id",
                keyValue: 3,
                columns: new[] { "ArrivalAtUtc", "DepartureAtUtc" },
                values: new object[] { new DateTime(2026, 5, 11, 8, 50, 0, 0, DateTimeKind.Utc), new DateTime(2026, 5, 11, 7, 45, 0, 0, DateTimeKind.Utc) });

            migrationBuilder.UpdateData(
                table: "Flights",
                keyColumn: "Id",
                keyValue: 4,
                columns: new[] { "ArrivalAtUtc", "DepartureAtUtc" },
                values: new object[] { new DateTime(2026, 5, 11, 17, 50, 0, 0, DateTimeKind.Utc), new DateTime(2026, 5, 11, 15, 20, 0, 0, DateTimeKind.Utc) });

            migrationBuilder.UpdateData(
                table: "Flights",
                keyColumn: "Id",
                keyValue: 5,
                columns: new[] { "ArrivalAtUtc", "DepartureAtUtc" },
                values: new object[] { new DateTime(2026, 5, 12, 8, 30, 0, 0, DateTimeKind.Utc), new DateTime(2026, 5, 12, 6, 10, 0, 0, DateTimeKind.Utc) });

            migrationBuilder.UpdateData(
                table: "Flights",
                keyColumn: "Id",
                keyValue: 6,
                columns: new[] { "ArrivalAtUtc", "DepartureAtUtc" },
                values: new object[] { new DateTime(2026, 5, 12, 19, 20, 0, 0, DateTimeKind.Utc), new DateTime(2026, 5, 12, 18, 0, 0, 0, DateTimeKind.Utc) });
        }
    }
}
