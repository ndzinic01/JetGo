class AdminNotificationItem {
  AdminNotificationItem({
    required this.type,
    required this.title,
    required this.body,
    required this.status,
    required this.createdAtUtc,
    required this.readAtUtc,
    required this.flightNumber,
    required this.reservationCode,
    required this.recipientName,
    required this.recipientEmail,
  });

  final NotificationTypeValue type;
  final String title;
  final String body;
  final NotificationStatusValue status;
  final DateTime createdAtUtc;
  final DateTime? readAtUtc;
  final String? flightNumber;
  final String? reservationCode;
  final String recipientName;
  final String recipientEmail;

  factory AdminNotificationItem.fromJson(Map<String, dynamic> json) {
    return AdminNotificationItem(
      type: NotificationTypeValue.fromValue(json['type'] as int? ?? 1),
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      status: NotificationStatusValue.fromValue(json['status'] as int? ?? 1),
      createdAtUtc: DateTime.parse(json['createdAtUtc'] as String),
      readAtUtc: json['readAtUtc'] == null
          ? null
          : DateTime.parse(json['readAtUtc'] as String),
      flightNumber: _emptyToNull(json['flightNumber'] as String?),
      reservationCode: _emptyToNull(json['reservationCode'] as String?),
      recipientName: json['recipientName'] as String? ?? '',
      recipientEmail: json['recipientEmail'] as String? ?? '',
    );
  }

  static String? _emptyToNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}

enum NotificationStatusValue {
  unread(1, 'Neprocitano'),
  read(2, 'Procitano');

  const NotificationStatusValue(this.value, this.label);

  final int value;
  final String label;

  static NotificationStatusValue fromValue(int value) {
    return NotificationStatusValue.values.firstWhere(
      (item) => item.value == value,
      orElse: () => NotificationStatusValue.unread,
    );
  }
}

enum NotificationTypeValue {
  system(1, 'Sistemska'),
  reservationCreated(2, 'Rezervacija kreirana'),
  reservationChanged(3, 'Izmjena rezervacije'),
  reservationCancelled(4, 'Rezervacija otkazana'),
  reservationExpired(5, 'Rezervacija istekla'),
  reservationCompleted(6, 'Putovanje zavrseno'),
  paymentCompleted(7, 'Placanje potvrdjeno'),
  paymentRefunded(8, 'Placanje refundirano'),
  flightStatusChanged(9, 'Promjena statusa leta'),
  flightTimeChanged(10, 'Promjena vremena leta'),
  supportReply(11, 'Odgovor podrske');

  const NotificationTypeValue(this.value, this.label);

  final int value;
  final String label;

  static NotificationTypeValue fromValue(int value) {
    return NotificationTypeValue.values.firstWhere(
      (item) => item.value == value,
      orElse: () => NotificationTypeValue.system,
    );
  }
}
