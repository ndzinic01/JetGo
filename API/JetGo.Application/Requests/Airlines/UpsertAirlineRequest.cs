using System.ComponentModel.DataAnnotations;

namespace JetGo.Application.Requests.Airlines;

public sealed class UpsertAirlineRequest
{
    [Required(ErrorMessage = "Naziv aviokompanije je obavezan.")]
    [MaxLength(150, ErrorMessage = "Naziv aviokompanije moze sadrzavati maksimalno 150 karaktera.")]
    public string Name { get; init; } = string.Empty;

    [Required(ErrorMessage = "Kod aviokompanije je obavezan.")]
    [MaxLength(10, ErrorMessage = "Kod aviokompanije moze sadrzavati maksimalno 10 karaktera.")]
    public string Code { get; init; } = string.Empty;

    [MaxLength(500, ErrorMessage = "Logo URL moze sadrzavati maksimalno 500 karaktera.")]
    public string? LogoUrl { get; init; }

    public bool IsActive { get; init; } = true;
}
