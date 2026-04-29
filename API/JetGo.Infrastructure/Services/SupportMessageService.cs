using System.Security.Claims;
using JetGo.Application.Constants;
using JetGo.Application.Contracts.Messaging;
using JetGo.Application.Contracts.Services;
using JetGo.Application.DTOs.Common;
using JetGo.Application.DTOs.SupportMessages;
using JetGo.Application.Exceptions;
using JetGo.Application.Messaging.Notifications;
using JetGo.Application.Requests.SupportMessages;
using JetGo.Domain.Entities;
using JetGo.Infrastructure.Persistence;
using JetGo.Infrastructure.Services.Common;
using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace JetGo.Infrastructure.Services;

public sealed class SupportMessageService : ISupportMessageService
{
    private readonly JetGoDbContext _dbContext;
    private readonly IHttpContextAccessor _httpContextAccessor;
    private readonly INotificationEventPublisher _notificationEventPublisher;
    private readonly ILogger<SupportMessageService> _logger;

    public SupportMessageService(
        JetGoDbContext dbContext,
        IHttpContextAccessor httpContextAccessor,
        INotificationEventPublisher notificationEventPublisher,
        ILogger<SupportMessageService> logger)
    {
        _dbContext = dbContext;
        _httpContextAccessor = httpContextAccessor;
        _notificationEventPublisher = notificationEventPublisher;
        _logger = logger;
    }

    public async Task<SupportMessageDetailsDto> CreateAsync(CreateSupportMessageRequest request, CancellationToken cancellationToken = default)
    {
        var currentUserId = GetRequiredCurrentUserId();
        var subject = NormalizeRequiredText(
            request.Subject,
            "subject",
            "Naslov upita je obavezan.");
        var message = NormalizeRequiredText(
            request.Message,
            "message",
            "Sadrzaj upita je obavezan.");

        var supportMessage = new SupportMessage
        {
            UserId = currentUserId,
            Subject = subject,
            Message = message
        };

        await _dbContext.SupportMessages.AddAsync(supportMessage, cancellationToken);
        await _dbContext.SaveChangesAsync(cancellationToken);

        _logger.LogInformation("Support message {SupportMessageId} created by user {UserId}.", supportMessage.Id, currentUserId);

        return await GetByIdAsync(supportMessage.Id, cancellationToken);
    }

    public async Task<PagedResponseDto<SupportMessageListItemDto>> GetMineAsync(SupportMessageSearchRequest request, CancellationToken cancellationToken = default)
    {
        var currentUserId = GetRequiredCurrentUserId();
        return await GetPagedInternalAsync(request, currentUserId, isAdminView: false, cancellationToken);
    }

    public async Task<PagedResponseDto<SupportMessageListItemDto>> GetAdminPagedAsync(SupportMessageSearchRequest request, CancellationToken cancellationToken = default)
    {
        return await GetPagedInternalAsync(request, userIdFilter: null, isAdminView: true, cancellationToken);
    }

    public async Task<SupportMessageDetailsDto> GetByIdAsync(int id, CancellationToken cancellationToken = default)
    {
        var currentUserId = GetRequiredCurrentUserId();
        var isAdmin = IsCurrentUserAdmin();

        var ownerInfo = await _dbContext.SupportMessages
            .AsNoTracking()
            .Where(x => x.Id == id)
            .Select(x => new
            {
                x.UserId
            })
            .SingleOrDefaultAsync(cancellationToken);

        if (ownerInfo is null)
        {
            throw new NotFoundException($"Korisnicki upit sa ID vrijednoscu {id} nije pronadjen.");
        }

        if (!isAdmin && ownerInfo.UserId != currentUserId)
        {
            throw new ForbiddenException("Mozete pregledati samo vlastite korisnicke upite.");
        }

        return await BuildDetailsAsync(id, cancellationToken);
    }

