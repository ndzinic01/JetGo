class ReservationItem {
  ReservationItem({
    required this.id,
    required this.reservationCode,
    required this.flightId,
    required this.flightNumber,
    required this.routeCode,
    required this.departureAirportCode,
    required this.arrivalAirportCode,
    required this.departureAtUtc,
    required this.status,
    required this.totalAmount,
    required this.currency,
    required this.paymentId,
    required this.paymentStatus,
    required this.isPaid,
    required this.seatsCount,
    required this.additionalBaggageCount,
    required this.createdAtUtc,
    required this.customerName,
  });

  final int id;
  final String reservationCode;
  final int flightId;
  final String flightNumber;
  final String routeCode;
  final String departureAirportCode;
  final String arrivalAirportCode;
  final DateTime departureAtUtc;
  final ReservationStatusValue status;
  final double totalAmount;
  final String currency;
  final int? paymentId;
  final PaymentStatusValue? paymentStatus;
  final bool isPaid;
  final int seatsCount;
  final int additionalBaggageCount;
  final DateTime createdAtUtc;
  final String customerName;

  factory ReservationItem.fromJson(Map<String, dynamic> json) {
    return ReservationItem(
      id: json['id'] as int? ?? 0,
      reservationCode: json['reservationCode'] as String? ?? '',
      flightId: json['flightId'] as int? ?? 0,
      flightNumber: json['flightNumber'] as String? ?? '',
      routeCode: json['routeCode'] as String? ?? '',
      departureAirportCode: json['departureAirportCode'] as String? ?? '',
      arrivalAirportCode: json['arrivalAirportCode'] as String? ?? '',
      departureAtUtc: DateTime.parse(json['departureAtUtc'] as String),
      status: ReservationStatusValue.fromValue(json['status'] as int? ?? 1),
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0,
      currency: json['currency'] as String? ?? 'BAM',
      paymentId: json['paymentId'] as int?,
      paymentStatus: json['paymentStatus'] == null
          ? null
          : PaymentStatusValue.fromValue(json['paymentStatus'] as int),
      isPaid: json['isPaid'] as bool? ?? false,
      seatsCount: json['seatsCount'] as int? ?? 0,
      additionalBaggageCount: json['additionalBaggageCount'] as int? ?? 0,
      createdAtUtc: DateTime.parse(json['createdAtUtc'] as String),
      customerName: json['customerName'] as String? ?? '',
    );
  }
}

class ReservationDetails {
  ReservationDetails({
    required this.id,
    required this.reservationCode,
    required this.flightId,
    required this.flightNumber,
    required this.routeCode,
    required this.departureAirportCode,
    required this.arrivalAirportCode,
    required this.departureAtUtc,
    required this.arrivalAtUtc,
    required this.status,
    required this.totalAmount,
    required this.currency,
    required this.seatsTotalAmount,
    required this.additionalBaggageCount,
    required this.additionalBaggageUnitPrice,
    required this.additionalBaggageTotalAmount,
    required this.paymentId,
    required this.paymentStatus,
    required this.isPaid,
    required this.hasCapturedPayment,
    required this.createdAtUtc,
    required this.statusChangedAtUtc,
    required this.statusChangedByUserId,
    required this.statusReason,
    required this.customer,
    required this.seats,
    required this.passengers,
    required this.canBeCancelled,
    required this.canBeConfirmed,
    required this.canBeCompleted,
    required this.canInitiatePayment,
    required this.canBeRefunded,
    required this.canUpdateBaggage,
    required this.canChangeReservation,
  });

  final int id;
  final String reservationCode;
  final int flightId;
  final String flightNumber;
  final String routeCode;
  final String departureAirportCode;
  final String arrivalAirportCode;
  final DateTime departureAtUtc;
  final DateTime arrivalAtUtc;
  final ReservationStatusValue status;
  final double totalAmount;
  final String currency;
  final double seatsTotalAmount;
  final int additionalBaggageCount;
  final double additionalBaggageUnitPrice;
  final double additionalBaggageTotalAmount;
  final int? paymentId;
  final PaymentStatusValue? paymentStatus;
  final bool isPaid;
  final bool hasCapturedPayment;
  final DateTime createdAtUtc;
  final DateTime? statusChangedAtUtc;
  final String? statusChangedByUserId;
  final String? statusReason;
  final ReservationCustomer customer;
  final List<ReservationSeat> seats;
  final List<ReservationPassenger> passengers;
  final bool canBeCancelled;
  final bool canBeConfirmed;
  final bool canBeCompleted;
  final bool canInitiatePayment;
  final bool canBeRefunded;
  final bool canUpdateBaggage;
  final bool canChangeReservation;

