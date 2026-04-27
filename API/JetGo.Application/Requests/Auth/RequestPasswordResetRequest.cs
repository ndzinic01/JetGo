using System.ComponentModel.DataAnnotations;

namespace JetGo.Application.Requests.Auth;

public sealed class RequestPasswordResetRequest
{
    [Required(ErrorMessage = "Email adresa je obavezna.")]
    [EmailAddress(ErrorMessage = "Unesite validnu email adresu u formatu korisnik@domena.com.")]
    [MaxLength(200, ErrorMessage = "Email adresa moze sadrzavati maksimalno 200 karaktera.")]
    public string Email { get; init; } = string.Empty;
}
