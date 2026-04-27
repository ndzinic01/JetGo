using System.ComponentModel.DataAnnotations;

namespace JetGo.Application.Requests.Reservations;

public sealed class CreateReservationRequest
{
    [Range(1, int.MaxValue, ErrorMessage = "FlightId mora biti veci od 0.")]
    public int FlightId { get; init; }

    [Required(ErrorMessage = "Morate odabrati najmanje jedno sjediste.")]
    [MinLength(1, ErrorMessage = "Morate odabrati najmanje jedno sjediste.")]
    [MaxLength(6, ErrorMessage = "Maksimalno je dozvoljeno odabrati 6 sjedista po rezervaciji.")]
    public string[] SeatNumbers { get; init; } = Array.Empty<string>();
}
