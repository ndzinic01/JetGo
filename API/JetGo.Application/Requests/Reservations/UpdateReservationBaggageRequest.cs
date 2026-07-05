using System.ComponentModel.DataAnnotations;

namespace JetGo.Application.Requests.Reservations;

public sealed class UpdateReservationBaggageRequest
{
    [Range(0, 6, ErrorMessage = "Dodatni prtljag mora biti izmedju 0 i 6 komada.")]
    public int AdditionalBaggageCount { get; init; }
}