  factory ReservationDetails.fromJson(Map<String, dynamic> json) {
    return ReservationDetails(
      id: json['id'] as int? ?? 0,
      reservationCode: json['reservationCode'] as String? ?? '',
      flightId: json['flightId'] as int? ?? 0,
      flightNumber: json['flightNumber'] as String? ?? '',
      routeCode: json['routeCode'] as String? ?? '',
      departureAirportCode: json['departureAirportCode'] as String? ?? '',
      arrivalAirportCode: json['arrivalAirportCode'] as String? ?? '',
      departureAtUtc: DateTime.parse(json['departureAtUtc'] as String),
      arrivalAtUtc: DateTime.parse(json['arrivalAtUtc'] as String),
      status: ReservationStatusValue.fromValue(json['status'] as int? ?? 1),
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0,
      currency: json['currency'] as String? ?? 'BAM',
      seatsTotalAmount: (json['seatsTotalAmount'] as num?)?.toDouble() ?? 0,
      additionalBaggageCount: json['additionalBaggageCount'] as int? ?? 0,
      additionalBaggageUnitPrice:
          (json['additionalBaggageUnitPrice'] as num?)?.toDouble() ?? 0,
      additionalBaggageTotalAmount:
          (json['additionalBaggageTotalAmount'] as num?)?.toDouble() ?? 0,
      paymentId: json['paymentId'] as int?,
      paymentStatus: json['paymentStatus'] == null
          ? null
          : PaymentStatusValue.fromValue(json['paymentStatus'] as int),
      isPaid: json['isPaid'] as bool? ?? false,
      hasCapturedPayment: json['hasCapturedPayment'] as bool? ?? false,
      createdAtUtc: DateTime.parse(json['createdAtUtc'] as String),
      statusChangedAtUtc: json['statusChangedAtUtc'] == null
          ? null
          : DateTime.parse(json['statusChangedAtUtc'] as String),
      statusChangedByUserId: json['statusChangedByUserId'] as String?,
      statusReason: json['statusReason'] as String?,
      customer: ReservationCustomer.fromJson(
        json['customer'] as Map<String, dynamic>? ?? const {},
      ),
      seats: (json['seats'] as List<dynamic>? ?? const [])
          .map((item) => ReservationSeat.fromJson(item as Map<String, dynamic>))
          .toList(),
      passengers: (json['passengers'] as List<dynamic>? ?? const [])
          .map(
            (item) =>
                ReservationPassenger.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
      canBeCancelled: json['canBeCancelled'] as bool? ?? false,
      canBeConfirmed: json['canBeConfirmed'] as bool? ?? false,
      canBeCompleted: json['canBeCompleted'] as bool? ?? false,
      canInitiatePayment: json['canInitiatePayment'] as bool? ?? false,
      canBeRefunded: json['canBeRefunded'] as bool? ?? false,
      canUpdateBaggage: json['canUpdateBaggage'] as bool? ?? false,
      canChangeReservation: json['canChangeReservation'] as bool? ?? false,
    );
  }
}

class ReservationCustomer {
  ReservationCustomer({
    required this.userId,
    required this.username,
    required this.fullName,
    required this.email,
  });

  final String userId;
  final String username;
  final String fullName;
  final String email;

  factory ReservationCustomer.fromJson(Map<String, dynamic> json) {
    return ReservationCustomer(
      userId: json['userId'] as String? ?? '',
      username: json['username'] as String? ?? '',
      fullName: json['fullName'] as String? ?? '',
      email: json['email'] as String? ?? '',
    );
  }
}

class ReservationSeat {
  ReservationSeat({
    required this.flightSeatId,
    required this.seatNumber,
    required this.price,
  });

  final int flightSeatId;
  final String seatNumber;
  final double price;

  factory ReservationSeat.fromJson(Map<String, dynamic> json) {
    return ReservationSeat(
      flightSeatId: json['flightSeatId'] as int? ?? 0,
      seatNumber: json['seatNumber'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0,
    );
  }
}

class ReservationPassenger {
  ReservationPassenger({
    required this.seatNumber,
    required this.firstName,
    required this.lastName,
    required this.gender,
    required this.passportNumber,
  });

  final String seatNumber;
  final String firstName;
  final String lastName;
  final int gender;
  final String passportNumber;

  String get fullName => '$firstName $lastName'.trim();

  factory ReservationPassenger.fromJson(Map<String, dynamic> json) {
    return ReservationPassenger(
      seatNumber: json['seatNumber'] as String? ?? '',
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
      gender: json['gender'] as int? ?? 3,
      passportNumber: json['passportNumber'] as String? ?? '',
    );
  }
}

enum ReservationStatusValue {
  pending(1, 'Na cekanju'),
  confirmed(2, 'Potvrdjeno'),
  cancelled(3, 'Otkazano'),
  completed(4, 'Zavrseno');

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

enum PaymentStatusValue {
  pending(1, 'Na cekanju'),
  paid(2, 'Placeno'),
  failed(3, 'Neuspjelo'),
  refunded(4, 'Refundirano');

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
