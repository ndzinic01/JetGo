using System.ComponentModel.DataAnnotations;
using JetGo.Application.Requests.Common;

namespace JetGo.Application.Requests.Users;

public sealed class AdminUserSearchRequest : PagedRequest
{
    [MaxLength(150, ErrorMessage = "Pretraga moze sadrzavati maksimalno 150 karaktera.")]
    public string? SearchText { get; init; }

    [MaxLength(50, ErrorMessage = "Naziv role moze sadrzavati maksimalno 50 karaktera.")]
    public string? RoleName { get; init; }

    public bool? IsActive { get; init; }
}
