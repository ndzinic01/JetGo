using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace JetGo.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddReservationBaggage : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(
                name: "AdditionalBaggageCount",
                table: "Reservations",
                type: "int",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<decimal>(
                name: "AdditionalBaggageTotalPrice",
                table: "Reservations",
                type: "decimal(18,2)",
                precision: 18,
                scale: 2,
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.AddColumn<decimal>(
                name: "AdditionalBaggageUnitPrice",
                table: "Reservations",
                type: "decimal(18,2)",
                precision: 18,
                scale: 2,
                nullable: false,
                defaultValue: 0m);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "AdditionalBaggageCount",
                table: "Reservations");

            migrationBuilder.DropColumn(
                name: "AdditionalBaggageTotalPrice",
                table: "Reservations");

            migrationBuilder.DropColumn(
                name: "AdditionalBaggageUnitPrice",
                table: "Reservations");
        }
    }
}
