using System.ComponentModel.DataAnnotations;

namespace JetGo.Application.Requests.SupportMessages;

public sealed class ReplyToSupportMessageRequest
{
    [Required(ErrorMessage = "Odgovor administratora je obavezan.")]
    [MaxLength(4000, ErrorMessage = "Odgovor administratora moze sadrzavati maksimalno 4000 karaktera.")]
    public string AdminReply { get; init; } = string.Empty;
}
