using System.ComponentModel.DataAnnotations;
using JetGo.Application.Requests.Common;

namespace JetGo.Application.Requests.News;

public sealed class NewsSearchRequest : PagedRequest
{
    public bool? IsPublished { get; init; }

    public DateTime? PublishedAfterUtc { get; init; }

    [MaxLength(100, ErrorMessage = "Pretraga moze sadrzavati maksimalno 100 karaktera.")]
    public string? SearchText { get; init; }
}
