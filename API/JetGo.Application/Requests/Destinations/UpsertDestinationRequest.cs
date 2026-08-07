using System.ComponentModel.DataAnnotations;

namespace JetGo.Application.Requests.Destinations;

public sealed class UpsertDestinationRequest
{
    [Range(1, int.MaxValue, ErrorMessage = "Polazni aerodrom je obavezan.")]
    public int DepartureAirportId { get; init; }

    [Range(1, int.MaxValue, ErrorMessage = "Dolazni aerodrom je obavezan.")]
    public int ArrivalAirportId { get; init; }

    [MaxLength(500, ErrorMessage = "URL slike moze sadrzavati maksimalno 500 karaktera.")]
    [Url(ErrorMessage = "URL slike mora biti validan link, npr. https://example.com/slika.jpg.")]
    public string? ImageUrl { get; init; }

    public bool IsActive { get; init; } = true;
}
