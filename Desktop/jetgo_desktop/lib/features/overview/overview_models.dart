class AdminDashboardSummary {
  AdminDashboardSummary({
    required this.generatedAtUtc,
    required this.totalUsersCount,
    required this.activeUsersCount,
    required this.inactiveUsersCount,
    required this.upcomingFlightsCount,
    required this.delayedFlightsCount,
    required this.totalReservationsCount,
    required this.pendingReservationsCount,
    required this.openSupportMessagesCount,
    required this.answeredSupportMessagesCount,
    required this.pendingPaymentsCount,
    required this.paidPaymentsCount,
    required this.refundedPaymentsCount,
    required this.paidAmountsByCurrency,
    required this.recentReservations,
    required this.recentPayments,
    required this.recentSupportMessages,
  });

  final DateTime generatedAtUtc;
  final int totalUsersCount;
  final int activeUsersCount;
  final int inactiveUsersCount;
  final int upcomingFlightsCount;
  final int delayedFlightsCount;
  final int totalReservationsCount;
  final int pendingReservationsCount;
  final int openSupportMessagesCount;
  final int answeredSupportMessagesCount;
  final int pendingPaymentsCount;
  final int paidPaymentsCount;
  final int refundedPaymentsCount;
  final List<AdminDashboardAmount> paidAmountsByCurrency;
  final List<AdminDashboardRecentReservation> recentReservations;
  final List<AdminDashboardRecentPayment> recentPayments;
  final List<AdminDashboardRecentSupportMessage> recentSupportMessages;

  factory AdminDashboardSummary.fromJson(Map<String, dynamic> json) {
    return AdminDashboardSummary(
      generatedAtUtc: DateTime.parse(json['generatedAtUtc'] as String),
      totalUsersCount: json['totalUsersCount'] as int? ?? 0,
      activeUsersCount: json['activeUsersCount'] as int? ?? 0,
      inactiveUsersCount: json['inactiveUsersCount'] as int? ?? 0,
      upcomingFlightsCount: json['upcomingFlightsCount'] as int? ?? 0,
      delayedFlightsCount: json['delayedFlightsCount'] as int? ?? 0,
      totalReservationsCount: json['totalReservationsCount'] as int? ?? 0,
      pendingReservationsCount: json['pendingReservationsCount'] as int? ?? 0,
      openSupportMessagesCount: json['openSupportMessagesCount'] as int? ?? 0,
      answeredSupportMessagesCount:
          json['answeredSupportMessagesCount'] as int? ?? 0,
      pendingPaymentsCount: json['pendingPaymentsCount'] as int? ?? 0,
      paidPaymentsCount: json['paidPaymentsCount'] as int? ?? 0,
      refundedPaymentsCount: json['refundedPaymentsCount'] as int? ?? 0,
      paidAmountsByCurrency:
          (json['paidAmountsByCurrency'] as List<dynamic>? ?? const [])
              .map(
                (item) =>
                    AdminDashboardAmount.fromJson(item as Map<String, dynamic>),
              )
              .toList(),
      recentReservations:
          (json['recentReservations'] as List<dynamic>? ?? const [])
              .map(
                (item) => AdminDashboardRecentReservation.fromJson(
                  item as Map<String, dynamic>,
                ),
              )
              .toList(),
      recentPayments: (json['recentPayments'] as List<dynamic>? ?? const [])
          .map(
            (item) => AdminDashboardRecentPayment.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList(),
      recentSupportMessages:
          (json['recentSupportMessages'] as List<dynamic>? ?? const [])
              .map(
                (item) => AdminDashboardRecentSupportMessage.fromJson(
                  item as Map<String, dynamic>,
                ),
              )
              .toList(),
    );
  }
}

class AdminDashboardAmount {
  AdminDashboardAmount({
    required this.currency,
    required this.amount,
  });

  final String currency;
  final double amount;

  factory AdminDashboardAmount.fromJson(Map<String, dynamic> json) {
    return AdminDashboardAmount(
      currency: json['currency'] as String? ?? 'BAM',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
    );
  }
}

class AdminDashboardRecentReservation {
  AdminDashboardRecentReservation({
    required this.reservationCode,
    required this.flightNumber,
    required this.routeCode,
    required this.customerName,
    required this.status,
    required this.totalAmount,
    required this.currency,
    required this.createdAtUtc,
  });

  final String reservationCode;
  final String flightNumber;
  final String routeCode;
  final String customerName;
  final int status;
  final double totalAmount;
  final String currency;
  final DateTime createdAtUtc;

  factory AdminDashboardRecentReservation.fromJson(Map<String, dynamic> json) {
    return AdminDashboardRecentReservation(
      reservationCode: json['reservationCode'] as String? ?? '',
      flightNumber: json['flightNumber'] as String? ?? '',
      routeCode: json['routeCode'] as String? ?? '',
      customerName: json['customerName'] as String? ?? '',
      status: json['status'] as int? ?? 1,
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0,
      currency: json['currency'] as String? ?? 'BAM',
      createdAtUtc: DateTime.parse(json['createdAtUtc'] as String),
    );
  }
}

class AdminDashboardRecentPayment {
  AdminDashboardRecentPayment({
    required this.id,
    required this.reservationCode,
    required this.flightNumber,
    required this.routeCode,
    required this.customerName,
    required this.status,
    required this.amount,
    required this.currency,
    required this.createdAtUtc,
  });

  final int id;
  final String reservationCode;
  final String flightNumber;
  final String routeCode;
  final String customerName;
  final int status;
  final double amount;
  final String currency;
  final DateTime createdAtUtc;

  factory AdminDashboardRecentPayment.fromJson(Map<String, dynamic> json) {
    return AdminDashboardRecentPayment(
      id: json['id'] as int? ?? 0,
      reservationCode: json['reservationCode'] as String? ?? '',
      flightNumber: json['flightNumber'] as String? ?? '',
      routeCode: json['routeCode'] as String? ?? '',
      customerName: json['customerName'] as String? ?? '',
      status: json['status'] as int? ?? 1,
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      currency: json['currency'] as String? ?? 'BAM',
      createdAtUtc: DateTime.parse(json['createdAtUtc'] as String),
    );
  }
}

class AdminDashboardRecentSupportMessage {
  AdminDashboardRecentSupportMessage({
    required this.id,
    required this.subject,
    required this.customerName,
    required this.customerEmail,
    required this.isReplied,
    required this.createdAtUtc,
    required this.repliedAtUtc,
  });

  final int id;
  final String subject;
  final String customerName;
  final String customerEmail;
  final bool isReplied;
  final DateTime createdAtUtc;
  final DateTime? repliedAtUtc;

  factory AdminDashboardRecentSupportMessage.fromJson(
    Map<String, dynamic> json,
  ) {
    return AdminDashboardRecentSupportMessage(
      id: json['id'] as int? ?? 0,
      subject: json['subject'] as String? ?? '',
      customerName: json['customerName'] as String? ?? '',
      customerEmail: json['customerEmail'] as String? ?? '',
      isReplied: json['isReplied'] as bool? ?? false,
      createdAtUtc: DateTime.parse(json['createdAtUtc'] as String),
      repliedAtUtc: json['repliedAtUtc'] == null
          ? null
          : DateTime.parse(json['repliedAtUtc'] as String),
    );
  }
}
