using JetGo.Domain.Enums;

namespace JetGo.Application.DTOs.Reservations;

public sealed class ReservationListItemDto
{
    public int Id { get; init; }

    public string ReservationCode { get; init; } = string.Empty;

    public int FlightId { get; init; }

    public string FlightNumber { get; init; } = string.Empty;

    public string RouteCode { get; init; } = string.Empty;

    public string DepartureAirportCode { get; init; } = string.Empty;

    public string ArrivalAirportCode { get; init; } = string.Empty;

    public DateTime DepartureAtUtc { get; init; }

    public ReservationStatus Status { get; init; }

    public decimal TotalAmount { get; init; }

    public string Currency { get; init; } = "BAM";

    public int? PaymentId { get; init; }

    public PaymentStatus? PaymentStatus { get; init; }

    public bool IsPaid { get; init; }

    public int SeatsCount { get; init; }

    public DateTime CreatedAtUtc { get; init; }

    public string CustomerName { get; init; } = string.Empty;
}
