using System.ComponentModel.DataAnnotations;

namespace JetGo.Application.Requests.Auth;

public sealed class LoginRequest
{
    [Required(ErrorMessage = "Korisnicko ime je obavezno.")]
    [MaxLength(50, ErrorMessage = "Korisnicko ime moze sadrzavati maksimalno 50 karaktera.")]
    public string Username { get; init; } = string.Empty;

    [Required(ErrorMessage = "Lozinka je obavezna.")]
    public string Password { get; init; } = string.Empty;
}
