using System.ComponentModel.DataAnnotations;
using JetGo.Application.Requests.Common;

namespace JetGo.Application.Requests.Airlines;

public sealed class AirlineSearchRequest : PagedRequest
{
    public bool? IsActive { get; init; }

    [MaxLength(150, ErrorMessage = "Pretraga moze sadrzavati maksimalno 150 karaktera.")]
    public string? SearchText { get; init; }
}
