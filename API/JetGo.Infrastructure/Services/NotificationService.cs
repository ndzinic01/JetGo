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
            query = query.Where(x => x.Title.Contains(searchText) || x.Body.Contains(searchText));
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

    public async Task<NotificationSummaryDto> GetSummaryAsync(CancellationToken cancellationToken = default)
    {
        var currentUserId = GetRequiredCurrentUserId();

        return new NotificationSummaryDto
        {
            TotalCount = await _dbContext.Notifications.CountAsync(x => x.UserId == currentUserId, cancellationToken),
            UnreadCount = await _dbContext.Notifications.CountAsync(x => x.UserId == currentUserId && x.Status == NotificationStatus.Unread, cancellationToken),
            LatestCreatedAtUtc = await _dbContext.Notifications
                .Where(x => x.UserId == currentUserId)
                .OrderByDescending(x => x.CreatedAtUtc)
                .Select(x => (DateTime?)x.CreatedAtUtc)
                .FirstOrDefaultAsync(cancellationToken)
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
