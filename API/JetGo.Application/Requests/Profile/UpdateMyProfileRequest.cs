using System.ComponentModel.DataAnnotations;

namespace JetGo.Application.Requests.Profile;

public sealed class UpdateMyProfileRequest
{
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

    [MaxLength(500, ErrorMessage = "Putanja ili URL slike moze sadrzavati maksimalno 500 karaktera.")]
    public string? ImageUrl { get; init; }
}
