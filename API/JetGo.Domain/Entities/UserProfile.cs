using JetGo.Domain.Common;

namespace JetGo.Domain.Entities;

public sealed class UserProfile : AuditableEntity
{
    public string UserId { get; set; } = string.Empty;

    public string FirstName { get; set; } = string.Empty;

    public string LastName { get; set; } = string.Empty;

    public string Email { get; set; } = string.Empty;

    public string? PhoneNumber { get; set; }

    public string? ImageUrl { get; set; }
}
