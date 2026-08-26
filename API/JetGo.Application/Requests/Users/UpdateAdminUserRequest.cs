using System.ComponentModel.DataAnnotations;

namespace JetGo.Application.Requests.Users;

public sealed class UpdateAdminUserRequest
{
    [Required(ErrorMessage = "Ime je obavezno.")]
    [MaxLength(100, ErrorMessage = "Ime moze sadrzavati maksimalno 100 karaktera.")]
    [RegularExpression(@"^[\p{L}]+(?: [\p{L}]+)*$", ErrorMessage = "Ime smije sadrzavati samo slova i razmake.")]
    public string FirstName { get; init; } = string.Empty;

    [Required(ErrorMessage = "Prezime je obavezno.")]
    [MaxLength(100, ErrorMessage = "Prezime moze sadrzavati maksimalno 100 karaktera.")]
    [RegularExpression(@"^[\p{L}]+(?: [\p{L}]+)*$", ErrorMessage = "Prezime smije sadrzavati samo slova i razmake.")]
    public string LastName { get; init; } = string.Empty;

    [Required(ErrorMessage = "Email adresa je obavezna.")]
    [EmailAddress(ErrorMessage = "Email adresa mora biti u formatu korisnik@domena.com.")]
    [MaxLength(256, ErrorMessage = "Email adresa moze sadrzavati maksimalno 256 karaktera.")]
    public string Email { get; init; } = string.Empty;

    [RegularExpression(@"^\+?[0-9]{8,15}$", ErrorMessage = "Broj telefona mora imati 8 do 15 cifara i smije imati samo + na pocetku, npr. +38761123456.")]
    [MaxLength(50, ErrorMessage = "Broj telefona moze sadrzavati maksimalno 50 karaktera.")]
    public string? PhoneNumber { get; init; }

    [MaxLength(500, ErrorMessage = "Slika profila moze sadrzavati maksimalno 500 karaktera.")]
    public string? ImageUrl { get; init; }

    [Required(ErrorMessage = "Korisnicke role su obavezne.")]
    [MinLength(1, ErrorMessage = "Korisnik mora imati barem jednu rolu.")]
    public string[] Roles { get; init; } = Array.Empty<string>();
}
