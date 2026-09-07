using System.Text.Json.Serialization;
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

    public FlightStatus FlightStatus { get; init; }

    [JsonIgnore]
    public bool FlightAirlineIsActive { get; init; } = true;

    [JsonIgnore]
    public bool FlightDestinationIsActive { get; init; } = true;

    public ReservationStatus Status { get; init; }

    public decimal TotalAmount { get; init; }

    public string Currency { get; init; } = "BAM";

    public decimal SeatsTotalAmount { get; init; }

    public int AdditionalBaggageCount { get; init; }

    public decimal AdditionalBaggageUnitPrice { get; init; }

    public decimal AdditionalBaggageTotalAmount { get; init; }

    public int? PaymentId { get; init; }

    public PaymentStatus? PaymentStatus { get; init; }

    public bool IsPaid { get; init; }

    public bool HasCapturedPayment { get; init; }

    public DateTime CreatedAtUtc { get; init; }

    public DateTime? StatusChangedAtUtc { get; init; }

    public string? StatusChangedByUserId { get; init; }

    public string? StatusChangedByUserDisplayName { get; set; }

    public string? StatusReason { get; init; }

    public ReservationCustomerDto Customer { get; init; } = new();

    public IReadOnlyCollection<ReservationSeatDto> Seats { get; init; } = Array.Empty<ReservationSeatDto>();

    public IReadOnlyCollection<ReservationPassengerDto> Passengers { get; init; } = Array.Empty<ReservationPassengerDto>();

    public bool CanBeCancelled { get; set; }

    public bool CanBeConfirmed { get; set; }

    public bool CanBeCompleted { get; set; }

    public bool CanInitiatePayment { get; set; }

    public bool CanBeRefunded { get; set; }

    public bool CanUpdateBaggage { get; set; }

    public bool CanChangeReservation { get; set; }
}
