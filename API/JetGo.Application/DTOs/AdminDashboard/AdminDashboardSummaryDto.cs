using JetGo.Domain.Enums;

namespace JetGo.Application.DTOs.AdminDashboard;

public sealed class AdminDashboardSummaryDto
{
    public DateTime GeneratedAtUtc { get; init; }

    public int TotalUsersCount { get; init; }

    public int ActiveUsersCount { get; init; }

    public int InactiveUsersCount { get; init; }

    public int UpcomingFlightsCount { get; init; }

    public int DelayedFlightsCount { get; init; }

    public int TotalReservationsCount { get; init; }

    public int PendingReservationsCount { get; init; }

    public int OpenSupportMessagesCount { get; init; }

    public int AnsweredSupportMessagesCount { get; init; }

    public int PendingPaymentsCount { get; init; }

    public int PaidPaymentsCount { get; init; }

    public int RefundedPaymentsCount { get; init; }

    public List<AdminDashboardAmountDto> PaidAmountsByCurrency { get; init; } = [];

    public List<AdminDashboardRecentReservationDto> RecentReservations { get; init; } = [];

    public List<AdminDashboardRecentPaymentDto> RecentPayments { get; init; } = [];

    public List<AdminDashboardRecentSupportMessageDto> RecentSupportMessages { get; init; } = [];
}

public sealed class AdminDashboardAmountDto
{
    public string Currency { get; init; } = "BAM";

    public decimal Amount { get; init; }
}

public sealed class AdminDashboardRecentReservationDto
{
    public string ReservationCode { get; init; } = string.Empty;

    public string FlightNumber { get; init; } = string.Empty;

    public string RouteCode { get; init; } = string.Empty;

    public string CustomerName { get; init; } = string.Empty;

    public ReservationStatus Status { get; init; }

    public decimal TotalAmount { get; init; }

    public string Currency { get; init; } = "BAM";

    public DateTime CreatedAtUtc { get; init; }
}

public sealed class AdminDashboardRecentPaymentDto
{
    public int Id { get; init; }

    public string ReservationCode { get; init; } = string.Empty;

    public string FlightNumber { get; init; } = string.Empty;

    public string RouteCode { get; init; } = string.Empty;

    public string CustomerName { get; init; } = string.Empty;

    public PaymentStatus Status { get; init; }

    public decimal Amount { get; init; }

    public string Currency { get; init; } = "BAM";

    public DateTime CreatedAtUtc { get; init; }
}

public sealed class AdminDashboardRecentSupportMessageDto
{
    public int Id { get; init; }

    public string Subject { get; init; } = string.Empty;

    public string CustomerName { get; init; } = string.Empty;

    public string CustomerEmail { get; init; } = string.Empty;

    public bool IsReplied { get; init; }

    public DateTime CreatedAtUtc { get; init; }

    public DateTime? RepliedAtUtc { get; init; }
}
