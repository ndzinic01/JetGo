using JetGo.Application.DTOs.Common;
using JetGo.Application.DTOs.Reservations;
using JetGo.Application.Requests.Reservations;

namespace JetGo.Application.Contracts.Services;

public interface IReservationService
{
    Task<ReservationDetailsDto> CreateAsync(CreateReservationRequest request, CancellationToken cancellationToken = default);

    Task<PagedResponseDto<ReservationListItemDto>> GetMineAsync(ReservationSearchRequest request, CancellationToken cancellationToken = default);

    Task<PagedResponseDto<ReservationListItemDto>> GetAdminPagedAsync(ReservationSearchRequest request, CancellationToken cancellationToken = default);

    Task<ReservationDetailsDto> GetByIdAsync(int id, CancellationToken cancellationToken = default);

    Task<ReservationDetailsDto> ConfirmAsync(int id, UpdateReservationStatusRequest request, CancellationToken cancellationToken = default);

    Task<ReservationDetailsDto> CancelAsync(int id, UpdateReservationStatusRequest request, CancellationToken cancellationToken = default);

    Task<ReservationDetailsDto> CompleteAsync(int id, UpdateReservationStatusRequest request, CancellationToken cancellationToken = default);
}
