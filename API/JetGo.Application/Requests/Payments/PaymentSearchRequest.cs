using System.ComponentModel.DataAnnotations;
using JetGo.Application.Requests.Common;
using JetGo.Domain.Enums;

namespace JetGo.Application.Requests.Payments;

public sealed class PaymentSearchRequest : PagedRequest
{
    public PaymentStatus? Status { get; init; }

    public int? ReservationId { get; init; }

    [MaxLength(100, ErrorMessage = "Pretraga moze sadrzavati maksimalno 100 karaktera.")]
    public string? SearchText { get; init; }

    public DateTime? CreatedFromUtc { get; init; }

    public DateTime? CreatedToUtc { get; init; }
}
