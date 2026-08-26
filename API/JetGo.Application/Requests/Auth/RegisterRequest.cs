using System.ComponentModel.DataAnnotations;

namespace JetGo.Application.Requests.Auth;

public sealed class RegisterRequest
{
    [Required(ErrorMessage = "Korisnicko ime je obavezno.")]
    [MinLength(3, ErrorMessage = "Korisnicko ime mora sadrzavati najmanje 3 karaktera.")]
    [MaxLength(50, ErrorMessage = "Korisnicko ime moze sadrzavati maksimalno 50 karaktera.")]
    [RegularExpression(@"^[A-Za-z0-9._-]+$", ErrorMessage = "Korisnicko ime smije sadrzavati slova, brojeve, tacku, donju crtu i crticu.")]
    public string Username { get; init; } = string.Empty;

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
    [MaxLength(200, ErrorMessage = "Email adresa moze sadrzavati maksimalno 200 karaktera.")]
    public string Email { get; init; } = string.Empty;

    [Required(ErrorMessage = "Broj telefona je obavezan.")]
    [RegularExpression(@"^\+387[1-9][0-9]{7,8}$", ErrorMessage = "Broj telefona mora pocinjati sa +387 i imati jos 8 ili 9 cifara bez pocetne nule, npr. +38761805861.")]
    [MaxLength(30, ErrorMessage = "Broj telefona moze sadrzavati maksimalno 30 karaktera.")]
    public string PhoneNumber { get; init; } = string.Empty;

    [Required(ErrorMessage = "Lozinka je obavezna.")]
    [MinLength(4, ErrorMessage = "Lozinka mora sadrzavati najmanje 4 karaktera.")]
    public string Password { get; init; } = string.Empty;

    [Required(ErrorMessage = "Potvrda lozinke je obavezna.")]
    [Compare(nameof(Password), ErrorMessage = "Lozinka i potvrda lozinke moraju biti iste.")]
    public string ConfirmPassword { get; init; } = string.Empty;
}
