using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace JetGo.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddDestinationImages : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "ImageUrl",
                table: "Destinations",
                type: "nvarchar(500)",
                maxLength: 500,
                nullable: true);

            migrationBuilder.UpdateData(
                table: "Destinations",
                keyColumn: "Id",
                keyValue: 1,
                column: "ImageUrl",
                value: "https://images.pexels.com/photos/27401067/pexels-photo-27401067.jpeg?cs=srgb&dl=pexels-damir-27401067.jpg&fm=jpg");

            migrationBuilder.UpdateData(
                table: "Destinations",
                keyColumn: "Id",
                keyValue: 2,
                column: "ImageUrl",
                value: "https://images.pexels.com/photos/31725340/pexels-photo-31725340.jpeg?cs=srgb&dl=pexels-bidbtc-31725340.jpg&fm=jpg");

            migrationBuilder.UpdateData(
                table: "Destinations",
                keyColumn: "Id",
                keyValue: 3,
                column: "ImageUrl",
                value: "https://images.pexels.com/photos/32237254/pexels-photo-32237254.jpeg?cs=srgb&dl=pexels-borishamer-32237254.jpg&fm=jpg");

            migrationBuilder.UpdateData(
                table: "Destinations",
                keyColumn: "Id",
                keyValue: 4,
                column: "ImageUrl",
                value: "https://images.pexels.com/photos/28879119/pexels-photo-28879119.jpeg?cs=srgb&dl=pexels-reojuve-28879119.jpg&fm=jpg");

            migrationBuilder.UpdateData(
                table: "Destinations",
                keyColumn: "Id",
                keyValue: 5,
                column: "ImageUrl",
                value: "https://images.pexels.com/photos/19335682/pexels-photo-19335682.jpeg?cs=srgb&dl=pexels-masoodaslami-19335682.jpg&fm=jpg");

            migrationBuilder.UpdateData(
                table: "Destinations",
                keyColumn: "Id",
                keyValue: 6,
                column: "ImageUrl",
                value: "https://images.pexels.com/photos/31725340/pexels-photo-31725340.jpeg?cs=srgb&dl=pexels-bidbtc-31725340.jpg&fm=jpg");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "ImageUrl",
                table: "Destinations");
        }
    }
}
