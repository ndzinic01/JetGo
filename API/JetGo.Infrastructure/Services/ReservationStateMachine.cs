using JetGo.Application.Exceptions;
using JetGo.Domain.Entities;
using JetGo.Domain.Enums;

namespace JetGo.Infrastructure.Services;

public sealed class ReservationStateMachine
{
    private const string AutoCompletedReason = "Rezervacija je automatski oznacena kao zavrsena jer je proslo planirano vrijeme dolaska leta.";

    public void MarkCreated(Reservation reservation, string actorUserId, DateTime nowUtc)
    {
        reservation.Status = ReservationStatus.Pending;
        reservation.StatusChangedByUserId = actorUserId;
        reservation.StatusChangedAtUtc = nowUtc;
        reservation.StatusReason = "Rezervacija je kreirana i ceka zavrsetak placanja.";
    }

    public void MarkPaymentConfirmed(Reservation reservation, string actorUserId, DateTime nowUtc)
    {
        if (reservation.Status == ReservationStatus.Confirmed)
        {
            return;
        }

        if (reservation.Status != ReservationStatus.Pending)
        {
            throw new ValidationException(
                "Samo rezervacija koja ceka placanje moze biti potvrdjena.",
                new Dictionary<string, string[]>
                {
                    ["status"] = ["Potvrda je dozvoljena samo za rezervacije u statusu Pending."]
                });
        }

        reservation.Status = ReservationStatus.Confirmed;
        reservation.StatusChangedByUserId = actorUserId;
        reservation.StatusChangedAtUtc = nowUtc;
        reservation.StatusReason = "Rezervacija je potvrdjena nakon uspjesnog placanja.";
    }

    public void MarkChanged(Reservation reservation, string actorUserId, string reason, DateTime nowUtc)
    {
        if (reservation.Status is ReservationStatus.Cancelled or ReservationStatus.Completed)
        {
            throw new ValidationException(
                "Zavrsena ili otkazana rezervacija se ne moze mijenjati.",
                new Dictionary<string, string[]>
                {
                    ["status"] = ["Izmjena je dozvoljena samo za aktivne rezervacije."]
                });
        }

        reservation.StatusChangedByUserId = actorUserId;
        reservation.StatusChangedAtUtc = nowUtc;
        reservation.StatusReason = reason.Trim();
        reservation.UpdatedAtUtc = nowUtc;
    }

    public void MarkChangeRequiresPayment(Reservation reservation, string actorUserId, string reason, DateTime nowUtc)
    {
        if (reservation.Status is ReservationStatus.Cancelled or ReservationStatus.Completed)
        {
            throw new ValidationException(
                "Zavrsena ili otkazana rezervacija se ne moze mijenjati.",
                new Dictionary<string, string[]>
                {
                    ["status"] = ["Izmjena je dozvoljena samo za aktivne rezervacije."]
                });
        }

        reservation.Status = ReservationStatus.Pending;
        reservation.StatusChangedByUserId = actorUserId;
        reservation.StatusChangedAtUtc = nowUtc;
        reservation.StatusReason = reason.Trim();
        reservation.UpdatedAtUtc = nowUtc;
    }
    public bool TryExpirePendingPayment(
        Reservation reservation,
        string actorUserId,
        DateTime nowUtc,
        TimeSpan paymentHoldDuration)
    {
        if (reservation.Status != ReservationStatus.Pending)
        {
            return false;
        }

        var holdStartedAtUtc = reservation.StatusChangedAtUtc ?? reservation.CreatedAtUtc;

        if (holdStartedAtUtc.Add(paymentHoldDuration) > nowUtc)
        {
            return false;
        }

        reservation.Status = ReservationStatus.Cancelled;
        reservation.StatusChangedByUserId = actorUserId;
        reservation.StatusChangedAtUtc = nowUtc;
        reservation.StatusReason = "Rezervacija je istekla jer placanje nije zavrseno u predvidjenom roku.";
        reservation.UpdatedAtUtc = nowUtc;

        return true;
    }

    public void Cancel(Reservation reservation, string actorUserId, string reason, DateTime nowUtc, bool hasCompletedPayment)
    {
        if (reservation.Status == ReservationStatus.Cancelled)
        {
            throw new ValidationException(
                "Rezervacija je vec otkazana.",
                new Dictionary<string, string[]>
                {
                    ["status"] = ["Rezervacija se ne moze ponovo otkazati."]
                });
        }

        if (reservation.Status == ReservationStatus.Completed)
        {
            throw new ValidationException(
                "Zavrsena rezervacija se ne moze otkazati.",
                new Dictionary<string, string[]>
                {
                    ["status"] = ["Rezervacija u statusu Completed ne moze biti otkazana."]
                });
        }

        if (hasCompletedPayment)
        {
            throw new ValidationException(
                "Placena rezervacija se trenutno ne moze otkazati bez refund toka.",
                new Dictionary<string, string[]>
                {
                    ["payment"] = ["Prije otkazivanja placene rezervacije potrebno je koristiti refund tok."]
                });
        }

        reservation.Status = ReservationStatus.Cancelled;
        reservation.StatusChangedByUserId = actorUserId;
        reservation.StatusChangedAtUtc = nowUtc;
        reservation.StatusReason = reason.Trim();
        reservation.UpdatedAtUtc = nowUtc;
    }

