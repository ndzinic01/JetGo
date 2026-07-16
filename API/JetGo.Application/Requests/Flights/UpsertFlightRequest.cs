using System.ComponentModel.DataAnnotations;
using JetGo.Domain.Enums;

namespace JetGo.Application.Requests.Flights;

public sealed class UpsertFlightRequest
{
    [Range(1, int.MaxValue, ErrorMessage = "Aviokompanija je obavezna.")]
    public int AirlineId { get; init; }

    [Range(1, int.MaxValue, ErrorMessage = "Destinacija je obavezna.")]
    public int DestinationId { get; init; }

    [Required(ErrorMessage = "Broj leta je obavezan.")]
    [MaxLength(20, ErrorMessage = "Broj leta moze sadrzavati maksimalno 20 karaktera.")]
    [RegularExpression("^[A-Za-z]{1,3}[- ]?\\d{1,4}[A-Za-z]?$", ErrorMessage = "Broj leta mora biti u formatu poput JG101 ili OU-215.")]
    public string FlightNumber { get; init; } = string.Empty;

    public DateTime DepartureAtUtc { get; init; }

    public DateTime ArrivalAtUtc { get; init; }

    [Range(typeof(decimal), "0.01", "999999999", ErrorMessage = "Cijena mora biti veca od 0.")]
    public decimal BasePrice { get; init; }

    [Range(1, 300, ErrorMessage = "Ukupan broj sjedista mora biti izmedju 1 i 300.")]
    public int TotalSeats { get; init; }

    public FlightStatus Status { get; init; } = FlightStatus.Scheduled;
}
