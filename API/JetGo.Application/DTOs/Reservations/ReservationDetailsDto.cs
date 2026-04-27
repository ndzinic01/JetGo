using JetGo.Domain.Enums;

namespace JetGo.Application.DTOs.Reservations;

public sealed class ReservationDetailsDto
{
    public int Id { get; init; }

    public string ReservationCode { get; init; } = string.Empty;

    public int FlightId { get; init; }

    public string FlightNumber { get; init; } = string.Empty;

    public string RouteCode { get; init; } = string.Empty;

    public string DepartureAirportCode { get; init; } = string.Empty;

    public string ArrivalAirportCode { get; init; } = string.Empty;

    public DateTime DepartureAtUtc { get; init; }

    public DateTime ArrivalAtUtc { get; init; }

    public ReservationStatus Status { get; init; }

    public decimal TotalAmount { get; init; }

    public string Currency { get; init; } = "BAM";

    public DateTime CreatedAtUtc { get; init; }

    public DateTime? StatusChangedAtUtc { get; init; }

    public string? StatusChangedByUserId { get; init; }

    public string? StatusReason { get; init; }

    public ReservationCustomerDto Customer { get; init; } = new();

    public IReadOnlyCollection<ReservationSeatDto> Seats { get; init; } = Array.Empty<ReservationSeatDto>();

    public bool CanBeCancelled { get; set; }

    public bool CanBeConfirmed { get; set; }

    public bool CanBeCompleted { get; set; }
}
