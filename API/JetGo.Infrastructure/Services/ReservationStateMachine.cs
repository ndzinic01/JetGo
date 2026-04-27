using JetGo.Application.Exceptions;
using JetGo.Domain.Entities;
using JetGo.Domain.Enums;

namespace JetGo.Infrastructure.Services;

public sealed class ReservationStateMachine
{
    public void MarkCreated(Reservation reservation, string actorUserId, DateTime nowUtc)
    {
        reservation.Status = ReservationStatus.Pending;
        reservation.StatusChangedByUserId = actorUserId;
        reservation.StatusChangedAtUtc = nowUtc;
        reservation.StatusReason = "Rezervacija je kreirana i ceka potvrdu.";
    }

    public void Confirm(Reservation reservation, string actorUserId, string? reason, DateTime nowUtc)
    {
        if (reservation.Status != ReservationStatus.Pending)
        {
            throw new ValidationException(
                "Samo rezervacija u statusu Pending moze biti potvrdjena.",
                new Dictionary<string, string[]>
                {
                    ["status"] = ["Potvrda je dozvoljena samo za rezervacije u statusu Pending."]
                });
        }

        reservation.Status = ReservationStatus.Confirmed;
        reservation.StatusChangedByUserId = actorUserId;
        reservation.StatusChangedAtUtc = nowUtc;
        reservation.StatusReason = string.IsNullOrWhiteSpace(reason)
            ? "Rezervacija je potvrdjena od strane administratora."
            : reason.Trim();
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
                    ["payment"] = ["Prije otkazivanja placene rezervacije potrebno je implementirati refund logiku."]
                });
        }

        reservation.Status = ReservationStatus.Cancelled;
        reservation.StatusChangedByUserId = actorUserId;
        reservation.StatusChangedAtUtc = nowUtc;
        reservation.StatusReason = reason.Trim();
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

        reservation.Status = ReservationStatus.Completed;
        reservation.StatusChangedByUserId = actorUserId;
        reservation.StatusChangedAtUtc = nowUtc;
        reservation.StatusReason = string.IsNullOrWhiteSpace(reason)
            ? "Rezervacija je oznacena kao zavrsena."
            : reason.Trim();
    }

    public bool CanCancel(ReservationStatus status)
    {
        return status is ReservationStatus.Pending or ReservationStatus.Confirmed;
    }

    public bool CanConfirm(ReservationStatus status)
    {
        return status == ReservationStatus.Pending;
    }

    public bool CanComplete(ReservationStatus status)
    {
        return status == ReservationStatus.Confirmed;
    }
}
