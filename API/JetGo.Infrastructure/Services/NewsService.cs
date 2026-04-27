using JetGo.Application.Contracts.Services;
using JetGo.Application.DTOs.Common;
using JetGo.Application.DTOs.News;
using JetGo.Application.Exceptions;
using JetGo.Application.Requests.News;
using JetGo.Domain.Entities;
using JetGo.Infrastructure.Persistence;
using JetGo.Infrastructure.Services.Common;
using Microsoft.EntityFrameworkCore;

namespace JetGo.Infrastructure.Services;

public sealed class NewsService : INewsService
{
    private readonly JetGoDbContext _dbContext;

    public NewsService(JetGoDbContext dbContext)
    {
        _dbContext = dbContext;
    }

    public async Task<PagedResponseDto<NewsArticleListItemDto>> GetPublishedPagedAsync(NewsSearchRequest request, CancellationToken cancellationToken = default)
    {
        return await GetPagedInternalAsync(request, includeUnpublished: false, cancellationToken);
    }

    public async Task<PagedResponseDto<NewsArticleListItemDto>> GetAdminPagedAsync(NewsSearchRequest request, CancellationToken cancellationToken = default)
    {
        return await GetPagedInternalAsync(request, includeUnpublished: true, cancellationToken);
    }

    public async Task<NewsArticleDetailsDto> GetByIdAsync(int id, bool includeUnpublished, CancellationToken cancellationToken = default)
    {
        var query = _dbContext.NewsArticles.AsNoTracking().Where(x => x.Id == id);

        if (!includeUnpublished)
        {
            query = query.Where(x => x.IsPublished);
        }

        var article = await query
            .Select(x => new NewsArticleDetailsDto
            {
                Id = x.Id,
                Title = x.Title,
                Content = x.Content,
                ImageUrl = x.ImageUrl,
                IsPublished = x.IsPublished,
                PublishedAtUtc = x.PublishedAtUtc,
                CreatedAtUtc = x.CreatedAtUtc
            })
            .SingleOrDefaultAsync(cancellationToken);

        return article ?? throw new NotFoundException($"Obavijest sa ID vrijednoscu {id} nije pronadjena.");
    }

    public async Task<NewsArticleDetailsDto> CreateAsync(UpsertNewsArticleRequest request, CancellationToken cancellationToken = default)
    {
        ValidateRequest(request);

        var article = new NewsArticle
        {
            Title = request.Title.Trim(),
            Content = request.Content.Trim(),
            ImageUrl = request.ImageUrl.Trim(),
            IsPublished = request.IsPublished,
            PublishedAtUtc = ResolvePublishedAtUtc(request)
        };

        await _dbContext.NewsArticles.AddAsync(article, cancellationToken);
        await _dbContext.SaveChangesAsync(cancellationToken);

        return await GetByIdAsync(article.Id, includeUnpublished: true, cancellationToken);
    }

    public async Task<NewsArticleDetailsDto> UpdateAsync(int id, UpsertNewsArticleRequest request, CancellationToken cancellationToken = default)
    {
        ValidateRequest(request);

        var article = await _dbContext.NewsArticles.SingleOrDefaultAsync(x => x.Id == id, cancellationToken);

        if (article is null)
        {
            throw new NotFoundException($"Obavijest sa ID vrijednoscu {id} nije pronadjena.");
        }

        article.Title = request.Title.Trim();
        article.Content = request.Content.Trim();
        article.ImageUrl = request.ImageUrl.Trim();
        article.IsPublished = request.IsPublished;
        article.PublishedAtUtc = ResolvePublishedAtUtc(request, article.PublishedAtUtc);
        article.UpdatedAtUtc = DateTime.UtcNow;

        await _dbContext.SaveChangesAsync(cancellationToken);

        return await GetByIdAsync(article.Id, includeUnpublished: true, cancellationToken);
    }

    private async Task<PagedResponseDto<NewsArticleListItemDto>> GetPagedInternalAsync(
        NewsSearchRequest request,
        bool includeUnpublished,
        CancellationToken cancellationToken)
    {
        ValidateSearchRequest(request);

        var query = _dbContext.NewsArticles.AsNoTracking().AsQueryable();

        if (!includeUnpublished)
        {
            query = query.Where(x => x.IsPublished);
        }
        else if (request.IsPublished.HasValue)
        {
            query = query.Where(x => x.IsPublished == request.IsPublished.Value);
        }

        if (request.PublishedAfterUtc.HasValue)
        {
            query = query.Where(x => x.PublishedAtUtc >= request.PublishedAfterUtc.Value);
        }

        if (!string.IsNullOrWhiteSpace(request.SearchText))
        {
            var searchText = request.SearchText.Trim();
            query = query.Where(x => x.Title.Contains(searchText) || x.Content.Contains(searchText));
        }

        var totalCount = await query.CountAsync(cancellationToken);

        var items = await query
            .OrderByDescending(x => x.PublishedAtUtc)
            .ThenByDescending(x => x.Id)
            .Skip((request.Page - 1) * request.PageSize)
            .Take(request.PageSize)
            .Select(x => new NewsArticleListItemDto
            {
                Id = x.Id,
                Title = x.Title,
                ImageUrl = x.ImageUrl,
                IsPublished = x.IsPublished,
                PublishedAtUtc = x.PublishedAtUtc
            })
            .ToListAsync(cancellationToken);

        return PagedResponseBuilder.Build(items, request.Page, request.PageSize, totalCount);
    }

    private static void ValidateRequest(UpsertNewsArticleRequest request)
    {
        if (request.PublishedAtUtc.HasValue && request.PublishedAtUtc.Value.Kind == DateTimeKind.Unspecified)
        {
            throw new ValidationException(
                "Datum objave mora biti u UTC formatu.",
                new Dictionary<string, string[]>
                {
                    ["publishedAtUtc"] = ["Koristite UTC datum za PublishedAtUtc vrijednost."]
                });
        }
    }

    private static void ValidateSearchRequest(NewsSearchRequest request)
    {
        if (request.PublishedAfterUtc.HasValue && request.PublishedAfterUtc.Value.Kind == DateTimeKind.Unspecified)
        {
            throw new ValidationException(
                "Datum filtera mora biti u UTC formatu.",
                new Dictionary<string, string[]>
                {
                    ["publishedAfterUtc"] = ["Koristite UTC datum za PublishedAfterUtc vrijednost."]
                });
        }
    }

    private static DateTime ResolvePublishedAtUtc(UpsertNewsArticleRequest request, DateTime? fallbackValue = null)
    {
        if (request.PublishedAtUtc.HasValue)
        {
            return request.PublishedAtUtc.Value;
        }

        if (fallbackValue.HasValue)
        {
            return fallbackValue.Value;
        }

        return DateTime.UtcNow;
    }
}
