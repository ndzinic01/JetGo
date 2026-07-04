using JetGo.Application.Contracts.Services;
using JetGo.Application.DTOs.AdminDashboard;
using JetGo.Domain.Enums;
using JetGo.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace JetGo.Infrastructure.Services;

public sealed class AdminDashboardService : IAdminDashboardService
{
    private readonly JetGoDbContext _dbContext;

    public AdminDashboardService(JetGoDbContext dbContext)
    {
        _dbContext = dbContext;
    }

    public async Task<AdminDashboardSummaryDto> GetSummaryAsync(CancellationToken cancellationToken = default)
    {
        var nowUtc = DateTime.UtcNow;
        var nowOffset = DateTimeOffset.UtcNow;

        var totalUsersCount = await _dbContext.Users
            .AsNoTracking()
            .CountAsync(cancellationToken);

        var activeUsersCount = await _dbContext.Users
            .AsNoTracking()
            .CountAsync(
                x => !x.LockoutEnd.HasValue || x.LockoutEnd <= nowOffset,
                cancellationToken);

        var upcomingFlightsCount = await _dbContext.Flights
            .AsNoTracking()
            .CountAsync(
                x => x.DepartureAtUtc >= nowUtc &&
                     (x.Status == FlightStatus.Scheduled || x.Status == FlightStatus.Delayed),
                cancellationToken);

        var delayedFlightsCount = await _dbContext.Flights
            .AsNoTracking()
            .CountAsync(x => x.Status == FlightStatus.Delayed, cancellationToken);

        var totalReservationsCount = await _dbContext.Reservations
            .AsNoTracking()
            .CountAsync(cancellationToken);

        var pendingReservationsCount = await _dbContext.Reservations
            .AsNoTracking()
            .CountAsync(x => x.Status == ReservationStatus.Pending, cancellationToken);

        var openSupportMessagesCount = await _dbContext.SupportMessages
            .AsNoTracking()
            .CountAsync(
                x => x.AdminReply == null || x.AdminReply == string.Empty,
                cancellationToken);

        var totalSupportMessagesCount = await _dbContext.SupportMessages
            .AsNoTracking()
            .CountAsync(cancellationToken);

        var pendingPaymentsCount = await _dbContext.Payments
            .AsNoTracking()
            .CountAsync(x => x.Status == PaymentStatus.Pending, cancellationToken);

        var paidPaymentsCount = await _dbContext.Payments
            .AsNoTracking()
            .CountAsync(x => x.Status == PaymentStatus.Paid, cancellationToken);

        var refundedPaymentsCount = await _dbContext.Payments
            .AsNoTracking()
            .CountAsync(x => x.Status == PaymentStatus.Refunded, cancellationToken);

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
