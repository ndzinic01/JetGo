using JetGo.Application.Contracts.Services;
using JetGo.Application.DTOs.AdminDashboard;
using JetGo.Domain.Enums;
using JetGo.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace JetGo.Infrastructure.Services;

public sealed class AdminDashboardService : IAdminDashboardService
{
    private readonly JetGoDbContext _dbContext;
    private readonly ReservationStatusSyncService _reservationStatusSyncService;

    public AdminDashboardService(
        JetGoDbContext dbContext,
        ReservationStatusSyncService reservationStatusSyncService)
    {
        _dbContext = dbContext;
        _reservationStatusSyncService = reservationStatusSyncService;
    }

    public async Task<AdminDashboardSummaryDto> GetSummaryAsync(CancellationToken cancellationToken = default)
    {
        var nowUtc = DateTime.UtcNow;
        var nowOffset = DateTimeOffset.UtcNow;
        await _reservationStatusSyncService.SyncCompletedReservationsAsync(nowUtc, cancellationToken);

        var userStats = await _dbContext.Users
            .AsNoTracking()
            .GroupBy(_ => 1)
            .Select(x => new
            {
                TotalCount = x.Count(),
                ActiveCount = x.Count(y => !y.LockoutEnd.HasValue || y.LockoutEnd <= nowOffset)
            })
            .SingleOrDefaultAsync(cancellationToken);

        var flightStats = await _dbContext.Flights
            .AsNoTracking()
            .GroupBy(_ => 1)
            .Select(x => new
            {
                UpcomingCount = x.Count(y =>
                    y.DepartureAtUtc >= nowUtc &&
                    (y.Status == FlightStatus.Scheduled || y.Status == FlightStatus.Delayed)),
                DelayedCount = x.Count(y => y.Status == FlightStatus.Delayed)
            })
            .SingleOrDefaultAsync(cancellationToken);

        var reservationStats = await _dbContext.Reservations
            .AsNoTracking()
            .GroupBy(_ => 1)
            .Select(x => new
            {
                TotalCount = x.Count(),
                PendingCount = x.Count(y => y.Status == ReservationStatus.Pending)
            })
            .SingleOrDefaultAsync(cancellationToken);

        var supportMessageStats = await _dbContext.SupportMessages
            .AsNoTracking()
            .GroupBy(_ => 1)
            .Select(x => new
            {
                TotalCount = x.Count(),
                OpenCount = x.Count(y => y.AdminReply == null || y.AdminReply == string.Empty)
            })
            .SingleOrDefaultAsync(cancellationToken);

        var paymentStats = await _dbContext.Payments
            .AsNoTracking()
            .GroupBy(_ => 1)
            .Select(x => new
            {
                PendingCount = x.Count(y => y.Status == PaymentStatus.Pending),
                PaidCount = x.Count(y => y.Status == PaymentStatus.Paid),
                RefundedCount = x.Count(y => y.Status == PaymentStatus.Refunded)
            })
            .SingleOrDefaultAsync(cancellationToken);

        var totalUsersCount = userStats?.TotalCount ?? 0;
        var activeUsersCount = userStats?.ActiveCount ?? 0;
        var upcomingFlightsCount = flightStats?.UpcomingCount ?? 0;
        var delayedFlightsCount = flightStats?.DelayedCount ?? 0;
        var totalReservationsCount = reservationStats?.TotalCount ?? 0;
        var pendingReservationsCount = reservationStats?.PendingCount ?? 0;
        var totalSupportMessagesCount = supportMessageStats?.TotalCount ?? 0;
        var openSupportMessagesCount = supportMessageStats?.OpenCount ?? 0;
        var pendingPaymentsCount = paymentStats?.PendingCount ?? 0;
        var paidPaymentsCount = paymentStats?.PaidCount ?? 0;
        var refundedPaymentsCount = paymentStats?.RefundedCount ?? 0;

        var paidAmountsByCurrency = await _dbContext.Payments
            .AsNoTracking()
            .Where(x => x.Status == PaymentStatus.Paid)
            .GroupBy(x => x.Currency)
            .Select(x => new AdminDashboardAmountDto
            {
                Currency = x.Key,
                Amount = x.Sum(y => y.Amount)
            })
            .OrderBy(x => x.Currency)
            .ToListAsync(cancellationToken);

        var recentReservations = await _dbContext.Reservations
            .AsNoTracking()
            .OrderByDescending(x => x.CreatedAtUtc)
            .Take(5)
            .Select(x => new AdminDashboardRecentReservationDto
            {
                ReservationCode = x.ReservationCode,
                FlightNumber = x.Flight.FlightNumber,
                RouteCode = x.Flight.Destination.RouteCode,
                CustomerName = _dbContext.UserProfiles
                    .Where(p => p.UserId == x.UserId)
                    .Select(p => p.FirstName + " " + p.LastName)
                    .FirstOrDefault() ?? string.Empty,
                Status = x.Status,
                TotalAmount = x.TotalAmount,
                Currency = x.Currency,
                CreatedAtUtc = x.CreatedAtUtc
            })
            .ToListAsync(cancellationToken);

        var recentPayments = await _dbContext.Payments
            .AsNoTracking()
            .OrderByDescending(x => x.CreatedAtUtc)
            .Take(5)
            .Select(x => new AdminDashboardRecentPaymentDto
            {
                Id = x.Id,
                ReservationCode = x.Reservation.ReservationCode,
                FlightNumber = x.Reservation.Flight.FlightNumber,
                RouteCode = x.Reservation.Flight.Destination.RouteCode,
                CustomerName = _dbContext.UserProfiles
                    .Where(p => p.UserId == x.Reservation.UserId)
                    .Select(p => p.FirstName + " " + p.LastName)
                    .FirstOrDefault() ?? string.Empty,
                Status = x.Status,
                Amount = x.Amount,
                Currency = x.Currency,
                CreatedAtUtc = x.CreatedAtUtc
            })
            .ToListAsync(cancellationToken);

        var recentSupportMessages = await _dbContext.SupportMessages
            .AsNoTracking()
            .OrderByDescending(x => x.CreatedAtUtc)
            .Take(5)
            .Select(x => new AdminDashboardRecentSupportMessageDto
            {
                Id = x.Id,
                Subject = x.Subject,
                CustomerName = _dbContext.UserProfiles
                    .Where(p => p.UserId == x.UserId)
                    .Select(p => p.FirstName + " " + p.LastName)
                    .FirstOrDefault() ?? string.Empty,
                CustomerEmail = _dbContext.UserProfiles
                    .Where(p => p.UserId == x.UserId)
                    .Select(p => p.Email)
                    .FirstOrDefault() ?? string.Empty,
                IsReplied = x.AdminReply != null && x.AdminReply != string.Empty,
                CreatedAtUtc = x.CreatedAtUtc,
                RepliedAtUtc = x.RepliedAtUtc
            })
            .ToListAsync(cancellationToken);

        return new AdminDashboardSummaryDto
        {
            GeneratedAtUtc = nowUtc,
            TotalUsersCount = totalUsersCount,
            ActiveUsersCount = activeUsersCount,
            InactiveUsersCount = totalUsersCount - activeUsersCount,
            UpcomingFlightsCount = upcomingFlightsCount,
            DelayedFlightsCount = delayedFlightsCount,
            TotalReservationsCount = totalReservationsCount,
            PendingReservationsCount = pendingReservationsCount,
            OpenSupportMessagesCount = openSupportMessagesCount,
            AnsweredSupportMessagesCount = totalSupportMessagesCount - openSupportMessagesCount,
            PendingPaymentsCount = pendingPaymentsCount,
            PaidPaymentsCount = paidPaymentsCount,
            RefundedPaymentsCount = refundedPaymentsCount,
            PaidAmountsByCurrency = paidAmountsByCurrency,
            RecentReservations = recentReservations,
            RecentPayments = recentPayments,
            RecentSupportMessages = recentSupportMessages
        };
    }
}
