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
    private static readonly PaymentTransactionType[] ChargeTransactionTypes =
    [
        PaymentTransactionType.InitialPayment,
        PaymentTransactionType.AdditionalCharge
    ];

    private static readonly PaymentTransactionType[] RefundTransactionTypes =
    [
        PaymentTransactionType.PartialRefund,
        PaymentTransactionType.FullRefund
    ];

    private static readonly PaymentTransactionType[] MoneyMovementTransactionTypes =
    [
        PaymentTransactionType.InitialPayment,
        PaymentTransactionType.AdditionalCharge,
        PaymentTransactionType.PartialRefund,
        PaymentTransactionType.FullRefund
    ];

    private readonly JetGoDbContext _dbContext;
    private readonly ReservationStatusSyncService _reservationStatusSyncService;

    public ReportService(
        JetGoDbContext dbContext,
        ReservationStatusSyncService reservationStatusSyncService)
    {
        _dbContext = dbContext;
        _reservationStatusSyncService = reservationStatusSyncService;
    }

    public async Task<ReportFileDto> GenerateSalesReportAsync(
        ReportPeriodRequest request,
        CancellationToken cancellationToken = default)
    {
        ValidatePeriodRequest(request, "Raspon datuma za izvjestaj o prodaji nije validan.");
        await SyncReservationStatusesAsync(cancellationToken);

        var chargeTransactions = await ApplyTransactionPeriod(
                _dbContext.PaymentTransactions.AsNoTracking()
                    .Where(x =>
                        x.Status == PaymentTransactionStatus.Completed &&
                        ChargeTransactionTypes.Contains(x.Type)),
                request)
            .Select(x => new SalesChargeTransaction(
                x.PaymentId,
                x.Amount,
                x.Currency,
                x.CompletedAtUtc ?? x.CreatedAtUtc))
            .ToListAsync(cancellationToken);

        var paymentIds = chargeTransactions
            .Select(x => x.PaymentId)
            .Distinct()
            .ToArray();

        var reservationRows = paymentIds.Length == 0
            ? []
            : await _dbContext.Reservations
                .AsNoTracking()
                .Where(x => x.Payment != null && paymentIds.Contains(x.Payment.Id))
                .OrderByDescending(x => x.CreatedAtUtc)
                .Select(x => new SalesReservationRow(
                    x.Payment!.Id,
                    x.ReservationCode,
                    x.Flight.FlightNumber,
                    x.Flight.Destination.RouteCode,
                    _dbContext.UserProfiles
                        .Where(p => p.UserId == x.UserId)
                        .Select(p => p.FirstName + " " + p.LastName)
                        .FirstOrDefault() ?? string.Empty,
                    x.Status,
                    x.Items.Count,
                    x.CreatedAtUtc))
                .ToListAsync(cancellationToken);

        var chargesByPaymentId = chargeTransactions
            .GroupBy(x => x.PaymentId)
            .ToDictionary(
                x => x.Key,
                x => x.GroupBy(y => NormalizeCurrency(y.Currency))
                    .Select(y => new CurrencyAmount(y.Key, y.Sum(z => z.Amount)))
                    .OrderBy(y => y.Currency)
                    .ToArray());

        var totalsByCurrency = chargeTransactions
            .GroupBy(x => NormalizeCurrency(x.Currency))
            .Select(x => new CurrencyAmount(x.Key, x.Sum(y => y.Amount)))
            .OrderBy(x => x.Currency)
            .ToArray();

        var soldSeats = reservationRows.Sum(x => x.SeatsCount);
        var lines = BuildReportHeader(
            "Izvjestaj o prodaji",
            request,
            "Period se primjenjuje na datum uspjesno evidentirane naplate.");

        lines.Add($"Broj prodajnih transakcija: {chargeTransactions.Count}");
        lines.Add($"Broj rezervacija sa prodajom u periodu: {reservationRows.Count}");
        lines.Add($"Broj prodatih sjedista: {soldSeats}");
        AddCurrencyAmountLines(lines, "Naplateni iznos po valutama:", totalsByCurrency);
        lines.Add(string.Empty);
        lines.Add("Rezervacija | Let | Ruta | Korisnik | Status | Sjedista | Naplaceno | Kreirano");

        foreach (var row in reservationRows.Take(80))
        {
            var amounts = chargesByPaymentId.TryGetValue(row.PaymentId, out var paymentAmounts)
                ? FormatCurrencyAmounts(paymentAmounts)
                : "-";
            lines.Add(
                $"{row.ReservationCode} | {row.FlightNumber} | {row.RouteCode} | {SafeText(row.CustomerName, 22)} | {FormatReservationStatus(row.Status)} | {row.SeatsCount} | {amounts} | {FormatDate(row.CreatedAtUtc)}");
        }

        if (reservationRows.Count == 0)
        {
            lines.Add("Nema prodaje za odabrani period.");
        }

        return BuildPdf("JetGo - Izvjestaj o prodaji", "jetgo-sales-report", lines);
    }

    public async Task<ReportFileDto> GenerateOccupancyReportAsync(
        ReportPeriodRequest request,
        CancellationToken cancellationToken = default)
    {
        ValidatePeriodRequest(request, "Raspon datuma za izvjestaj o popunjenosti nije validan.");
        await SyncReservationStatusesAsync(cancellationToken);

        var query = _dbContext.Flights.AsNoTracking().AsQueryable();

        if (request.FromUtc.HasValue)
        {
            query = query.Where(x => x.DepartureAtUtc >= request.FromUtc.Value);
        }

        if (request.ToUtc.HasValue)
        {
            query = query.Where(x => x.DepartureAtUtc <= request.ToUtc.Value);
        }

        var flights = await query
            .OrderBy(x => x.DepartureAtUtc)
            .ThenBy(x => x.FlightNumber)
            .Select(x => new OccupancyReportRow(
                x.FlightNumber,
                x.Destination.RouteCode,
                x.Airline.Code,
                x.Status,
                x.DepartureAtUtc,
                x.TotalSeats,
                x.AvailableSeats,
                x.Reservations.Count(r => r.Status == ReservationStatus.Pending),
                x.Reservations.Count(r => r.Status == ReservationStatus.Confirmed),
                x.Reservations.Count(r => r.Status == ReservationStatus.Completed),
                x.Reservations.Count(r => r.Status == ReservationStatus.Cancelled)))
            .ToListAsync(cancellationToken);

        var totalSeats = flights.Sum(x => x.TotalSeats);
        var occupiedSeats = flights.Sum(x => x.OccupiedSeats);
        var occupancyRate = totalSeats == 0 ? 0m : decimal.Round(occupiedSeats * 100m / totalSeats, 2);
        var lines = BuildReportHeader(
            "Izvjestaj o popunjenosti letova",
            request,
            "Period se primjenjuje na datum polaska leta.");

        lines.Add($"Broj letova: {flights.Count}");
        lines.Add($"Ukupno sjedista: {totalSeats}");
        lines.Add($"Zauzeta sjedista: {occupiedSeats}");
        lines.Add($"Ukupna popunjenost: {occupancyRate.ToString("0.00", CultureInfo.InvariantCulture)}%");
        lines.Add(string.Empty);
        lines.Add("Let | Ruta | Aviokompanija | Status | Polazak | Ukupno | Zauzeto | Slobodno | Popunjenost");

        foreach (var row in flights.Take(100))
        {
            lines.Add(
                $"{row.FlightNumber} | {row.RouteCode} | {row.AirlineCode} | {FormatFlightStatus(row.Status)} | {FormatDate(row.DepartureAtUtc)} | {row.TotalSeats} | {row.OccupiedSeats} | {row.AvailableSeats} | {row.OccupancyPercent.ToString("0.00", CultureInfo.InvariantCulture)}%");
        }

        if (flights.Count == 0)
        {
            lines.Add("Nema letova za odabrani period.");
        }

        return BuildPdf("JetGo - Popunjenost letova", "jetgo-occupancy-report", lines);
    }

    public async Task<ReportFileDto> GenerateFinancialReportAsync(
        ReportPeriodRequest request,
        CancellationToken cancellationToken = default)
    {
        ValidatePeriodRequest(request, "Raspon datuma za finansijski izvjestaj nije validan.");
        await SyncReservationStatusesAsync(cancellationToken);

        var transactions = await ApplyTransactionPeriod(
                _dbContext.PaymentTransactions.AsNoTracking()
                    .Where(x =>
                        x.Status == PaymentTransactionStatus.Completed &&
                        MoneyMovementTransactionTypes.Contains(x.Type)),
                request)
            .OrderByDescending(x => x.CompletedAtUtc ?? x.CreatedAtUtc)
            .Select(x => new FinancialTransactionRow(
                x.PaymentId,
                x.Type,
                x.Amount,
                x.Currency,
                x.CompletedAtUtc ?? x.CreatedAtUtc,
                x.Payment.Reservation.ReservationCode,
                x.Payment.Reservation.Flight.FlightNumber,
                x.Payment.Reservation.Flight.Destination.RouteCode))
            .ToListAsync(cancellationToken);

        var statusCounts = await ApplyPaymentPeriod(_dbContext.Payments.AsNoTracking(), request)
            .GroupBy(x => x.Status)
            .Select(x => new PaymentStatusCount(x.Key, x.Count()))
            .ToListAsync(cancellationToken);

        var financialSummaries = transactions
            .GroupBy(x => NormalizeCurrency(x.Currency))
            .Select(x => new FinancialCurrencySummary(
                x.Key,
                x.Where(y => ChargeTransactionTypes.Contains(y.Type)).Sum(y => y.Amount),
                x.Where(y => RefundTransactionTypes.Contains(y.Type)).Sum(y => y.Amount)))
            .OrderBy(x => x.Currency)
            .ToArray();

        var lines = BuildReportHeader(
            "Finansijski izvjestaj",
            request,
            "Period se primjenjuje na datum zavrsene PayPal transakcije.");

        lines.Add($"Zavrsene novcane transakcije: {transactions.Count}");
        lines.Add($"Placanja po statusu: {FormatPaymentStatusCounts(statusCounts)}");
        lines.Add(string.Empty);
        lines.Add("Finansijski total po valutama:");

        if (financialSummaries.Length == 0)
        {
            lines.Add("- Nema novcanih transakcija za odabrani period.");
        }
        else
        {
            foreach (var summary in financialSummaries)
            {
                lines.Add(
                    $"- {summary.Currency}: naplaceno {FormatMoney(summary.ChargedAmount)}, refundirano {FormatMoney(summary.RefundedAmount)}, neto {FormatMoney(summary.NetAmount)}");
            }
        }

        lines.Add(string.Empty);
        lines.Add("Tip | Payment | Rezervacija | Let | Ruta | Iznos | Vrijeme");

        foreach (var row in transactions.Take(100))
        {
            lines.Add(
                $"{FormatTransactionType(row.Type)} | {row.PaymentId} | {row.ReservationCode} | {row.FlightNumber} | {row.RouteCode} | {FormatMoney(row.Amount)} {NormalizeCurrency(row.Currency)} | {FormatDate(row.CompletedAtUtc)}");
        }

        return BuildPdf("JetGo - Finansijski izvjestaj", "jetgo-financial-report", lines);
    }

    public async Task<ReportFileDto> GenerateUsersReportAsync(
        ReportPeriodRequest request,
        CancellationToken cancellationToken = default)
    {
        ValidatePeriodRequest(request, "Raspon datuma za izvjestaj o korisnicima nije validan.");
        await SyncReservationStatusesAsync(cancellationToken);

        var nowOffset = DateTimeOffset.UtcNow;
        var query =
            from user in _dbContext.Users.AsNoTracking()
            join profile in _dbContext.UserProfiles.AsNoTracking() on user.Id equals profile.UserId into profiles
            from profile in profiles.DefaultIfEmpty()
            select new
            {
                user.Id,
                UserName = user.UserName ?? string.Empty,
                Email = profile == null ? user.Email ?? string.Empty : profile.Email,
                FullName = profile == null ? string.Empty : profile.FirstName + " " + profile.LastName,
                RegisteredAtUtc = profile == null ? (DateTime?)null : profile.CreatedAtUtc,
                IsActive = !user.LockoutEnd.HasValue || user.LockoutEnd <= nowOffset,
                ReservationCount = _dbContext.Reservations.Count(r => r.UserId == user.Id),
                PaidPaymentCount = _dbContext.Payments.Count(p =>
                    p.Reservation.UserId == user.Id &&
                    p.Transactions.Any(t =>
                        t.Status == PaymentTransactionStatus.Completed &&
                        ChargeTransactionTypes.Contains(t.Type))),
                SearchHistoryCount = _dbContext.SearchHistories.Count(s => s.UserId == user.Id)
            };

        if (request.FromUtc.HasValue)
        {
            query = query.Where(x => !x.RegisteredAtUtc.HasValue || x.RegisteredAtUtc >= request.FromUtc.Value);
        }

        if (request.ToUtc.HasValue)
        {
            query = query.Where(x => !x.RegisteredAtUtc.HasValue || x.RegisteredAtUtc <= request.ToUtc.Value);
        }

        var users = await query
            .OrderBy(x => x.UserName)
            .ToListAsync(cancellationToken);

        var userIds = users.Select(x => x.Id).ToArray();
        var roleRows = await (
                from userRole in _dbContext.UserRoles.AsNoTracking()
                join role in _dbContext.Roles.AsNoTracking() on userRole.RoleId equals role.Id
                where userIds.Contains(userRole.UserId)
                select new
                {
                    userRole.UserId,
                    RoleName = role.Name ?? string.Empty
                })
            .ToListAsync(cancellationToken);

        var rolesByUserId = roleRows
            .GroupBy(x => x.UserId)
            .ToDictionary(
                x => x.Key,
                x => string.Join(", ", x.Select(y => y.RoleName).Where(y => !string.IsNullOrWhiteSpace(y)).OrderBy(y => y)));

        var activeCount = users.Count(x => x.IsActive);
        var inactiveCount = users.Count - activeCount;
        var lines = BuildReportHeader(
            "Izvjestaj o korisnicima",
            request,
            "Period se primjenjuje na datum kreiranja korisnickog profila.");

        lines.Add($"Ukupno korisnika: {users.Count}");
        lines.Add($"Aktivni korisnici: {activeCount}");
        lines.Add($"Neaktivni korisnici: {inactiveCount}");
        lines.Add($"Ukupno rezervacija korisnika: {users.Sum(x => x.ReservationCount)}");
        lines.Add($"Ukupno placenih payment tokova: {users.Sum(x => x.PaidPaymentCount)}");
        lines.Add(string.Empty);
        lines.Add("Korisnik | Ime i prezime | Email | Role | Status | Rezervacije | Placanja | Pretrage");

        foreach (var user in users.Take(100))
        {
            var roles = rolesByUserId.GetValueOrDefault(user.Id, "-");
            lines.Add(
                $"{SafeText(user.UserName, 18)} | {SafeText(user.FullName, 22)} | {SafeText(user.Email, 26)} | {SafeText(roles, 18)} | {(user.IsActive ? "Aktivan" : "Neaktivan")} | {user.ReservationCount} | {user.PaidPaymentCount} | {user.SearchHistoryCount}");
        }

        if (users.Count == 0)
        {
            lines.Add("Nema korisnika za odabrani period.");
        }

        return BuildPdf("JetGo - Izvjestaj o korisnicima", "jetgo-users-report", lines);
    }

    public async Task<ReportFileDto> GenerateReservationsReportAsync(
        ReservationReportRequest request,
        CancellationToken cancellationToken = default)
    {
        ValidateLegacyReservationRequest(request);

        return await GenerateSalesReportAsync(
            new ReportPeriodRequest
            {
                FromUtc = request.CreatedFromUtc,
                ToUtc = request.CreatedToUtc
            },
            cancellationToken);
    }

    public async Task<ReportFileDto> GeneratePaymentsReportAsync(
        PaymentReportRequest request,
        CancellationToken cancellationToken = default)
    {
        ValidateLegacyPaymentRequest(request);

        return await GenerateFinancialReportAsync(
            new ReportPeriodRequest
            {
                FromUtc = request.CreatedFromUtc,
                ToUtc = request.CreatedToUtc
            },
            cancellationToken);
    }

    private async Task SyncReservationStatusesAsync(CancellationToken cancellationToken)
    {
        await _reservationStatusSyncService.SyncCompletedReservationsAsync(DateTime.UtcNow, cancellationToken);
    }

    private static IQueryable<JetGo.Domain.Entities.PaymentTransaction> ApplyTransactionPeriod(
        IQueryable<JetGo.Domain.Entities.PaymentTransaction> query,
        ReportPeriodRequest request)
    {
        if (request.FromUtc.HasValue)
        {
            query = query.Where(x => (x.CompletedAtUtc ?? x.CreatedAtUtc) >= request.FromUtc.Value);
        }

        if (request.ToUtc.HasValue)
        {
            query = query.Where(x => (x.CompletedAtUtc ?? x.CreatedAtUtc) <= request.ToUtc.Value);
        }

        return query;
    }

    private static IQueryable<JetGo.Domain.Entities.Payment> ApplyPaymentPeriod(
        IQueryable<JetGo.Domain.Entities.Payment> query,
        ReportPeriodRequest request)
    {
        if (request.FromUtc.HasValue)
        {
            query = query.Where(x => x.CreatedAtUtc >= request.FromUtc.Value);
        }

        if (request.ToUtc.HasValue)
        {
            query = query.Where(x => x.CreatedAtUtc <= request.ToUtc.Value);
        }

        return query;
    }

    private static List<string> BuildReportHeader(string reportName, ReportPeriodRequest request, string periodDescription)
    {
        return
        [
            $"Generisano (UTC): {DateTime.UtcNow:yyyy-MM-dd HH:mm}",
            $"Vrsta izvjestaja: {reportName}",
            "Format: PDF",
            $"Period od: {FormatDate(request.FromUtc)}",
            $"Period do: {FormatDate(request.ToUtc)}",
            periodDescription,
            string.Empty
        ];
    }

    private static void AddCurrencyAmountLines(
        ICollection<string> lines,
        string title,
        IReadOnlyCollection<CurrencyAmount> amounts)
    {
        lines.Add(title);

        if (amounts.Count == 0)
        {
            lines.Add("- Nema iznosa za prikaz.");
            return;
        }

        foreach (var amount in amounts)
        {
            lines.Add($"- {amount.Currency}: {FormatMoney(amount.Amount)}");
        }
    }

    private static string FormatCurrencyAmounts(IReadOnlyCollection<CurrencyAmount> amounts)
    {
        return amounts.Count == 0
            ? "-"
            : string.Join(", ", amounts.Select(x => $"{FormatMoney(x.Amount)} {x.Currency}"));
    }

    private static string FormatPaymentStatusCounts(IReadOnlyCollection<PaymentStatusCount> statusCounts)
    {
        if (statusCounts.Count == 0)
        {
            return "nema payment zapisa";
        }

        return string.Join(", ", statusCounts
            .OrderBy(x => x.Status)
            .Select(x => $"{FormatPaymentStatus(x.Status)}: {x.Count}"));
    }

    private static void ValidatePeriodRequest(ReportPeriodRequest request, string message)
    {
        if (request.FromUtc.HasValue && request.ToUtc.HasValue && request.FromUtc > request.ToUtc)
        {
            throw new ValidationException(
                message,
                new Dictionary<string, string[]>
                {
                    ["toUtc"] = ["Datum 'toUtc' mora biti veci ili jednak datumu 'fromUtc'."]
                });
        }
    }

    private static void ValidateLegacyReservationRequest(ReservationReportRequest request)
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

    private static void ValidateLegacyPaymentRequest(PaymentReportRequest request)
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

    private static ReportFileDto BuildPdf(string title, string fileNamePrefix, IReadOnlyCollection<string> lines)
    {
        return new ReportFileDto
        {
            FileName = $"{fileNamePrefix}-{DateTime.UtcNow:yyyyMMddHHmmss}.pdf",
            Content = SimplePdfReportBuilder.Build(title, lines)
        };
    }

    private static string FormatDate(DateTime? value)
    {
        return value.HasValue
            ? value.Value.ToString("yyyy-MM-dd HH:mm", CultureInfo.InvariantCulture)
            : "N/A";
    }

    private static string FormatMoney(decimal value)
    {
        return value.ToString("0.00", CultureInfo.InvariantCulture);
    }

    private static string NormalizeCurrency(string value)
    {
        return string.IsNullOrWhiteSpace(value) ? "N/A" : value.Trim().ToUpperInvariant();
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

    private static string FormatReservationStatus(ReservationStatus status)
    {
        return status switch
        {
            ReservationStatus.Pending => "Na cekanju",
            ReservationStatus.Confirmed => "Potvrdjeno",
            ReservationStatus.Cancelled => "Otkazano",
            ReservationStatus.Completed => "Zavrseno",
            _ => status.ToString()
        };
    }

    private static string FormatFlightStatus(FlightStatus status)
    {
        return status switch
        {
            FlightStatus.Scheduled => "Planiran",
            FlightStatus.Delayed => "Odlozen",
            FlightStatus.Cancelled => "Otkazan",
            FlightStatus.Completed => "Zavrsen",
            _ => status.ToString()
        };
    }

    private static string FormatPaymentStatus(PaymentStatus status)
    {
        return status switch
        {
            PaymentStatus.Pending => "Na cekanju",
            PaymentStatus.Paid => "Placeno",
            PaymentStatus.Failed => "Neuspjelo",
            PaymentStatus.Refunded => "Refundirano",
            _ => status.ToString()
        };
    }

    private static string FormatTransactionType(PaymentTransactionType type)
    {
        return type switch
        {
            PaymentTransactionType.InitialPayment => "Naplata",
            PaymentTransactionType.AdditionalCharge => "Doplata",
            PaymentTransactionType.PartialRefund => "Djelimicni refund",
            PaymentTransactionType.FullRefund => "Puni refund",
            _ => type.ToString()
        };
    }

    private sealed record CurrencyAmount(string Currency, decimal Amount);

    private sealed record SalesChargeTransaction(int PaymentId, decimal Amount, string Currency, DateTime CompletedAtUtc);

    private sealed record SalesReservationRow(
        int PaymentId,
        string ReservationCode,
        string FlightNumber,
        string RouteCode,
        string CustomerName,
        ReservationStatus Status,
        int SeatsCount,
        DateTime CreatedAtUtc);

    private sealed record OccupancyReportRow(
        string FlightNumber,
        string RouteCode,
        string AirlineCode,
        FlightStatus Status,
        DateTime DepartureAtUtc,
        int TotalSeats,
        int AvailableSeats,
        int PendingReservationCount,
        int ConfirmedReservationCount,
        int CompletedReservationCount,
        int CancelledReservationCount)
    {
        public int OccupiedSeats => Math.Max(0, TotalSeats - AvailableSeats);

        public decimal OccupancyPercent => TotalSeats == 0
            ? 0m
            : decimal.Round(OccupiedSeats * 100m / TotalSeats, 2);
    }

    private sealed record FinancialTransactionRow(
        int PaymentId,
        PaymentTransactionType Type,
        decimal Amount,
        string Currency,
        DateTime CompletedAtUtc,
        string ReservationCode,
        string FlightNumber,
        string RouteCode);

    private sealed record FinancialCurrencySummary(string Currency, decimal ChargedAmount, decimal RefundedAmount)
    {
        public decimal NetAmount => ChargedAmount - RefundedAmount;
    }

    private sealed record PaymentStatusCount(PaymentStatus Status, int Count);
}