    public void CancelAfterRefund(Reservation reservation, string actorUserId, string reason, DateTime nowUtc)
    {
        if (reservation.Status == ReservationStatus.Cancelled)
        {
            throw new ValidationException(
                "Rezervacija je vec otkazana.",
                new Dictionary<string, string[]>
                {
                    ["status"] = ["Refundirano placanje ne moze ponovo otkazati istu rezervaciju."]
                });
        }

        if (reservation.Status == ReservationStatus.Completed)
        {
            throw new ValidationException(
                "Zavrsena rezervacija se ne moze otkazati nakon refundacije.",
                new Dictionary<string, string[]>
                {
                    ["status"] = ["Refund nije dozvoljen za rezervacije u statusu Completed."]
                });
        }

        if (reservation.Status is not (ReservationStatus.Confirmed or ReservationStatus.Pending))
        {
            throw new ValidationException(
                "Refund moze otkazati samo aktivnu rezervaciju.",
                new Dictionary<string, string[]>
                {
                    ["status"] = ["Rezervacija mora biti u statusu Pending ili Confirmed prije refundacije placanja."]
                });
        }

        reservation.Status = ReservationStatus.Cancelled;
        reservation.StatusChangedByUserId = actorUserId;
        reservation.StatusChangedAtUtc = nowUtc;
        reservation.StatusReason = $"Rezervacija je otkazana nakon refundacije placanja. Razlog: {reason.Trim()}";
        reservation.UpdatedAtUtc = nowUtc;
    }

    public void Complete(Reservation reservation, string actorUserId, string? reason, DateTime nowUtc)
    {
        if (reservation.Status != ReservationStatus.Confirmed)
        {
            throw new ValidationException(
                "Samo potvrdjena rezervacija moze biti zavrsena.",
                new Dictionary<string, string[]>
                {
                    ["status"] = ["Zavrsetak je dozvoljen samo za rezervacije u statusu Confirmed."]
                });
        }

        if (reservation.Flight.ArrivalAtUtc > nowUtc)
        {
            throw new ValidationException(
                "Rezervacija se ne moze oznaciti zavrsenom prije dolaska leta.",
                new Dictionary<string, string[]>
                {
                    ["flight"] = ["Let mora biti zavrsen prije nego sto rezervacija predje u status Completed."]
                });
        }

        if (reservation.Payment?.Status != PaymentStatus.Paid)
        {
            throw new ValidationException(
                "Rezervacija se ne moze oznaciti zavrsenom bez evidentiranog placanja.",
                new Dictionary<string, string[]>
                {
                    ["payment"] = ["Prije statusa Completed placanje mora biti u statusu Paid."]
                });
        }

        reservation.Status = ReservationStatus.Completed;
        reservation.StatusChangedByUserId = actorUserId;
        reservation.StatusChangedAtUtc = nowUtc;
        reservation.StatusReason = string.IsNullOrWhiteSpace(reason)
            ? "Rezervacija je oznacena kao zavrsena."
            : reason.Trim();
    }

    public bool TryAutoCompleteAfterArrival(Reservation reservation, string actorUserId, DateTime nowUtc)
    {
        if (reservation.Status is ReservationStatus.Cancelled or ReservationStatus.Completed)
        {
            return false;
        }

        if (reservation.Flight.ArrivalAtUtc > nowUtc)
        {
            return false;
        }

        if (reservation.Status != ReservationStatus.Confirmed)
        {
            return false;
        }

        if (reservation.Payment?.Status != PaymentStatus.Paid)
        {
            return false;
        }

        Complete(reservation, actorUserId, AutoCompletedReason, nowUtc);
        reservation.UpdatedAtUtc = nowUtc;
        return true;
    }

    public bool CanCancel(ReservationStatus status)
    {
        return status is ReservationStatus.Pending or ReservationStatus.Confirmed;
    }

    public bool CanComplete(ReservationStatus status)
    {
        return status == ReservationStatus.Confirmed;
    }

    public ReservationStatus GetEffectiveStatus(
        ReservationStatus status,
        PaymentStatus? paymentStatus,
        DateTime arrivalAtUtc,
        DateTime nowUtc)
    {
        if (status is ReservationStatus.Cancelled or ReservationStatus.Completed)
        {
            return status;
        }

        return status == ReservationStatus.Confirmed &&
            paymentStatus == PaymentStatus.Paid &&
            arrivalAtUtc <= nowUtc
            ? ReservationStatus.Completed
            : status;
    }
}
