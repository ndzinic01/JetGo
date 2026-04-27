using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

#pragma warning disable CA1814 // Prefer jagged arrays over multidimensional

namespace JetGo.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddNotificationsAndNews : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "NewsArticles",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    Title = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: false),
                    Content = table.Column<string>(type: "nvarchar(4000)", maxLength: 4000, nullable: false),
                    ImageUrl = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: false),
                    IsPublished = table.Column<bool>(type: "bit", nullable: false),
                    PublishedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false),
                    CreatedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false),
                    UpdatedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_NewsArticles", x => x.Id);
                });

            migrationBuilder.InsertData(
                table: "NewsArticles",
                columns: new[] { "Id", "Content", "CreatedAtUtc", "ImageUrl", "IsPublished", "PublishedAtUtc", "Title", "UpdatedAtUtc" },
                values: new object[,]
                {
                    { 1, "Od maja 2026. godine dostupna je nova linija iz Sarajeva prema Becu sa vise termina tokom sedmice.", new DateTime(2026, 4, 26, 12, 0, 0, 0, DateTimeKind.Utc), "https://images.unsplash.com/photo-1436491865332-7a61a109cc05?auto=format&fit=crop&w=1200&q=80", true, new DateTime(2026, 4, 20, 9, 0, 0, 0, DateTimeKind.Utc), "JetGo uvodi novu liniju Sarajevo - Bec", null },
                    { 2, "Pripremite pasos, provjerite vrijeme polaska i dodjite na aerodrom najmanje dva sata prije medjunarodnog leta.", new DateTime(2026, 4, 26, 12, 0, 0, 0, DateTimeKind.Utc), "https://images.unsplash.com/photo-1529074963764-98f45c47344b?auto=format&fit=crop&w=1200&q=80", true, new DateTime(2026, 4, 22, 14, 30, 0, 0, DateTimeKind.Utc), "Savjeti za brzi check-in prije putovanja", null }
                });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "NewsArticles");
        }
    }
}
