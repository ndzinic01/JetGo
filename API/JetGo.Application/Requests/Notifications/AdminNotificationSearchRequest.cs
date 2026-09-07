using System.ComponentModel.DataAnnotations;
using JetGo.Application.Requests.Common;
using JetGo.Domain.Enums;

namespace JetGo.Application.Requests.Notifications;

public sealed class AdminNotificationSearchRequest : PagedRequest
{
    public NotificationStatus? Status { get; init; }

    public NotificationType? Type { get; init; }

    public DateTime? CreatedFromUtc { get; init; }

    public DateTime? CreatedToUtc { get; init; }

    [MaxLength(30, ErrorMessage = "Broj leta moze sadrzavati maksimalno 30 karaktera.")]
    public string? FlightNumber { get; init; }

    [MaxLength(100, ErrorMessage = "Pretraga moze sadrzavati maksimalno 100 karaktera.")]
    public string? SearchText { get; init; }
}
