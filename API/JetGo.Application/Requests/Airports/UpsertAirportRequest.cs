using System.ComponentModel.DataAnnotations;

namespace JetGo.Application.Requests.Airports;

public sealed class UpsertAirportRequest
{
    [Range(1, int.MaxValue, ErrorMessage = "Grad je obavezan.")]
    public int CityId { get; init; }

    [Required(ErrorMessage = "Naziv aerodroma je obavezan.")]
    [MaxLength(150, ErrorMessage = "Naziv aerodroma moze sadrzavati maksimalno 150 karaktera.")]
    public string Name { get; init; } = string.Empty;

    [Required(ErrorMessage = "IATA kod je obavezan.")]
    [StringLength(3, MinimumLength = 3, ErrorMessage = "IATA kod mora sadrzavati tacno 3 karaktera.")]
    public string IataCode { get; init; } = string.Empty;

    [Range(typeof(decimal), "-90", "90", ErrorMessage = "Geografska sirina mora biti izmedju -90 i 90.")]
    public decimal? Latitude { get; init; }

    [Range(typeof(decimal), "-180", "180", ErrorMessage = "Geografska duzina mora biti izmedju -180 i 180.")]
    public decimal? Longitude { get; init; }
}
