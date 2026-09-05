using JetGo.Domain.Entities;
using JetGo.Domain.Enums;

namespace JetGo.Infrastructure.Services;

internal static class PaymentLedger
{
    private static readonly PaymentTransactionType[] ChargeTypes =
    [
        PaymentTransactionType.InitialPayment,
        PaymentTransactionType.AdditionalCharge
    ];

    private static readonly PaymentTransactionType[] RefundTypes =
    [
        PaymentTransactionType.PartialRefund,
        PaymentTransactionType.FullRefund
    ];

    public static bool HasCompletedCharge(Payment payment)
    {
        return payment.Transactions.Any(x =>
            ChargeTypes.Contains(x.Type) &&
            x.Status == PaymentTransactionStatus.Completed);
    }

    public static PaymentTransactionType GetNextChargeType(Payment payment)
    {
        return HasCompletedCharge(payment)
            ? PaymentTransactionType.AdditionalCharge
            : PaymentTransactionType.InitialPayment;
    }

    public static PaymentTransaction? FindPendingCharge(Payment payment)
    {
        return payment.Transactions
            .Where(x => ChargeTypes.Contains(x.Type) && x.Status == PaymentTransactionStatus.Pending)
            .OrderByDescending(x => x.CreatedAtUtc)
            .FirstOrDefault();
    }

    public static decimal CalculateNetPaidAmount(Payment payment)
    {
        if (payment.Transactions.Count == 0)
        {
            return payment.Status == PaymentStatus.Paid ? payment.Amount : 0m;
        }

        var capturedAmount = payment.Transactions
            .Where(x => ChargeTypes.Contains(x.Type) && x.Status == PaymentTransactionStatus.Completed)
            .Sum(x => x.Amount);

        var refundedAmount = payment.Transactions
            .Where(x => RefundTypes.Contains(x.Type) && x.Status == PaymentTransactionStatus.Completed)
            .Sum(x => x.Amount);

        return Math.Max(0m, capturedAmount - refundedAmount);
    }

    public static IReadOnlyList<RefundablePaymentCapture> GetRefundableCaptures(Payment payment)
    {
        if (payment.Transactions.Count == 0)
        {
            if (payment.Status == PaymentStatus.Paid &&
                !string.IsNullOrWhiteSpace(payment.ProviderReference) &&
                payment.Amount > 0m)
            {
                return [new RefundablePaymentCapture(payment.ProviderReference, payment.Amount, payment.Currency)];
            }

            return [];
        }

        var refundedByCapture = payment.Transactions
            .Where(x =>
                RefundTypes.Contains(x.Type) &&
                x.Status == PaymentTransactionStatus.Completed &&
                !string.IsNullOrWhiteSpace(x.RelatedProviderReference))
            .GroupBy(x => x.RelatedProviderReference!)
            .ToDictionary(x => x.Key, x => x.Sum(y => y.Amount));

        return payment.Transactions
            .Where(x =>
                ChargeTypes.Contains(x.Type) &&
                x.Status == PaymentTransactionStatus.Completed &&
                !string.IsNullOrWhiteSpace(x.ProviderReference))
            .OrderBy(x => x.CompletedAtUtc ?? x.CreatedAtUtc)
            .Select(x =>
            {
                var refundedAmount = refundedByCapture.GetValueOrDefault(x.ProviderReference!, 0m);
                var remainingAmount = Math.Max(0m, x.Amount - refundedAmount);
                return new RefundablePaymentCapture(x.ProviderReference!, remainingAmount, x.Currency);
            })
            .Where(x => x.Amount > 0m)
            .ToArray();
    }
}

internal sealed record RefundablePaymentCapture(string CaptureId, decimal Amount, string Currency);
