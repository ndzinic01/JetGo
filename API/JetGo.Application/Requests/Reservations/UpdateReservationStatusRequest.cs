using System.ComponentModel.DataAnnotations;

namespace JetGo.Application.Requests.Reservations;

public sealed class UpdateReservationStatusRequest
{
    [MaxLength(500, ErrorMessage = "Napomena moze sadrzavati maksimalno 500 karaktera.")]
    public string? Reason { get; init; }
}
