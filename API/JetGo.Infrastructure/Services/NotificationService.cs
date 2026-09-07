using System.Security.Claims;
using JetGo.Application.Contracts.Services;
using JetGo.Application.DTOs.Common;
using JetGo.Application.DTOs.Notifications;
using JetGo.Application.Exceptions;
using JetGo.Application.Requests.Notifications;
using JetGo.Domain.Enums;
using JetGo.Infrastructure.Persistence;
using JetGo.Infrastructure.Services.Common;
using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;

namespace JetGo.Infrastructure.Services;

public sealed class NotificationService : INotificationService
{
    private readonly JetGoDbContext _dbContext;
    private readonly IHttpContextAccessor _httpContextAccessor;

    public NotificationService(JetGoDbContext dbContext, IHttpContextAccessor httpContextAccessor)
    {
        _dbContext = dbContext;
        _httpContextAccessor = httpContextAccessor;
    }

    public async Task<PagedResponseDto<NotificationListItemDto>> GetMineAsync(NotificationSearchRequest request, CancellationToken cancellationToken = default)
    {
        var currentUserId = GetRequiredCurrentUserId();
        var query = _dbContext.Notifications
            .AsNoTracking()
            .Where(x => x.UserId == currentUserId);

        if (request.Status.HasValue)
        {
            query = query.Where(x => x.Status == request.Status.Value);
        }

        if (request.ChangedAfterUtc.HasValue)
        {
            var changedAfterUtc = request.ChangedAfterUtc.Value;
            query = query.Where(x => x.CreatedAtUtc > changedAfterUtc || (x.ReadAtUtc.HasValue && x.ReadAtUtc > changedAfterUtc));
        }

        if (!string.IsNullOrWhiteSpace(request.SearchText))
        {
            var searchText = request.SearchText.Trim();
            query = query.Where(x =>
                x.Title.Contains(searchText) ||
                x.Body.Contains(searchText) ||
                (x.FlightNumber != null && x.FlightNumber.Contains(searchText)) ||
                (x.ReservationCode != null && x.ReservationCode.Contains(searchText)));
        }

        var totalCount = await query.CountAsync(cancellationToken);

        var items = await query
            .OrderByDescending(x => x.CreatedAtUtc)
            .ThenByDescending(x => x.Id)
            .Skip((request.Page - 1) * request.PageSize)
            .Take(request.PageSize)
            .Select(x => new NotificationListItemDto
            {
                Id = x.Id,
                Title = x.Title,
                Body = x.Body,
                Status = x.Status,
                CreatedAtUtc = x.CreatedAtUtc,
                ReadAtUtc = x.ReadAtUtc
            })
            .ToListAsync(cancellationToken);

        return PagedResponseBuilder.Build(items, request.Page, request.PageSize, totalCount);
    }

    public async Task<PagedResponseDto<AdminNotificationListItemDto>> GetAdminPagedAsync(AdminNotificationSearchRequest request, CancellationToken cancellationToken = default)
    {
        ValidateAdminSearchRequest(request);

        var query =
            from notification in _dbContext.Notifications.AsNoTracking()
            join user in _dbContext.Users.AsNoTracking() on notification.UserId equals user.Id
            join profile in _dbContext.UserProfiles.AsNoTracking() on notification.UserId equals profile.UserId into profiles
            from profile in profiles.DefaultIfEmpty()
            where notification.Type != NotificationType.SupportReply
            select new
            {
                notification.Type,
                notification.Title,
                notification.Body,
                notification.Status,
                notification.CreatedAtUtc,
                notification.ReadAtUtc,
                notification.FlightNumber,
                notification.ReservationCode,
                UserName = user.UserName ?? string.Empty,
                UserEmail = user.Email ?? string.Empty,
                ProfileFirstName = profile != null ? profile.FirstName : null,
                ProfileLastName = profile != null ? profile.LastName : null,
                ProfileEmail = profile != null ? profile.Email : null
            };

        if (request.Status.HasValue)
        {
            query = query.Where(x => x.Status == request.Status.Value);
        }

        if (request.Type.HasValue)
        {
            query = query.Where(x => x.Type == request.Type.Value);
        }

        if (request.CreatedFromUtc.HasValue)
        {
            query = query.Where(x => x.CreatedAtUtc >= request.CreatedFromUtc.Value);
        }

        if (request.CreatedToUtc.HasValue)
        {
            query = query.Where(x => x.CreatedAtUtc <= request.CreatedToUtc.Value);
        }

        if (!string.IsNullOrWhiteSpace(request.FlightNumber))
        {
            var flightNumber = request.FlightNumber.Trim().ToUpperInvariant();
            query = query.Where(x => x.FlightNumber != null && x.FlightNumber.Contains(flightNumber));
        }

        if (!string.IsNullOrWhiteSpace(request.SearchText))
        {
            var searchText = request.SearchText.Trim();
            query = query.Where(x =>
                x.Title.Contains(searchText) ||
                x.Body.Contains(searchText) ||
                (x.FlightNumber != null && x.FlightNumber.Contains(searchText)) ||
                (x.ReservationCode != null && x.ReservationCode.Contains(searchText)) ||
                x.UserName.Contains(searchText) ||
                ((x.ProfileFirstName ?? string.Empty) + " " + (x.ProfileLastName ?? string.Empty)).Trim().Contains(searchText) ||
                (x.ProfileEmail ?? x.UserEmail).Contains(searchText));
        }

        var totalCount = await query.CountAsync(cancellationToken);

        var rawItems = await query
            .OrderByDescending(x => x.CreatedAtUtc)
            .ThenByDescending(x => x.FlightNumber)
            .Skip((request.Page - 1) * request.PageSize)
            .Take(request.PageSize)
            .ToListAsync(cancellationToken);

        var items = rawItems
            .Select(x => new AdminNotificationListItemDto
            {
                Type = x.Type,
                Title = x.Title,
                Body = x.Body,
                Status = x.Status,
                CreatedAtUtc = x.CreatedAtUtc,
                ReadAtUtc = x.ReadAtUtc,
                FlightNumber = x.FlightNumber,
                ReservationCode = x.ReservationCode,
                RecipientName = ResolveFullName(x.ProfileFirstName, x.ProfileLastName, x.UserName),
                RecipientEmail = x.ProfileEmail ?? x.UserEmail
            })
            .ToList();

        return PagedResponseBuilder.Build(items, request.Page, request.PageSize, totalCount);
    }

