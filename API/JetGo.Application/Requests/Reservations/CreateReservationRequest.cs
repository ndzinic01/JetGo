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

    [Range(0, 6, ErrorMessage = "Dodatni prtljag mora biti izmedju 0 i 6 komada.")]
    public int AdditionalBaggageCount { get; init; }

    [Required(ErrorMessage = "Podaci putnika su obavezni.")]
    [MinLength(1, ErrorMessage = "Morate unijeti podatke za najmanje jednog putnika.")]
    [MaxLength(6, ErrorMessage = "Maksimalno je dozvoljeno 6 putnika po rezervaciji.")]
    public ReservationPassengerRequest[] Passengers { get; init; } = Array.Empty<ReservationPassengerRequest>();
}
