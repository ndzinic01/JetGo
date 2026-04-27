using System.ComponentModel.DataAnnotations;
using JetGo.Application.Requests.Common;
using JetGo.Domain.Enums;

namespace JetGo.Application.Requests.Notifications;

public sealed class NotificationSearchRequest : PagedRequest
{
    public NotificationStatus? Status { get; init; }

    public DateTime? ChangedAfterUtc { get; init; }

    [MaxLength(100, ErrorMessage = "Pretraga moze sadrzavati maksimalno 100 karaktera.")]
    public string? SearchText { get; init; }
}
