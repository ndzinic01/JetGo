using System.ComponentModel.DataAnnotations;
using JetGo.Application.Requests.Common;
using JetGo.Domain.Enums;

namespace JetGo.Application.Requests.Flights;

public sealed class FlightSearchRequest : PagedRequest
{
    public int? DepartureAirportId { get; init; }

    public int? ArrivalAirportId { get; init; }

    public int? AirlineId { get; init; }

    [MaxLength(100, ErrorMessage = "Pretraga moze sadrzavati maksimalno 100 karaktera.")]
    public string? SearchText { get; init; }

    public DateTime? DepartureFromUtc { get; init; }

    public DateTime? DepartureToUtc { get; init; }

    [Range(typeof(decimal), "0", "999999999", ErrorMessage = "Minimalna cijena mora biti veca ili jednaka 0.")]
    public decimal? MinPrice { get; init; }

    [Range(typeof(decimal), "0", "999999999", ErrorMessage = "Maksimalna cijena mora biti veca ili jednaka 0.")]
    public decimal? MaxPrice { get; init; }

    public FlightStatus? Status { get; init; }
}
