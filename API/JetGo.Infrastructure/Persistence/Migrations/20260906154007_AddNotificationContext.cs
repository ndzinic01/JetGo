using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace JetGo.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddNotificationContext : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(
                name: "FlightId",
                table: "Notifications",
                type: "int",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "FlightNumber",
                table: "Notifications",
                type: "nvarchar(30)",
                maxLength: 30,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "ReservationCode",
                table: "Notifications",
                type: "nvarchar(30)",
                maxLength: 30,
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "ReservationId",
                table: "Notifications",
                type: "int",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "Type",
                table: "Notifications",
                type: "int",
                nullable: false,
                defaultValue: 1);

            migrationBuilder.CreateIndex(
                name: "IX_Notifications_CreatedAtUtc",
                table: "Notifications",
                column: "CreatedAtUtc");

            migrationBuilder.CreateIndex(
                name: "IX_Notifications_FlightId",
                table: "Notifications",
                column: "FlightId");

            migrationBuilder.CreateIndex(
                name: "IX_Notifications_FlightNumber",
                table: "Notifications",
                column: "FlightNumber");

            migrationBuilder.CreateIndex(
                name: "IX_Notifications_ReservationId",
                table: "Notifications",
                column: "ReservationId");

            migrationBuilder.CreateIndex(
                name: "IX_Notifications_Type",
                table: "Notifications",
                column: "Type");

            migrationBuilder.AddForeignKey(
                name: "FK_Notifications_Flights_FlightId",
                table: "Notifications",
                column: "FlightId",
                principalTable: "Flights",
                principalColumn: "Id",
                onDelete: ReferentialAction.SetNull);

            migrationBuilder.AddForeignKey(
                name: "FK_Notifications_Reservations_ReservationId",
                table: "Notifications",
                column: "ReservationId",
                principalTable: "Reservations",
                principalColumn: "Id",
                onDelete: ReferentialAction.SetNull);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_Notifications_Flights_FlightId",
                table: "Notifications");

            migrationBuilder.DropForeignKey(
                name: "FK_Notifications_Reservations_ReservationId",
                table: "Notifications");

            migrationBuilder.DropIndex(
                name: "IX_Notifications_CreatedAtUtc",
                table: "Notifications");

            migrationBuilder.DropIndex(
                name: "IX_Notifications_FlightId",
                table: "Notifications");

            migrationBuilder.DropIndex(
                name: "IX_Notifications_FlightNumber",
                table: "Notifications");

            migrationBuilder.DropIndex(
                name: "IX_Notifications_ReservationId",
                table: "Notifications");

            migrationBuilder.DropIndex(
                name: "IX_Notifications_Type",
                table: "Notifications");

            migrationBuilder.DropColumn(
                name: "FlightId",
                table: "Notifications");

            migrationBuilder.DropColumn(
                name: "FlightNumber",
                table: "Notifications");

            migrationBuilder.DropColumn(
                name: "ReservationCode",
                table: "Notifications");

            migrationBuilder.DropColumn(
                name: "ReservationId",
                table: "Notifications");

            migrationBuilder.DropColumn(
                name: "Type",
                table: "Notifications");
        }
    }
}

