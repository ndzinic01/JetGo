using System.ComponentModel.DataAnnotations;
using JetGo.Domain.Enums;

namespace JetGo.Application.Requests.Reservations;

public sealed class ReservationPassengerRequest
{
    [Required(ErrorMessage = "Sjediste putnika je obavezno.")]
    [StringLength(10, ErrorMessage = "Oznaka sjedista moze imati maksimalno 10 karaktera.")]
    public string SeatNumber { get; init; } = string.Empty;

    [Required(ErrorMessage = "Ime putnika je obavezno.")]
    [StringLength(50, MinimumLength = 2, ErrorMessage = "Ime putnika mora imati izmedju 2 i 50 karaktera.")]
    [RegularExpression(@"^[\p{L}]+(?:[ '\-][\p{L}]+)*$", ErrorMessage = "Ime putnika smije sadrzavati samo slova, razmake, crticu i apostrof.")]
    public string FirstName { get; init; } = string.Empty;

    [Required(ErrorMessage = "Prezime putnika je obavezno.")]
    [StringLength(50, MinimumLength = 2, ErrorMessage = "Prezime putnika mora imati izmedju 2 i 50 karaktera.")]
    [RegularExpression(@"^[\p{L}]+(?:[ '\-][\p{L}]+)*$", ErrorMessage = "Prezime putnika smije sadrzavati samo slova, razmake, crticu i apostrof.")]
    public string LastName { get; init; } = string.Empty;

    [Range(1, 2, ErrorMessage = "Odaberite spol putnika.")]
    public PassengerGender Gender { get; init; }

    [Required(ErrorMessage = "Broj pasosa je obavezan.")]
    [StringLength(20, MinimumLength = 6, ErrorMessage = "Broj pasosa mora imati izmedju 6 i 20 karaktera.")]
    [RegularExpression(@"^[A-Za-z0-9]+$", ErrorMessage = "Broj pasosa smije sadrzavati samo slova i brojeve.")]
    public string PassportNumber { get; init; } = string.Empty;
}