    public async Task<SupportMessageDetailsDto> ReplyAsync(int id, ReplyToSupportMessageRequest request, CancellationToken cancellationToken = default)
    {
        var actorUserId = GetRequiredCurrentUserId();
        var adminReply = NormalizeRequiredText(
            request.AdminReply,
            "adminReply",
            "Odgovor administratora je obavezan.");

        var supportMessage = await _dbContext.SupportMessages
            .SingleOrDefaultAsync(x => x.Id == id, cancellationToken);

        if (supportMessage is null)
        {
            throw new NotFoundException($"Korisnicki upit sa ID vrijednoscu {id} nije pronadjen.");
        }

        var nowUtc = DateTime.UtcNow;
        supportMessage.AdminReply = adminReply;
        supportMessage.RepliedAtUtc = nowUtc;
        supportMessage.UpdatedAtUtc = nowUtc;

        await _dbContext.SaveChangesAsync(cancellationToken);
        await PublishNotificationSafelyAsync(
            supportMessage.UserId,
            "Odgovor na korisnicki upit",
            $"Administrator je odgovorio na upit '{supportMessage.Subject}'.",
            nowUtc,
            cancellationToken);

        _logger.LogInformation("Support message {SupportMessageId} replied by admin {UserId}.", supportMessage.Id, actorUserId);

        return await BuildDetailsAsync(supportMessage.Id, cancellationToken);
    }

    private async Task<PagedResponseDto<SupportMessageListItemDto>> GetPagedInternalAsync(
        SupportMessageSearchRequest request,
        string? userIdFilter,
        bool isAdminView,
        CancellationToken cancellationToken)
    {
        ValidateSearchRequest(request);

        var query =
            from message in _dbContext.SupportMessages.AsNoTracking()
            join user in _dbContext.Users.AsNoTracking() on message.UserId equals user.Id
            join profile in _dbContext.UserProfiles.AsNoTracking() on message.UserId equals profile.UserId into profiles
            from profile in profiles.DefaultIfEmpty()
            select new
            {
                message.Id,
                message.UserId,
                message.Subject,
                message.Message,
                message.CreatedAtUtc,
                message.RepliedAtUtc,
                UserName = user.UserName ?? string.Empty,
                ProfileFirstName = profile != null ? profile.FirstName : null,
                ProfileLastName = profile != null ? profile.LastName : null,
                ProfileEmail = profile != null ? profile.Email : null,
                UserEmail = user.Email ?? string.Empty
            };

        if (!string.IsNullOrWhiteSpace(userIdFilter))
        {
            query = query.Where(x => x.UserId == userIdFilter);
        }

        if (request.IsReplied.HasValue)
        {
            if (request.IsReplied.Value)
            {
                query = query.Where(x => x.RepliedAtUtc.HasValue);
            }
            else
            {
                query = query.Where(x => !x.RepliedAtUtc.HasValue);
            }
        }

        if (request.CreatedFromUtc.HasValue)
        {
            query = query.Where(x => x.CreatedAtUtc >= request.CreatedFromUtc.Value);
        }

        if (request.CreatedToUtc.HasValue)
        {
            query = query.Where(x => x.CreatedAtUtc <= request.CreatedToUtc.Value);
        }

        if (!string.IsNullOrWhiteSpace(request.SearchText))
        {
            var searchText = request.SearchText.Trim();

            query = query.Where(x =>
                x.Subject.Contains(searchText) ||
                x.Message.Contains(searchText) ||
                (isAdminView && (
                    x.UserName.Contains(searchText) ||
                    ((x.ProfileFirstName ?? string.Empty) + " " + (x.ProfileLastName ?? string.Empty)).Trim().Contains(searchText) ||
                    (x.ProfileEmail ?? x.UserEmail).Contains(searchText))));
        }

        var totalCount = await query.CountAsync(cancellationToken);

        var rawItems = await query
            .OrderByDescending(x => x.CreatedAtUtc)
            .ThenByDescending(x => x.Id)
            .Skip((request.Page - 1) * request.PageSize)
            .Take(request.PageSize)
            .ToListAsync(cancellationToken);

        var items = rawItems
            .Select(x => new SupportMessageListItemDto
            {
                Id = x.Id,
                Subject = x.Subject,
                MessagePreview = BuildMessagePreview(x.Message),
                IsReplied = x.RepliedAtUtc.HasValue,
                CreatedAtUtc = x.CreatedAtUtc,
                RepliedAtUtc = x.RepliedAtUtc,
                CustomerName = ResolveFullName(x.ProfileFirstName, x.ProfileLastName, x.UserName),
                CustomerEmail = x.ProfileEmail ?? x.UserEmail
            })
            .ToList();

        return PagedResponseBuilder.Build(items, request.Page, request.PageSize, totalCount);
    }

