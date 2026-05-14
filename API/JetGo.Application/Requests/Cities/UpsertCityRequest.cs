using System.ComponentModel.DataAnnotations;

namespace JetGo.Application.Requests.Cities;

public sealed class UpsertCityRequest
{
    [Range(1, int.MaxValue, ErrorMessage = "Drzava je obavezna.")]
    public int CountryId { get; init; }

    [Required(ErrorMessage = "Naziv grada je obavezan.")]
    [MaxLength(100, ErrorMessage = "Naziv grada moze sadrzavati maksimalno 100 karaktera.")]
    public string Name { get; init; } = string.Empty;
}
