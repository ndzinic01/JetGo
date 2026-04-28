using System.ComponentModel.DataAnnotations;

namespace JetGo.Application.Requests.SupportMessages;

public sealed class CreateSupportMessageRequest
{
    [Required(ErrorMessage = "Naslov upita je obavezan.")]
    [MaxLength(200, ErrorMessage = "Naslov upita moze sadrzavati maksimalno 200 karaktera.")]
    public string Subject { get; init; } = string.Empty;

    [Required(ErrorMessage = "Sadrzaj upita je obavezan.")]
    [MaxLength(4000, ErrorMessage = "Sadrzaj upita moze sadrzavati maksimalno 4000 karaktera.")]
    public string Message { get; init; } = string.Empty;
}
