using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace JetGo.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddPaymentWorkflow : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<DateTime>(
                name: "RefundedAtUtc",
                table: "Payments",
                type: "datetime2",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "StatusReason",
                table: "Payments",
                type: "nvarchar(500)",
                maxLength: 500,
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "RefundedAtUtc",
                table: "Payments");

            migrationBuilder.DropColumn(
                name: "StatusReason",
                table: "Payments");
        }
    }
}
