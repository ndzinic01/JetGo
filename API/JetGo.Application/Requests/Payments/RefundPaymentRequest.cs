using System.ComponentModel.DataAnnotations;

namespace JetGo.Application.Requests.Payments;

public sealed class RefundPaymentRequest
{
    [Required(ErrorMessage = "Razlog refundiranja je obavezan.")]
    [MaxLength(500, ErrorMessage = "Razlog refundiranja moze sadrzavati maksimalno 500 karaktera.")]
    public string Reason { get; init; } = string.Empty;
}
