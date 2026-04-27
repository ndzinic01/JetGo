using System.ComponentModel.DataAnnotations;

namespace JetGo.Application.Requests.Profile;

public sealed class ChangePasswordRequest
{
    [Required(ErrorMessage = "Trenutna lozinka je obavezna.")]
    public string CurrentPassword { get; init; } = string.Empty;

    [Required(ErrorMessage = "Nova lozinka je obavezna.")]
    [MinLength(4, ErrorMessage = "Nova lozinka mora sadrzavati najmanje 4 karaktera.")]
    public string NewPassword { get; init; } = string.Empty;

    [Required(ErrorMessage = "Potvrda nove lozinke je obavezna.")]
    [Compare(nameof(NewPassword), ErrorMessage = "Nova lozinka i potvrda lozinke moraju biti iste.")]
    public string ConfirmPassword { get; init; } = string.Empty;
}
