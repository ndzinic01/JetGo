namespace JetGo.Domain.Enums;

public enum NotificationType
{
    System = 1,
    ReservationCreated = 2,
    ReservationChanged = 3,
    ReservationCancelled = 4,
    ReservationExpired = 5,
    ReservationCompleted = 6,
    PaymentCompleted = 7,
    PaymentRefunded = 8,
    FlightStatusChanged = 9,
    FlightTimeChanged = 10,
    SupportReply = 11
}