    private async Task<SupportMessageDetailsDto> BuildDetailsAsync(int id, CancellationToken cancellationToken)
    {
        var rawDetails = await (
            from message in _dbContext.SupportMessages.AsNoTracking()
            join user in _dbContext.Users.AsNoTracking() on message.UserId equals user.Id
            join profile in _dbContext.UserProfiles.AsNoTracking() on message.UserId equals profile.UserId into profiles
            from profile in profiles.DefaultIfEmpty()
            where message.Id == id
            select new
            {
                message.Id,
                message.Subject,
                message.Message,
                message.AdminReply,
                IsReplied = message.RepliedAtUtc.HasValue,
                message.CreatedAtUtc,
                message.UpdatedAtUtc,
                message.RepliedAtUtc,
                message.UserId,
                UserName = user.UserName ?? string.Empty,
                FirstName = profile != null ? profile.FirstName : null,
                LastName = profile != null ? profile.LastName : null,
                Email = profile != null && profile.Email != null
                    ? profile.Email
                    : (user.Email ?? string.Empty)
            })
            .SingleOrDefaultAsync(cancellationToken);

        if (rawDetails is null)
        {
            throw new NotFoundException($"Korisnicki upit sa ID vrijednoscu {id} nije pronadjen.");
        }

        return new SupportMessageDetailsDto
        {
            Id = rawDetails.Id,
            Subject = rawDetails.Subject,
            Message = rawDetails.Message,
            AdminReply = rawDetails.AdminReply,
            IsReplied = rawDetails.IsReplied,
            CreatedAtUtc = rawDetails.CreatedAtUtc,
            UpdatedAtUtc = rawDetails.UpdatedAtUtc,
            RepliedAtUtc = rawDetails.RepliedAtUtc,
            Customer = new SupportMessageCustomerDto
            {
                UserId = rawDetails.UserId,
                Username = rawDetails.UserName,
                FullName = ResolveFullName(rawDetails.FirstName, rawDetails.LastName, rawDetails.UserName),
                Email = rawDetails.Email
            }
        };
    }

    private static void ValidateSearchRequest(SupportMessageSearchRequest request)
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
                "Pocetni datum ne moze biti veci od krajnjeg datuma.",
                new Dictionary<string, string[]>
                {
                    ["createdFromUtc"] = ["CreatedFromUtc mora biti manji ili jednak vrijednosti CreatedToUtc."]
                });
        }
    }

    private static string NormalizeRequiredText(string? value, string key, string errorMessage)
    {
        var normalizedValue = value?.Trim();

        if (string.IsNullOrWhiteSpace(normalizedValue))
        {
            throw new ValidationException(
                errorMessage,
                new Dictionary<string, string[]>
                {
                    [key] = [errorMessage]
                });
        }

        return normalizedValue;
    }

    private static string BuildMessagePreview(string message)
    {
        if (message.Length <= 120)
        {
            return message;
        }

        return $"{message[..117]}...";
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

    private bool IsCurrentUserAdmin()
    {
        var httpContext = _httpContextAccessor.HttpContext ?? throw new UnauthorizedException("Prijava je obavezna za ovu akciju.");
        return httpContext.User.IsInRole(RoleNames.Admin);
    }

    private async Task PublishNotificationSafelyAsync(
        string userId,
        string title,
        string body,
        DateTime occurredAtUtc,
        CancellationToken cancellationToken)
    {
        var message = new NotificationRequestedMessage
        {
            UserId = userId,
            Title = title,
            Body = body,
            OccurredAtUtc = occurredAtUtc
        };

        try
        {
            await _notificationEventPublisher.PublishAsync(message, cancellationToken);
        }
        catch (Exception exception)
        {
            _logger.LogError(
                exception,
                "Failed to publish notification event {Title} for user {UserId}.",
                title,
                userId);
        }
    }
}
