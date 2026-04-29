using JetGo.Application.DTOs.Common;
using JetGo.Application.DTOs.Payments;
using JetGo.Application.Requests.Payments;

namespace JetGo.Application.Contracts.Services;

public interface IPaymentService
{
    Task<PaymentDetailsDto> InitializeAsync(int reservationId, CancellationToken cancellationToken = default);

    Task<PagedResponseDto<PaymentListItemDto>> GetMineAsync(PaymentSearchRequest request, CancellationToken cancellationToken = default);

    Task<PagedResponseDto<PaymentListItemDto>> GetAdminPagedAsync(PaymentSearchRequest request, CancellationToken cancellationToken = default);

    Task<PaymentDetailsDto> GetByIdAsync(int id, CancellationToken cancellationToken = default);

    Task<PaymentDetailsDto> ConfirmAsync(int id, ConfirmPaymentRequest request, CancellationToken cancellationToken = default);

    Task<PaymentDetailsDto> RefundAsync(int id, RefundPaymentRequest request, CancellationToken cancellationToken = default);
}
