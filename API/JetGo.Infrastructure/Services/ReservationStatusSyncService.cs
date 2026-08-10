using JetGo.Domain.Enums;
using JetGo.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace JetGo.Infrastructure.Services;

public sealed class ReservationStatusSyncService
{
    private const string SystemActorUserId = "system:auto-complete";

    private readonly JetGoDbContext _dbContext;
    private readonly ReservationStateMachine _stateMachine;
    private readonly ILogger<ReservationStatusSyncService> _logger;

    public ReservationStatusSyncService(
        JetGoDbContext dbContext,
        ReservationStateMachine stateMachine,
        ILogger<ReservationStatusSyncService> logger)
    {
        _dbContext = dbContext;
        _stateMachine = stateMachine;
        _logger = logger;
    }

    public async Task SyncCompletedReservationsAsync(DateTime nowUtc, CancellationToken cancellationToken = default)
    {
        var reservations = await _dbContext.Reservations
            .Include(x => x.Flight)
            .Where(x =>
                (x.Status == ReservationStatus.Pending || x.Status == ReservationStatus.Confirmed) &&
                x.Flight.ArrivalAtUtc <= nowUtc)
            .ToListAsync(cancellationToken);

        var completedCount = 0;

        foreach (var reservation in reservations)
        {
            if (_stateMachine.TryAutoCompleteAfterArrival(reservation, SystemActorUserId, nowUtc))
            {
                completedCount++;
            }
        }

        if (completedCount == 0)
        {
            return;
        }

        await _dbContext.SaveChangesAsync(cancellationToken);
        _logger.LogInformation("{ReservationCount} reservations automatically marked as completed.", completedCount);
    }

    public ReservationStatus GetEffectiveStatus(ReservationStatus status, DateTime arrivalAtUtc, DateTime nowUtc)
    {
        return _stateMachine.GetEffectiveStatus(status, arrivalAtUtc, nowUtc);
    }
}
