using System.ComponentModel.DataAnnotations;

namespace JetGo.Application.Requests.Countries;

public sealed class UpsertCountryRequest
{
    [Required(ErrorMessage = "Naziv drzave je obavezan.")]
    [MaxLength(100, ErrorMessage = "Naziv drzave moze sadrzavati maksimalno 100 karaktera.")]
    public string Name { get; init; } = string.Empty;

    [Required(ErrorMessage = "ISO kod drzave je obavezan.")]
    [StringLength(2, MinimumLength = 2, ErrorMessage = "ISO kod drzave mora sadrzavati tacno 2 karaktera.")]
    public string IsoCode { get; init; } = string.Empty;
}
