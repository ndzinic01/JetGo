using JetGo.Application.DTOs.Common;
using JetGo.Application.DTOs.News;
using JetGo.Application.Requests.News;

namespace JetGo.Application.Contracts.Services;

public interface INewsService
{
    Task<PagedResponseDto<NewsArticleListItemDto>> GetPublishedPagedAsync(NewsSearchRequest request, CancellationToken cancellationToken = default);

    Task<PagedResponseDto<NewsArticleListItemDto>> GetAdminPagedAsync(NewsSearchRequest request, CancellationToken cancellationToken = default);

    Task<NewsArticleDetailsDto> GetByIdAsync(int id, bool includeUnpublished, CancellationToken cancellationToken = default);

    Task<NewsArticleDetailsDto> CreateAsync(UpsertNewsArticleRequest request, CancellationToken cancellationToken = default);

    Task<NewsArticleDetailsDto> UpdateAsync(int id, UpsertNewsArticleRequest request, CancellationToken cancellationToken = default);
}
