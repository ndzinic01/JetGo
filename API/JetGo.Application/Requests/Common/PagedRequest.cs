using System.ComponentModel.DataAnnotations;

namespace JetGo.Application.Requests.Common;

public abstract class PagedRequest
{
    [Range(1, int.MaxValue, ErrorMessage = "Page mora biti veci ili jednak 1.")]
    public int Page { get; init; } = 1;

    [Range(1, 100, ErrorMessage = "PageSize mora biti izmedju 1 i 100.")]
    public int PageSize { get; init; } = 10;
}
