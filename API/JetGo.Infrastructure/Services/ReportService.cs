using System.Globalization;
using JetGo.Application.Contracts.Services;
using JetGo.Application.DTOs.Reports;
using JetGo.Application.Exceptions;
using JetGo.Application.Requests.Reports;
using JetGo.Domain.Enums;
using JetGo.Infrastructure.Persistence;
using JetGo.Infrastructure.Reports;
using Microsoft.EntityFrameworkCore;

namespace JetGo.Infrastructure.Services;

public sealed class ReportService : IReportService
{
    private readonly JetGoDbContext _dbContext;

    public ReportService(JetGoDbContext dbContext)
    {
        _dbContext = dbContext;
    }

    public async Task<ReportFileDto> GenerateReservationsReportAsync(
        ReservationReportRequest request,
        CancellationToken cancellationToken = default)
    {
        ValidateReservationRequest(request);

        var reservations = await _dbContext.Reservations
            .AsNoTracking()
            .Where(x =>
                (!request.Status.HasValue || x.Status == request.Status.Value) &&
                (!request.CreatedFromUtc.HasValue || x.CreatedAtUtc >= request.CreatedFromUtc.Value) &&
                (!request.CreatedToUtc.HasValue || x.CreatedAtUtc <= request.CreatedToUtc.Value))
            .OrderByDescending(x => x.CreatedAtUtc)
            .Select(x => new
            {
                x.ReservationCode,
                x.Status,
                x.TotalAmount,
                x.Currency,
                x.CreatedAtUtc,
                x.Flight.FlightNumber,
                x.Flight.Destination.RouteCode,
                CustomerName = _dbContext.UserProfiles
                    .Where(p => p.UserId == x.UserId)
                    .Select(p => p.FirstName + " " + p.LastName)
                    .FirstOrDefault() ?? string.Empty
            })
            .ToListAsync(cancellationToken);

        var lines = new List<string>
        {
            $"Generated at (UTC): {DateTime.UtcNow:yyyy-MM-dd HH:mm}",
            $"Filter status: {(request.Status?.ToString() ?? "All")}",
            $"Filter from: {FormatDate(request.CreatedFromUtc)}",
            $"Filter to: {FormatDate(request.CreatedToUtc)}",
            $"Total reservations: {reservations.Count}",
            $"Total value: {reservations.Sum(x => x.TotalAmount).ToString("0.00", CultureInfo.InvariantCulture)} BAM",
            string.Empty,
            "Code | Flight | Route | Customer | Status | Amount | Created"
        };

        lines.AddRange(reservations.Select(x =>
            $"{x.ReservationCode} | {x.FlightNumber} | {x.RouteCode} | {SafeText(x.CustomerName, 24)} | {x.Status} | {x.TotalAmount.ToString("0.00", CultureInfo.InvariantCulture)} {x.Currency} | {x.CreatedAtUtc:yyyy-MM-dd HH:mm}"));

        if (reservations.Count == 0)
        {
            lines.Add("No reservations found for selected criteria.");
        }

        return new ReportFileDto
        {
            FileName = $"jetgo-reservations-report-{DateTime.UtcNow:yyyyMMddHHmmss}.pdf",
            Content = SimplePdfReportBuilder.Build("JetGo Reservations Report", lines)
        };
    }

