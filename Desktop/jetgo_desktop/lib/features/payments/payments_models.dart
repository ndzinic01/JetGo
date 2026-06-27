class PaymentItem {
  PaymentItem({
    required this.id,
    required this.reservationId,
    required this.reservationCode,
    required this.flightNumber,
    required this.routeCode,
    required this.provider,
    required this.amount,
    required this.currency,
    required this.status,
    required this.isPaid,
    required this.createdAtUtc,
    required this.paidAtUtc,
    required this.refundedAtUtc,
    required this.customerName,
  });

  final int id;
  final int reservationId;
  final String reservationCode;
  final String flightNumber;
  final String routeCode;
  final String provider;
  final double amount;
  final String currency;
  final PaymentStatusValue status;
  final bool isPaid;
  final DateTime createdAtUtc;
  final DateTime? paidAtUtc;
  final DateTime? refundedAtUtc;
  final String customerName;

  factory PaymentItem.fromJson(Map<String, dynamic> json) {
    return PaymentItem(
      id: json['id'] as int? ?? 0,
      reservationId: json['reservationId'] as int? ?? 0,
      reservationCode: json['reservationCode'] as String? ?? '',
      flightNumber: json['flightNumber'] as String? ?? '',
      routeCode: json['routeCode'] as String? ?? '',
      provider: json['provider'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      currency: json['currency'] as String? ?? 'BAM',
      status: PaymentStatusValue.fromValue(json['status'] as int? ?? 1),
      isPaid: json['isPaid'] as bool? ?? false,
      createdAtUtc: DateTime.parse(json['createdAtUtc'] as String),
      paidAtUtc: json['paidAtUtc'] == null
          ? null
          : DateTime.parse(json['paidAtUtc'] as String),
      refundedAtUtc: json['refundedAtUtc'] == null
          ? null
          : DateTime.parse(json['refundedAtUtc'] as String),
      customerName: json['customerName'] as String? ?? '',
    );
  }
}

class PaymentDetails {
  PaymentDetails({
    required this.id,
    required this.reservationId,
    required this.reservationCode,
    required this.flightNumber,
    required this.routeCode,
    required this.provider,
    required this.providerReference,
    required this.approvalUrl,
    required this.amount,
    required this.currency,
    required this.status,
    required this.isPaid,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    required this.paidAtUtc,
    required this.refundedAtUtc,
    required this.statusReason,
    required this.canBeConfirmed,
    required this.canBeRefunded,
    required this.customer,
  });

  final int id;
  final int reservationId;
  final String reservationCode;
  final String flightNumber;
  final String routeCode;
  final String provider;
  final String? providerReference;
  final String? approvalUrl;
  final double amount;
  final String currency;
  final PaymentStatusValue status;
  final bool isPaid;
  final DateTime createdAtUtc;
  final DateTime? updatedAtUtc;
  final DateTime? paidAtUtc;
  final DateTime? refundedAtUtc;
  final String? statusReason;
  final bool canBeConfirmed;
  final bool canBeRefunded;
  final PaymentCustomer customer;

  factory PaymentDetails.fromJson(Map<String, dynamic> json) {
    return PaymentDetails(
      id: json['id'] as int? ?? 0,
      reservationId: json['reservationId'] as int? ?? 0,
      reservationCode: json['reservationCode'] as String? ?? '',
      flightNumber: json['flightNumber'] as String? ?? '',
      routeCode: json['routeCode'] as String? ?? '',
      provider: json['provider'] as String? ?? '',
      providerReference: json['providerReference'] as String?,
      approvalUrl: json['approvalUrl'] as String?,
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      currency: json['currency'] as String? ?? 'BAM',
      status: PaymentStatusValue.fromValue(json['status'] as int? ?? 1),
      isPaid: json['isPaid'] as bool? ?? false,
      createdAtUtc: DateTime.parse(json['createdAtUtc'] as String),
      updatedAtUtc: json['updatedAtUtc'] == null
          ? null
          : DateTime.parse(json['updatedAtUtc'] as String),
      paidAtUtc: json['paidAtUtc'] == null
          ? null
          : DateTime.parse(json['paidAtUtc'] as String),
      refundedAtUtc: json['refundedAtUtc'] == null
          ? null
          : DateTime.parse(json['refundedAtUtc'] as String),
      statusReason: json['statusReason'] as String?,
      canBeConfirmed: json['canBeConfirmed'] as bool? ?? false,
      canBeRefunded: json['canBeRefunded'] as bool? ?? false,
      customer: PaymentCustomer.fromJson(
        json['customer'] as Map<String, dynamic>? ?? const {},
      ),
    );
  }
}

class PaymentCustomer {
  PaymentCustomer({
    required this.userId,
    required this.username,
    required this.fullName,
    required this.email,
  });

  final String userId;
  final String username;
  final String fullName;
  final String email;

  factory PaymentCustomer.fromJson(Map<String, dynamic> json) {
    return PaymentCustomer(
      userId: json['userId'] as String? ?? '',
      username: json['username'] as String? ?? '',
      fullName: json['fullName'] as String? ?? '',
      email: json['email'] as String? ?? '',
    );
  }
}

class PayPalDebugSnapshot {
  PayPalDebugSnapshot({
    required this.paymentId,
    required this.reservationId,
    required this.reservationCode,
    required this.flightNumber,
    required this.storedProviderReference,
    required this.callbackToken,
    required this.callbackTokenMatchesStoredReference,
    required this.paymentStatus,
    required this.reservationStatus,
    required this.payPalResourceType,
    required this.payPalOrderId,
    required this.payPalOrderStatus,
    required this.approvalUrl,
    required this.debugNote,
    required this.links,
    required this.captures,
  });

  final int paymentId;
  final int reservationId;
  final String reservationCode;
  final String flightNumber;
  final String storedProviderReference;
  final String? callbackToken;
  final bool callbackTokenMatchesStoredReference;
  final PaymentStatusValue paymentStatus;
  final ReservationStatusValue reservationStatus;
  final String payPalResourceType;
  final String payPalOrderId;
  final String payPalOrderStatus;
  final String? approvalUrl;
  final String? debugNote;
  final List<PayPalDebugLink> links;
  final List<PayPalDebugCapture> captures;

  factory PayPalDebugSnapshot.fromJson(Map<String, dynamic> json) {
    return PayPalDebugSnapshot(
      paymentId: json['paymentId'] as int? ?? 0,
      reservationId: json['reservationId'] as int? ?? 0,
      reservationCode: json['reservationCode'] as String? ?? '',
      flightNumber: json['flightNumber'] as String? ?? '',
      storedProviderReference: json['storedProviderReference'] as String? ?? '',
      callbackToken: json['callbackToken'] as String?,
      callbackTokenMatchesStoredReference:
          json['callbackTokenMatchesStoredReference'] as bool? ?? false,
      paymentStatus: PaymentStatusValue.fromValue(
        json['paymentStatus'] as int? ?? 1,
      ),
      reservationStatus: ReservationStatusValue.fromValue(
        json['reservationStatus'] as int? ?? 1,
      ),
      payPalResourceType: json['payPalResourceType'] as String? ?? 'Order',
      payPalOrderId: json['payPalOrderId'] as String? ?? '',
      payPalOrderStatus: json['payPalOrderStatus'] as String? ?? '',
      approvalUrl: json['approvalUrl'] as String?,
      debugNote: json['debugNote'] as String?,
      links: (json['links'] as List<dynamic>? ?? const [])
          .map((item) => PayPalDebugLink.fromJson(item as Map<String, dynamic>))
          .toList(),
      captures: (json['captures'] as List<dynamic>? ?? const [])
          .map(
            (item) => PayPalDebugCapture.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}

class PayPalDebugLink {
  PayPalDebugLink({
    required this.rel,
    required this.method,
    required this.href,
  });

  final String rel;
  final String method;
  final String href;

  factory PayPalDebugLink.fromJson(Map<String, dynamic> json) {
    return PayPalDebugLink(
      rel: json['rel'] as String? ?? '',
      method: json['method'] as String? ?? '',
      href: json['href'] as String? ?? '',
    );
  }
}

class PayPalDebugCapture {
  PayPalDebugCapture({
    required this.id,
    required this.status,
    required this.amount,
    required this.currency,
    required this.createTimeUtc,
  });

  final String id;
  final String status;
  final double amount;
  final String currency;
  final DateTime? createTimeUtc;

  factory PayPalDebugCapture.fromJson(Map<String, dynamic> json) {
    return PayPalDebugCapture(
      id: json['id'] as String? ?? '',
      status: json['status'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      currency: json['currency'] as String? ?? '',
      createTimeUtc: json['createTimeUtc'] == null
          ? null
          : DateTime.parse(json['createTimeUtc'] as String),
    );
  }
}

enum PaymentStatusValue {
  pending(1, 'Pending'),
  paid(2, 'Paid'),
  failed(3, 'Failed'),
  refunded(4, 'Refunded');

  const PaymentStatusValue(this.value, this.label);

  final int value;
  final String label;

  static PaymentStatusValue fromValue(int value) {
    return PaymentStatusValue.values.firstWhere(
      (item) => item.value == value,
      orElse: () => PaymentStatusValue.pending,
    );
  }
}

enum ReservationStatusValue {
  pending(1, 'Pending'),
  confirmed(2, 'Confirmed'),
  cancelled(3, 'Cancelled'),
  completed(4, 'Completed');

  const ReservationStatusValue(this.value, this.label);

  final int value;
  final String label;

  static ReservationStatusValue fromValue(int value) {
    return ReservationStatusValue.values.firstWhere(
      (item) => item.value == value,
      orElse: () => ReservationStatusValue.pending,
    );
  }
}
