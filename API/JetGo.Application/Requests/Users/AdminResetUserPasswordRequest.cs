using System.ComponentModel.DataAnnotations;

namespace JetGo.Application.Requests.Users;

public sealed class AdminResetUserPasswordRequest
{
    [Required(ErrorMessage = "Nova lozinka je obavezna.")]
    [MinLength(4, ErrorMessage = "Nova lozinka mora sadrzavati najmanje 4 karaktera.")]
    public string NewPassword { get; init; } = string.Empty;

    [Required(ErrorMessage = "Potvrda lozinke je obavezna.")]
    [Compare(nameof(NewPassword), ErrorMessage = "Potvrda lozinke mora odgovarati novoj lozinci.")]
    public string ConfirmPassword { get; init; } = string.Empty;
}
