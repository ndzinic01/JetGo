using System.ComponentModel.DataAnnotations;

namespace JetGo.Application.Requests.Auth;

public sealed class RegisterRequest
{
    [Required(ErrorMessage = "Korisnicko ime je obavezno.")]
    [MaxLength(50, ErrorMessage = "Korisnicko ime moze sadrzavati maksimalno 50 karaktera.")]
    public string Username { get; init; } = string.Empty;

    [Required(ErrorMessage = "Ime je obavezno.")]
    [MaxLength(100, ErrorMessage = "Ime moze sadrzavati maksimalno 100 karaktera.")]
    public string FirstName { get; init; } = string.Empty;

    [Required(ErrorMessage = "Prezime je obavezno.")]
    [MaxLength(100, ErrorMessage = "Prezime moze sadrzavati maksimalno 100 karaktera.")]
    public string LastName { get; init; } = string.Empty;

    [Required(ErrorMessage = "Email adresa je obavezna.")]
    [EmailAddress(ErrorMessage = "Unesite validnu email adresu u formatu korisnik@domena.com.")]
    [MaxLength(200, ErrorMessage = "Email adresa moze sadrzavati maksimalno 200 karaktera.")]
    public string Email { get; init; } = string.Empty;

    [Phone(ErrorMessage = "Unesite validan broj telefona.")]
    [MaxLength(30, ErrorMessage = "Broj telefona moze sadrzavati maksimalno 30 karaktera.")]
    public string? PhoneNumber { get; init; }

    [Required(ErrorMessage = "Lozinka je obavezna.")]
    [MinLength(4, ErrorMessage = "Lozinka mora sadrzavati najmanje 4 karaktera.")]
    public string Password { get; init; } = string.Empty;

    [Required(ErrorMessage = "Potvrda lozinke je obavezna.")]
    [Compare(nameof(Password), ErrorMessage = "Lozinka i potvrda lozinke moraju biti iste.")]
    public string ConfirmPassword { get; init; } = string.Empty;
}
