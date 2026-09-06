using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace JetGo.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddStructuredSearchSignals : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_SearchHistories_UserId",
                table: "SearchHistories");

            migrationBuilder.AddColumn<int>(
                name: "AirlineId",
                table: "SearchHistories",
                type: "int",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "ArrivalAirportId",
                table: "SearchHistories",
                type: "int",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "DepartureAirportId",
                table: "SearchHistories",
                type: "int",
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_SearchHistories_AirlineId",
                table: "SearchHistories",
                column: "AirlineId");

            migrationBuilder.CreateIndex(
                name: "IX_SearchHistories_ArrivalAirportId",
                table: "SearchHistories",
                column: "ArrivalAirportId");

            migrationBuilder.CreateIndex(
                name: "IX_SearchHistories_DepartureAirportId",
                table: "SearchHistories",
                column: "DepartureAirportId");

            migrationBuilder.CreateIndex(
                name: "IX_SearchHistories_UserId_CreatedAtUtc",
                table: "SearchHistories",
                columns: new[] { "UserId", "CreatedAtUtc" });

            migrationBuilder.AddForeignKey(
                name: "FK_SearchHistories_Airlines_AirlineId",
                table: "SearchHistories",
                column: "AirlineId",
                principalTable: "Airlines",
                principalColumn: "Id",
                onDelete: ReferentialAction.SetNull);

            migrationBuilder.AddForeignKey(
                name: "FK_SearchHistories_Airports_ArrivalAirportId",
                table: "SearchHistories",
                column: "ArrivalAirportId",
                principalTable: "Airports",
                principalColumn: "Id",
                onDelete: ReferentialAction.SetNull);

            migrationBuilder.AddForeignKey(
                name: "FK_SearchHistories_Airports_DepartureAirportId",
                table: "SearchHistories",
                column: "DepartureAirportId",
                principalTable: "Airports",
                principalColumn: "Id",
                onDelete: ReferentialAction.SetNull);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_SearchHistories_Airlines_AirlineId",
                table: "SearchHistories");

            migrationBuilder.DropForeignKey(
                name: "FK_SearchHistories_Airports_ArrivalAirportId",
                table: "SearchHistories");

            migrationBuilder.DropForeignKey(
                name: "FK_SearchHistories_Airports_DepartureAirportId",
                table: "SearchHistories");

            migrationBuilder.DropIndex(
                name: "IX_SearchHistories_AirlineId",
                table: "SearchHistories");

            migrationBuilder.DropIndex(
                name: "IX_SearchHistories_ArrivalAirportId",
                table: "SearchHistories");

            migrationBuilder.DropIndex(
                name: "IX_SearchHistories_DepartureAirportId",
                table: "SearchHistories");

            migrationBuilder.DropIndex(
                name: "IX_SearchHistories_UserId_CreatedAtUtc",
                table: "SearchHistories");

            migrationBuilder.DropColumn(
                name: "AirlineId",
                table: "SearchHistories");

            migrationBuilder.DropColumn(
                name: "ArrivalAirportId",
                table: "SearchHistories");

            migrationBuilder.DropColumn(
                name: "DepartureAirportId",
                table: "SearchHistories");

            migrationBuilder.CreateIndex(
                name: "IX_SearchHistories_UserId",
                table: "SearchHistories",
                column: "UserId");
        }
    }
}
