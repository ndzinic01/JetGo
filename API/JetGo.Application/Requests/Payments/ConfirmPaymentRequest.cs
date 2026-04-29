using System.ComponentModel.DataAnnotations;

namespace JetGo.Application.Requests.Payments;

public sealed class ConfirmPaymentRequest
{
    [Required(ErrorMessage = "Provider reference je obavezan za potvrdu placanja.")]
    [MaxLength(200, ErrorMessage = "Provider reference moze sadrzavati maksimalno 200 karaktera.")]
    public string ProviderReference { get; init; } = string.Empty;

    [MaxLength(500, ErrorMessage = "Napomena moze sadrzavati maksimalno 500 karaktera.")]
    public string? Reason { get; init; }
}
