using JetGo.Domain.Entities;
using Microsoft.AspNetCore.Identity;

namespace JetGo.Infrastructure.Identity;

public sealed class AppUser : IdentityUser
{
    public UserProfile? UserProfile { get; set; }

    public ICollection<Notification> Notifications { get; set; } = new List<Notification>();

    public ICollection<RefreshToken> RefreshTokens { get; set; } = new List<RefreshToken>();

    public ICollection<Reservation> Reservations { get; set; } = new List<Reservation>();

    public ICollection<RevokedToken> RevokedTokens { get; set; } = new List<RevokedToken>();

    public ICollection<SearchHistory> SearchHistories { get; set; } = new List<SearchHistory>();

    public ICollection<SupportMessage> SupportMessages { get; set; } = new List<SupportMessage>();
}
