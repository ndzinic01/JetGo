using System.ComponentModel.DataAnnotations;
using JetGo.Application.Requests.Common;

namespace JetGo.Application.Requests.SupportMessages;

public sealed class SupportMessageSearchRequest : PagedRequest
{
    public bool? IsReplied { get; init; }

    [MaxLength(100, ErrorMessage = "Pretraga moze sadrzavati maksimalno 100 karaktera.")]
    public string? SearchText { get; init; }

    public DateTime? CreatedFromUtc { get; init; }

    public DateTime? CreatedToUtc { get; init; }
}
