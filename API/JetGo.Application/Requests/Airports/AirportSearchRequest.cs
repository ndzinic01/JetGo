using System.ComponentModel.DataAnnotations;
using JetGo.Application.Requests.Common;

namespace JetGo.Application.Requests.Airports;

public sealed class AirportSearchRequest : PagedRequest
{
    public int? CountryId { get; init; }

    public int? CityId { get; init; }

    [MaxLength(150, ErrorMessage = "Pretraga moze sadrzavati maksimalno 150 karaktera.")]
    public string? SearchText { get; init; }
}
