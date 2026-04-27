using System.ComponentModel.DataAnnotations;
using JetGo.Application.Requests.Common;

namespace JetGo.Application.Requests.Destinations;

public sealed class DestinationSearchRequest : PagedRequest
{
    public int? DepartureAirportId { get; init; }

    public int? ArrivalAirportId { get; init; }

    public bool? IsActive { get; init; }

    [MaxLength(100, ErrorMessage = "Pretraga moze sadrzavati maksimalno 100 karaktera.")]
    public string? SearchText { get; init; }
}
