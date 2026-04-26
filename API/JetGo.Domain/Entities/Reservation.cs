using JetGo.Domain.Common;
using JetGo.Domain.Enums;

namespace JetGo.Domain.Entities;

public sealed class Reservation : AuditableEntity
{
    public string UserId { get; set; } = string.Empty;

    public int FlightId { get; set; }

    public Flight Flight { get; set; } = null!;

    public ReservationStatus Status { get; set; } = ReservationStatus.Pending;

    public decimal TotalAmount { get; set; }

    public string Currency { get; set; } = "BAM";

    public ICollection<ReservationItem> Items { get; set; } = new List<ReservationItem>();

    public Payment? Payment { get; set; }
}
