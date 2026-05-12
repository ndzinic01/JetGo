using System.ComponentModel.DataAnnotations;

namespace JetGo.Application.Requests.Payments;

public sealed class ConfirmPaymentRequest
{
    [MaxLength(200, ErrorMessage = "Provider reference moze sadrzavati maksimalno 200 karaktera.")]
    public string? ProviderReference { get; init; }

    [MaxLength(500, ErrorMessage = "Napomena moze sadrzavati maksimalno 500 karaktera.")]
    public string? Reason { get; init; }
}
