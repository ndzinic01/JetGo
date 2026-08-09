abstract final class MobileFlightStatus {
  static const int unknown = 0;
  static const int scheduled = 1;
  static const int delayed = 2;
  static const int cancelled = 3;
  static const int completed = 4;
}

abstract final class MobileReservationStatus {
  static const int unknown = 0;
  static const int pending = 1;
  static const int confirmed = 2;
  static const int cancelled = 3;
  static const int completed = 4;
}

abstract final class MobilePaymentStatus {
  static const int unknown = 0;
  static const int pending = 1;
  static const int paid = 2;
  static const int failed = 3;
  static const int refunded = 4;
}

abstract final class MobileNotificationStatus {
  static const int unknown = 0;
  static const int unread = 1;
  static const int read = 2;
}
