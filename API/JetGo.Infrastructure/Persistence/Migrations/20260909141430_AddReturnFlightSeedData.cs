using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace JetGo.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddReturnFlightSeedData : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql(
                """
                IF NOT EXISTS (SELECT 1 FROM [Destinations] WHERE [RouteCode] = N'IST-OMO')
                   AND NOT EXISTS (SELECT 1 FROM [Destinations] WHERE [Id] = 7)
                BEGIN
                    SET IDENTITY_INSERT [Destinations] ON;

                    INSERT INTO [Destinations]
                        ([Id], [ArrivalAirportId], [CreatedAtUtc], [DepartureAirportId], [ImageUrl], [IsActive], [RouteCode], [UpdatedAtUtc])
                    VALUES
                        (7, 2, '2026-04-26T12:00:00.0000000Z', 7, N'https://images.pexels.com/photos/28879119/pexels-photo-28879119.jpeg?cs=srgb&dl=pexels-reojuve-28879119.jpg&fm=jpg', CAST(1 AS bit), N'IST-OMO', NULL);

                    SET IDENTITY_INSERT [Destinations] OFF;
                END
                """);

            migrationBuilder.Sql(
                """
                DECLARE @ReturnDestinationId int = (
                    SELECT TOP(1) [Id]
                    FROM [Destinations]
                    WHERE [RouteCode] = N'IST-OMO'
                );

                IF @ReturnDestinationId IS NOT NULL
                   AND NOT EXISTS (SELECT 1 FROM [Flights] WHERE [FlightNumber] = N'JG108')
                   AND NOT EXISTS (SELECT 1 FROM [Flights] WHERE [Id] = 7)
                BEGIN
                    SET IDENTITY_INSERT [Flights] ON;

                    INSERT INTO [Flights]
                        ([Id], [AirlineId], [ArrivalAtUtc], [AvailableSeats], [BasePrice], [CreatedAtUtc], [DepartureAtUtc], [DestinationId], [FlightNumber], [Status], [TotalSeats], [UpdatedAtUtc])
                    VALUES
                        (7, 4, '2026-12-16T12:30:00.0000000Z', 6, 179.00, '2026-04-26T12:00:00.0000000Z', '2026-12-16T10:00:00.0000000Z', @ReturnDestinationId, N'JG108', 1, 6, NULL);

                    SET IDENTITY_INSERT [Flights] OFF;
                END
                """);

            migrationBuilder.Sql(
                """
                DECLARE @ReturnFlightId int = (
                    SELECT TOP(1) [Id]
                    FROM [Flights]
                    WHERE [FlightNumber] = N'JG108'
                );

                IF @ReturnFlightId IS NOT NULL
                   AND NOT EXISTS (SELECT 1 FROM [FlightSeats] WHERE [FlightId] = @ReturnFlightId)
                   AND NOT EXISTS (SELECT 1 FROM [FlightSeats] WHERE [Id] IN (37, 38, 39, 40, 41, 42))
                BEGIN
                    SET IDENTITY_INSERT [FlightSeats] ON;

                    INSERT INTO [FlightSeats]
                        ([Id], [FlightId], [IsReserved], [SeatNumber])
                    VALUES
                        (37, @ReturnFlightId, CAST(0 AS bit), N'1A'),
                        (38, @ReturnFlightId, CAST(0 AS bit), N'1B'),
                        (39, @ReturnFlightId, CAST(0 AS bit), N'1C'),
                        (40, @ReturnFlightId, CAST(0 AS bit), N'2A'),
                        (41, @ReturnFlightId, CAST(0 AS bit), N'2B'),
                        (42, @ReturnFlightId, CAST(0 AS bit), N'2C');

                    SET IDENTITY_INSERT [FlightSeats] OFF;
                END
                """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql(
                """
                DECLARE @ReturnFlightId int = (
                    SELECT TOP(1) [Id]
                    FROM [Flights]
                    WHERE [FlightNumber] = N'JG108'
                );

                IF @ReturnFlightId IS NOT NULL
                BEGIN
                    DELETE FROM [FlightSeats]
                    WHERE [FlightId] = @ReturnFlightId
                      AND [SeatNumber] IN (N'1A', N'1B', N'1C', N'2A', N'2B', N'2C');

                    DELETE FROM [Flights]
                    WHERE [Id] = @ReturnFlightId
                      AND [FlightNumber] = N'JG108';
                END

                DELETE FROM [Destinations]
                WHERE [Id] = 7
                  AND [RouteCode] = N'IST-OMO'
                  AND NOT EXISTS (
                      SELECT 1
                      FROM [Flights]
                      WHERE [DestinationId] = 7
                  );
                """);
        }
    }
}