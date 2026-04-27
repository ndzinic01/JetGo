using JetGo.Application.DTOs.Common;

namespace JetGo.Infrastructure.Services.Common;

internal static class PagedResponseBuilder
{
    public static PagedResponseDto<T> Build<T>(IReadOnlyCollection<T> items, int page, int pageSize, int totalCount)
    {
        var totalPages = totalCount == 0
            ? 0
            : (int)Math.Ceiling(totalCount / (double)pageSize);

        return new PagedResponseDto<T>
        {
            Items = items,
            Page = page,
            PageSize = pageSize,
            TotalCount = totalCount,
            TotalPages = totalPages,
            HasPreviousPage = page > 1,
            HasNextPage = page < totalPages
        };
    }
}
