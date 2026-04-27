using System.ComponentModel.DataAnnotations;
using JetGo.Application.Requests.Common;
using JetGo.Domain.Enums;

namespace JetGo.Application.Requests.Reservations;

public sealed class ReservationSearchRequest : PagedRequest
{
    public ReservationStatus? Status { get; init; }

    public int? FlightId { get; init; }

    [MaxLength(100, ErrorMessage = "Pretraga moze sadrzavati maksimalno 100 karaktera.")]
    public string? SearchText { get; init; }

    public DateTime? CreatedFromUtc { get; init; }

    public DateTime? CreatedToUtc { get; init; }
}
