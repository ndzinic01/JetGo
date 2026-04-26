using JetGo.Domain.Common;

namespace JetGo.Domain.Entities;

public sealed class FlightSeat : BaseEntity
{
    public int FlightId { get; set; }

    public Flight Flight { get; set; } = null!;

    public string SeatNumber { get; set; } = string.Empty;

    public bool IsReserved { get; set; }
}
