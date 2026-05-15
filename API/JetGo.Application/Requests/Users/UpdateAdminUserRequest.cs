using System.ComponentModel.DataAnnotations;

namespace JetGo.Application.Requests.Users;

public sealed class UpdateAdminUserRequest
{
    [Required(ErrorMessage = "Ime je obavezno.")]
    [MaxLength(100, ErrorMessage = "Ime moze sadrzavati maksimalno 100 karaktera.")]
    public string FirstName { get; init; } = string.Empty;

    [Required(ErrorMessage = "Prezime je obavezno.")]
    [MaxLength(100, ErrorMessage = "Prezime moze sadrzavati maksimalno 100 karaktera.")]
    public string LastName { get; init; } = string.Empty;

    [Required(ErrorMessage = "Email adresa je obavezna.")]
    [EmailAddress(ErrorMessage = "Unesite validnu email adresu.")]
    [MaxLength(256, ErrorMessage = "Email adresa moze sadrzavati maksimalno 256 karaktera.")]
    public string Email { get; init; } = string.Empty;

    [MaxLength(50, ErrorMessage = "Broj telefona moze sadrzavati maksimalno 50 karaktera.")]
    public string? PhoneNumber { get; init; }

    [MaxLength(500, ErrorMessage = "Slika profila moze sadrzavati maksimalno 500 karaktera.")]
    public string? ImageUrl { get; init; }

    [Required(ErrorMessage = "Korisnicke role su obavezne.")]
    [MinLength(1, ErrorMessage = "Korisnik mora imati barem jednu rolu.")]
    public string[] Roles { get; init; } = Array.Empty<string>();
}
