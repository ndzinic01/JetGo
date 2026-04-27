using System.ComponentModel.DataAnnotations;

namespace JetGo.Application.Requests.Auth;

public sealed class ResetPasswordRequest
{
    [Required(ErrorMessage = "Email adresa je obavezna.")]
    [EmailAddress(ErrorMessage = "Unesite validnu email adresu u formatu korisnik@domena.com.")]
    [MaxLength(200, ErrorMessage = "Email adresa moze sadrzavati maksimalno 200 karaktera.")]
    public string Email { get; init; } = string.Empty;

    [Required(ErrorMessage = "Reset token je obavezan.")]
    public string Token { get; init; } = string.Empty;

    [Required(ErrorMessage = "Nova lozinka je obavezna.")]
    [MinLength(4, ErrorMessage = "Nova lozinka mora sadrzavati najmanje 4 karaktera.")]
    public string NewPassword { get; init; } = string.Empty;

    [Required(ErrorMessage = "Potvrda nove lozinke je obavezna.")]
    [Compare(nameof(NewPassword), ErrorMessage = "Nova lozinka i potvrda lozinke moraju biti iste.")]
    public string ConfirmPassword { get; init; } = string.Empty;
}
