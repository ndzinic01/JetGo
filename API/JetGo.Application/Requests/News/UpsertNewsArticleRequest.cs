using System.ComponentModel.DataAnnotations;

namespace JetGo.Application.Requests.News;

public sealed class UpsertNewsArticleRequest
{
    [Required(ErrorMessage = "Naslov je obavezan.")]
    [MaxLength(200, ErrorMessage = "Naslov moze sadrzavati maksimalno 200 karaktera.")]
    public string Title { get; init; } = string.Empty;

    [Required(ErrorMessage = "Tekst obavijesti je obavezan.")]
    [MaxLength(4000, ErrorMessage = "Tekst obavijesti moze sadrzavati maksimalno 4000 karaktera.")]
    public string Content { get; init; } = string.Empty;

    [Required(ErrorMessage = "Slika obavijesti je obavezna.")]
    [MaxLength(500, ErrorMessage = "Putanja ili URL slike moze sadrzavati maksimalno 500 karaktera.")]
    public string ImageUrl { get; init; } = string.Empty;

    public bool IsPublished { get; init; } = true;

    public DateTime? PublishedAtUtc { get; init; }
}