    public async Task<NotificationSummaryDto> GetSummaryAsync(CancellationToken cancellationToken = default)
    {
        var currentUserId = GetRequiredCurrentUserId();
        var summary = await _dbContext.Notifications
            .AsNoTracking()
            .Where(x => x.UserId == currentUserId)
            .GroupBy(_ => 1)
            .Select(x => new
            {
                TotalCount = x.Count(),
                UnreadCount = x.Count(y => y.Status == NotificationStatus.Unread),
                LatestCreatedAtUtc = x.Max(y => (DateTime?)y.CreatedAtUtc)
            })
            .SingleOrDefaultAsync(cancellationToken);

        return new NotificationSummaryDto
        {
            TotalCount = summary?.TotalCount ?? 0,
            UnreadCount = summary?.UnreadCount ?? 0,
            LatestCreatedAtUtc = summary?.LatestCreatedAtUtc
        };
    }

    public async Task MarkAsReadAsync(int id, CancellationToken cancellationToken = default)
    {
        var currentUserId = GetRequiredCurrentUserId();
        var notification = await _dbContext.Notifications
            .SingleOrDefaultAsync(x => x.Id == id, cancellationToken);

        if (notification is null)
        {
            throw new NotFoundException($"Notifikacija sa ID vrijednoscu {id} nije pronadjena.");
        }

        if (notification.UserId != currentUserId)
        {
            throw new ForbiddenException("Mozete oznaciti samo vlastite notifikacije kao procitane.");
        }

        if (notification.Status == NotificationStatus.Read)
        {
            return;
        }

        notification.Status = NotificationStatus.Read;
        notification.ReadAtUtc = DateTime.UtcNow;

        await _dbContext.SaveChangesAsync(cancellationToken);
    }

    public async Task MarkAllAsReadAsync(CancellationToken cancellationToken = default)
    {
        var currentUserId = GetRequiredCurrentUserId();
        var nowUtc = DateTime.UtcNow;

        var unreadNotifications = await _dbContext.Notifications
            .Where(x => x.UserId == currentUserId && x.Status == NotificationStatus.Unread)
            .ToListAsync(cancellationToken);

        if (unreadNotifications.Count == 0)
        {
            return;
        }

        foreach (var notification in unreadNotifications)
        {
            notification.Status = NotificationStatus.Read;
            notification.ReadAtUtc = nowUtc;
        }

        await _dbContext.SaveChangesAsync(cancellationToken);
    }

    private static void ValidateAdminSearchRequest(AdminNotificationSearchRequest request)
    {
        if (request.CreatedFromUtc.HasValue && request.CreatedFromUtc.Value.Kind == DateTimeKind.Unspecified)
        {
            throw new ValidationException(
                "Datum pocetka pretrage mora biti u UTC formatu.",
                new Dictionary<string, string[]>
                {
                    ["createdFromUtc"] = ["Koristite UTC datum za CreatedFromUtc vrijednost."]
                });
        }

        if (request.CreatedToUtc.HasValue && request.CreatedToUtc.Value.Kind == DateTimeKind.Unspecified)
        {
            throw new ValidationException(
                "Datum kraja pretrage mora biti u UTC formatu.",
                new Dictionary<string, string[]>
                {
                    ["createdToUtc"] = ["Koristite UTC datum za CreatedToUtc vrijednost."]
                });
        }

        if (request.CreatedFromUtc.HasValue && request.CreatedToUtc.HasValue && request.CreatedFromUtc > request.CreatedToUtc)
        {
            throw new ValidationException(
                "Raspon datuma za pretragu notifikacija nije validan.",
                new Dictionary<string, string[]>
                {
                    ["createdToUtc"] = ["Datum kraja mora biti veci ili jednak datumu pocetka."]
                });
        }
    }

    private static string ResolveFullName(string? firstName, string? lastName, string fallbackUserName)
    {
        var fullName = $"{firstName ?? string.Empty} {lastName ?? string.Empty}".Trim();
        return string.IsNullOrWhiteSpace(fullName) ? fallbackUserName : fullName;
    }

    private string GetRequiredCurrentUserId()
    {
        var httpContext = _httpContextAccessor.HttpContext ?? throw new UnauthorizedException("Prijava je obavezna za ovu akciju.");
        var userId = httpContext.User.FindFirstValue(ClaimTypes.NameIdentifier);

        if (string.IsNullOrWhiteSpace(userId))
        {
            throw new UnauthorizedException("Nije moguce odrediti trenutnog korisnika.");
        }

        return userId;
    }
}