    public async Task<ReportFileDto> GeneratePaymentsReportAsync(
        PaymentReportRequest request,
        CancellationToken cancellationToken = default)
    {
        ValidatePaymentRequest(request);

        var payments = await _dbContext.Payments
            .AsNoTracking()
            .Where(x =>
                (!request.Status.HasValue || x.Status == request.Status.Value) &&
                (!request.CreatedFromUtc.HasValue || x.CreatedAtUtc >= request.CreatedFromUtc.Value) &&
                (!request.CreatedToUtc.HasValue || x.CreatedAtUtc <= request.CreatedToUtc.Value))
            .OrderByDescending(x => x.CreatedAtUtc)
            .Select(x => new
            {
                x.Id,
                x.Provider,
                x.ProviderReference,
                x.Amount,
                x.Currency,
                x.Status,
                x.CreatedAtUtc,
                x.PaidAtUtc,
                x.RefundedAtUtc,
                x.Reservation.ReservationCode,
                x.Reservation.Flight.FlightNumber,
                x.Reservation.Flight.Destination.RouteCode,
                CustomerName = _dbContext.UserProfiles
                    .Where(p => p.UserId == x.Reservation.UserId)
                    .Select(p => p.FirstName + " " + p.LastName)
                    .FirstOrDefault() ?? string.Empty
            })
            .ToListAsync(cancellationToken);

        var paidCount = payments.Count(x => x.Status == PaymentStatus.Paid);
        var refundedCount = payments.Count(x => x.Status == PaymentStatus.Refunded);

        var lines = new List<string>
        {
            $"Generated at (UTC): {DateTime.UtcNow:yyyy-MM-dd HH:mm}",
            $"Filter status: {(request.Status?.ToString() ?? "All")}",
            $"Filter from: {FormatDate(request.CreatedFromUtc)}",
            $"Filter to: {FormatDate(request.CreatedToUtc)}",
            $"Total payments: {payments.Count}",
            $"Paid payments: {paidCount}",
            $"Refunded payments: {refundedCount}",
            $"Total amount: {payments.Sum(x => x.Amount).ToString("0.00", CultureInfo.InvariantCulture)} BAM",
            string.Empty,
            "Id | Reservation | Flight | Route | Customer | Status | Amount | Provider"
        };

        lines.AddRange(payments.Select(x =>
            $"{x.Id} | {x.ReservationCode} | {x.FlightNumber} | {x.RouteCode} | {SafeText(x.CustomerName, 24)} | {x.Status} | {x.Amount.ToString("0.00", CultureInfo.InvariantCulture)} {x.Currency} | {SafeText(x.ProviderReference ?? x.Provider, 20)}"));

        if (payments.Count == 0)
        {
            lines.Add("No payments found for selected criteria.");
        }

        return new ReportFileDto
        {
            FileName = $"jetgo-payments-report-{DateTime.UtcNow:yyyyMMddHHmmss}.pdf",
            Content = SimplePdfReportBuilder.Build("JetGo Payments Report", lines)
        };
    }

    private static void ValidateReservationRequest(ReservationReportRequest request)
    {
        if (request.CreatedFromUtc.HasValue && request.CreatedToUtc.HasValue && request.CreatedFromUtc > request.CreatedToUtc)
        {
            throw new ValidationException(
                "Raspon datuma kreiranja rezervacija nije validan.",
                new Dictionary<string, string[]>
                {
                    ["createdToUtc"] = ["Datum 'CreatedToUtc' mora biti veci ili jednak datumu 'CreatedFromUtc'."]
                });
        }
    }

    private static void ValidatePaymentRequest(PaymentReportRequest request)
    {
        if (request.CreatedFromUtc.HasValue && request.CreatedToUtc.HasValue && request.CreatedFromUtc > request.CreatedToUtc)
        {
            throw new ValidationException(
                "Raspon datuma kreiranja placanja nije validan.",
                new Dictionary<string, string[]>
                {
                    ["createdToUtc"] = ["Datum 'CreatedToUtc' mora biti veci ili jednak datumu 'CreatedFromUtc'."]
                });
        }
    }

    private static string FormatDate(DateTime? value)
    {
        return value.HasValue
            ? value.Value.ToString("yyyy-MM-dd HH:mm", CultureInfo.InvariantCulture)
            : "N/A";
    }

    private static string SafeText(string value, int maxLength)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return "-";
        }

        var trimmed = value.Trim();
        return trimmed.Length <= maxLength
            ? trimmed
            : trimmed[..maxLength];
    }
}
