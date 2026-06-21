class PagedResult<T> {
  PagedResult({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.totalCount,
    required this.totalPages,
    required this.hasPreviousPage,
    required this.hasNextPage,
  });

  final List<T> items;
  final int page;
  final int pageSize;
  final int totalCount;
  final int totalPages;
  final bool hasPreviousPage;
  final bool hasNextPage;
}

class AirlineSummary {
  AirlineSummary({
    required this.id,
    required this.name,
    required this.code,
    this.logoUrl,
  });

  final int id;
  final String name;
  final String code;
  final String? logoUrl;

  factory AirlineSummary.fromJson(Map<String, dynamic> json) {
    return AirlineSummary(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      code: json['code'] as String? ?? '',
      logoUrl: json['logoUrl'] as String?,
    );
  }
}

class AirportSummary {
  AirportSummary({
    required this.id,
    required this.name,
    required this.iataCode,
    required this.cityName,
    required this.countryName,
  });

  final int id;
  final String name;
  final String iataCode;
  final String cityName;
  final String countryName;

  factory AirportSummary.fromJson(Map<String, dynamic> json) {
    return AirportSummary(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      iataCode: json['iataCode'] as String? ?? '',
      cityName: json['cityName'] as String? ?? '',
      countryName: json['countryName'] as String? ?? '',
    );
  }
}

class MobileFlight {
  MobileFlight({
    required this.id,
    required this.flightNumber,
    required this.routeCode,
    required this.airline,
    required this.departureAirport,
    required this.arrivalAirport,
    required this.departureAtUtc,
    required this.arrivalAtUtc,
    required this.durationMinutes,
    required this.basePrice,
    required this.currency,
    required this.availableSeats,
    required this.totalSeats,
    required this.status,
  });

  final int id;
  final String flightNumber;
  final String routeCode;
  final AirlineSummary airline;
  final AirportSummary departureAirport;
  final AirportSummary arrivalAirport;
  final DateTime departureAtUtc;
  final DateTime arrivalAtUtc;
  final int durationMinutes;
  final double basePrice;
  final String currency;
  final int availableSeats;
  final int totalSeats;
  final int status;

  factory MobileFlight.fromJson(Map<String, dynamic> json) {
    return MobileFlight(
      id: json['id'] as int? ?? 0,
      flightNumber: json['flightNumber'] as String? ?? '',
      routeCode: json['routeCode'] as String? ?? '',
      airline: AirlineSummary.fromJson(
        json['airline'] as Map<String, dynamic>? ?? const <String, dynamic>{},
      ),
      departureAirport: AirportSummary.fromJson(
        json['departureAirport'] as Map<String, dynamic>? ??
            const <String, dynamic>{},
      ),
      arrivalAirport: AirportSummary.fromJson(
        json['arrivalAirport'] as Map<String, dynamic>? ??
            const <String, dynamic>{},
      ),
      departureAtUtc: DateTime.parse(json['departureAtUtc'] as String),
      arrivalAtUtc: DateTime.parse(json['arrivalAtUtc'] as String),
      durationMinutes: json['durationMinutes'] as int? ?? 0,
      basePrice: (json['basePrice'] as num?)?.toDouble() ?? 0,
      currency: json['currency'] as String? ?? '',
      availableSeats: json['availableSeats'] as int? ?? 0,
      totalSeats: json['totalSeats'] as int? ?? 0,
      status: json['status'] as int? ?? 0,
    );
  }
}

class MobileFlightDetails {
  MobileFlightDetails({
    required this.id,
    required this.destinationId,
    required this.flightNumber,
    required this.routeCode,
    required this.airline,
    required this.departureAirport,
    required this.arrivalAirport,
    required this.departureAtUtc,
    required this.arrivalAtUtc,
    required this.durationMinutes,
    required this.basePrice,
    required this.currency,
    required this.availableSeats,
    required this.totalSeats,
    required this.reservedSeats,
    required this.status,
    required this.availableSeatNumbers,
  });

  final int id;
  final int destinationId;
  final String flightNumber;
  final String routeCode;
  final AirlineSummary airline;
  final AirportSummary departureAirport;
  final AirportSummary arrivalAirport;
  final DateTime departureAtUtc;
  final DateTime arrivalAtUtc;
  final int durationMinutes;
  final double basePrice;
  final String currency;
  final int availableSeats;
  final int totalSeats;
  final int reservedSeats;
  final int status;
  final List<String> availableSeatNumbers;

  factory MobileFlightDetails.fromJson(Map<String, dynamic> json) {
    return MobileFlightDetails(
      id: json['id'] as int? ?? 0,
      destinationId: json['destinationId'] as int? ?? 0,
      flightNumber: json['flightNumber'] as String? ?? '',
      routeCode: json['routeCode'] as String? ?? '',
      airline: AirlineSummary.fromJson(
        json['airline'] as Map<String, dynamic>? ?? const <String, dynamic>{},
      ),
      departureAirport: AirportSummary.fromJson(
        json['departureAirport'] as Map<String, dynamic>? ??
            const <String, dynamic>{},
      ),
      arrivalAirport: AirportSummary.fromJson(
        json['arrivalAirport'] as Map<String, dynamic>? ??
            const <String, dynamic>{},
      ),
      departureAtUtc: DateTime.parse(json['departureAtUtc'] as String),
      arrivalAtUtc: DateTime.parse(json['arrivalAtUtc'] as String),
      durationMinutes: json['durationMinutes'] as int? ?? 0,
      basePrice: (json['basePrice'] as num?)?.toDouble() ?? 0,
      currency: json['currency'] as String? ?? '',
      availableSeats: json['availableSeats'] as int? ?? 0,
      totalSeats: json['totalSeats'] as int? ?? 0,
      reservedSeats: json['reservedSeats'] as int? ?? 0,
      status: json['status'] as int? ?? 0,
      availableSeatNumbers:
          ((json['availableSeatNumbers'] as List<dynamic>?) ?? const [])
              .map((item) => item.toString())
              .toList(),
    );
  }
}

class MobileReservation {
  MobileReservation({
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
    required this.isPaid,
    required this.seatsCount,
    required this.createdAtUtc,
    this.paymentId,
    this.paymentStatus,
    this.customerName,
  });

  final int id;
  final String reservationCode;
  final int flightId;
  final String flightNumber;
  final String routeCode;
  final String departureAirportCode;
  final String arrivalAirportCode;
  final DateTime departureAtUtc;
  final int status;
  final double totalAmount;
  final String currency;
  final int? paymentId;
  final int? paymentStatus;
  final bool isPaid;
  final int seatsCount;
  final DateTime createdAtUtc;
  final String? customerName;

  factory MobileReservation.fromJson(Map<String, dynamic> json) {
    return MobileReservation(
      id: json['id'] as int? ?? 0,
      reservationCode: json['reservationCode'] as String? ?? '',
      flightId: json['flightId'] as int? ?? 0,
      flightNumber: json['flightNumber'] as String? ?? '',
      routeCode: json['routeCode'] as String? ?? '',
      departureAirportCode: json['departureAirportCode'] as String? ?? '',
      arrivalAirportCode: json['arrivalAirportCode'] as String? ?? '',
      departureAtUtc: DateTime.parse(json['departureAtUtc'] as String),
      status: json['status'] as int? ?? 0,
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0,
      currency: json['currency'] as String? ?? '',
      paymentId: json['paymentId'] as int?,
      paymentStatus: json['paymentStatus'] as int?,
      isPaid: json['isPaid'] as bool? ?? false,
      seatsCount: json['seatsCount'] as int? ?? 0,
      createdAtUtc: DateTime.parse(json['createdAtUtc'] as String),
      customerName: json['customerName'] as String?,
    );
  }
}

class MobileReservationCustomer {
  MobileReservationCustomer({
    required this.userId,
    required this.username,
    required this.fullName,
    required this.email,
  });

  final String userId;
  final String username;
  final String fullName;
  final String email;

  factory MobileReservationCustomer.fromJson(Map<String, dynamic> json) {
    return MobileReservationCustomer(
      userId: json['userId'] as String? ?? '',
      username: json['username'] as String? ?? '',
      fullName: json['fullName'] as String? ?? '',
      email: json['email'] as String? ?? '',
    );
  }
}

class MobileReservationSeat {
  MobileReservationSeat({
    required this.flightSeatId,
    required this.seatNumber,
    required this.price,
  });

  final int flightSeatId;
  final String seatNumber;
  final double price;

  factory MobileReservationSeat.fromJson(Map<String, dynamic> json) {
    return MobileReservationSeat(
      flightSeatId: json['flightSeatId'] as int? ?? 0,
      seatNumber: json['seatNumber'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0,
    );
  }
}

class MobileReservationDetails {
  MobileReservationDetails({
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
    required this.isPaid,
    required this.createdAtUtc,
    required this.customer,
    required this.seats,
    required this.canBeCancelled,
    required this.canBeConfirmed,
    required this.canBeCompleted,
    required this.canInitiatePayment,
    required this.canBeRefunded,
    this.paymentId,
    this.paymentStatus,
    this.statusChangedAtUtc,
    this.statusChangedByUserId,
    this.statusReason,
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
  final int status;
  final double totalAmount;
  final String currency;
  final int? paymentId;
  final int? paymentStatus;
  final bool isPaid;
  final DateTime createdAtUtc;
  final DateTime? statusChangedAtUtc;
  final String? statusChangedByUserId;
  final String? statusReason;
  final MobileReservationCustomer customer;
  final List<MobileReservationSeat> seats;
  final bool canBeCancelled;
  final bool canBeConfirmed;
  final bool canBeCompleted;
  final bool canInitiatePayment;
  final bool canBeRefunded;

  factory MobileReservationDetails.fromJson(Map<String, dynamic> json) {
    return MobileReservationDetails(
      id: json['id'] as int? ?? 0,
      reservationCode: json['reservationCode'] as String? ?? '',
      flightId: json['flightId'] as int? ?? 0,
      flightNumber: json['flightNumber'] as String? ?? '',
      routeCode: json['routeCode'] as String? ?? '',
      departureAirportCode: json['departureAirportCode'] as String? ?? '',
      arrivalAirportCode: json['arrivalAirportCode'] as String? ?? '',
      departureAtUtc: DateTime.parse(json['departureAtUtc'] as String),
      arrivalAtUtc: DateTime.parse(json['arrivalAtUtc'] as String),
      status: json['status'] as int? ?? 0,
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0,
      currency: json['currency'] as String? ?? '',
      paymentId: json['paymentId'] as int?,
      paymentStatus: json['paymentStatus'] as int?,
      isPaid: json['isPaid'] as bool? ?? false,
      createdAtUtc: DateTime.parse(json['createdAtUtc'] as String),
      statusChangedAtUtc: json['statusChangedAtUtc'] == null
          ? null
          : DateTime.parse(json['statusChangedAtUtc'] as String),
      statusChangedByUserId: json['statusChangedByUserId'] as String?,
      statusReason: json['statusReason'] as String?,
      customer: MobileReservationCustomer.fromJson(
        json['customer'] as Map<String, dynamic>? ?? const <String, dynamic>{},
      ),
      seats: ((json['seats'] as List<dynamic>?) ?? const [])
          .map((item) => MobileReservationSeat.fromJson(item as Map<String, dynamic>))
          .toList(),
      canBeCancelled: json['canBeCancelled'] as bool? ?? false,
      canBeConfirmed: json['canBeConfirmed'] as bool? ?? false,
      canBeCompleted: json['canBeCompleted'] as bool? ?? false,
      canInitiatePayment: json['canInitiatePayment'] as bool? ?? false,
      canBeRefunded: json['canBeRefunded'] as bool? ?? false,
    );
  }
}

class NewsArticleSummary {
  NewsArticleSummary({
    required this.id,
    required this.title,
    required this.isPublished,
    required this.publishedAtUtc,
    this.imageUrl,
  });

  final int id;
  final String title;
  final String? imageUrl;
  final bool isPublished;
  final DateTime publishedAtUtc;

  factory NewsArticleSummary.fromJson(Map<String, dynamic> json) {
    return NewsArticleSummary(
      id: json['id'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      imageUrl: json['imageUrl'] as String?,
      isPublished: json['isPublished'] as bool? ?? false,
      publishedAtUtc: DateTime.parse(json['publishedAtUtc'] as String),
    );
  }
}

class MobileProfile {
  MobileProfile({
    required this.userId,
    required this.username,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.roles,
    this.phoneNumber,
    this.imageUrl,
  });

  final String userId;
  final String username;
  final String firstName;
  final String lastName;
  final String email;
  final String? phoneNumber;
  final String? imageUrl;
  final List<String> roles;

  String get fullName {
    final value = '$firstName $lastName'.trim();
    return value.isEmpty ? username : value;
  }

  factory MobileProfile.fromJson(Map<String, dynamic> json) {
    return MobileProfile(
      userId: json['userId'] as String? ?? '',
      username: json['username'] as String? ?? '',
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phoneNumber: json['phoneNumber'] as String?,
      imageUrl: json['imageUrl'] as String?,
      roles: ((json['roles'] as List<dynamic>?) ?? const [])
          .map((role) => role.toString())
          .toList(),
    );
  }
}

class MobileNotification {
  MobileNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.status,
    required this.createdAtUtc,
    this.readAtUtc,
  });

  final int id;
  final String title;
  final String body;
  final int status;
  final DateTime createdAtUtc;
  final DateTime? readAtUtc;

  bool get isUnread => status == 1;

  factory MobileNotification.fromJson(Map<String, dynamic> json) {
    return MobileNotification(
      id: json['id'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      status: json['status'] as int? ?? 0,
      createdAtUtc: DateTime.parse(json['createdAtUtc'] as String),
      readAtUtc: json['readAtUtc'] == null
          ? null
          : DateTime.parse(json['readAtUtc'] as String),
    );
  }
}

class MobileNotificationSummary {
  MobileNotificationSummary({
    required this.totalCount,
    required this.unreadCount,
    this.latestCreatedAtUtc,
  });

  final int totalCount;
  final int unreadCount;
  final DateTime? latestCreatedAtUtc;

  factory MobileNotificationSummary.fromJson(Map<String, dynamic> json) {
    return MobileNotificationSummary(
      totalCount: json['totalCount'] as int? ?? 0,
      unreadCount: json['unreadCount'] as int? ?? 0,
      latestCreatedAtUtc: json['latestCreatedAtUtc'] == null
          ? null
          : DateTime.parse(json['latestCreatedAtUtc'] as String),
    );
  }
}

class MobileSupportMessageSummary {
  MobileSupportMessageSummary({
    required this.id,
    required this.subject,
    required this.messagePreview,
    required this.isReplied,
    required this.createdAtUtc,
    required this.customerName,
    required this.customerEmail,
    this.repliedAtUtc,
  });

  final int id;
  final String subject;
  final String messagePreview;
  final bool isReplied;
  final DateTime createdAtUtc;
  final DateTime? repliedAtUtc;
  final String customerName;
  final String customerEmail;

  factory MobileSupportMessageSummary.fromJson(Map<String, dynamic> json) {
    return MobileSupportMessageSummary(
      id: json['id'] as int? ?? 0,
      subject: json['subject'] as String? ?? '',
      messagePreview: json['messagePreview'] as String? ?? '',
      isReplied: json['isReplied'] as bool? ?? false,
      createdAtUtc: DateTime.parse(json['createdAtUtc'] as String),
      repliedAtUtc: json['repliedAtUtc'] == null
          ? null
          : DateTime.parse(json['repliedAtUtc'] as String),
      customerName: json['customerName'] as String? ?? '',
      customerEmail: json['customerEmail'] as String? ?? '',
    );
  }
}

class MobileSupportMessageCustomer {
  MobileSupportMessageCustomer({
    required this.userId,
    required this.username,
    required this.fullName,
    required this.email,
  });

  final String userId;
  final String username;
  final String fullName;
  final String email;

  factory MobileSupportMessageCustomer.fromJson(Map<String, dynamic> json) {
    return MobileSupportMessageCustomer(
      userId: json['userId'] as String? ?? '',
      username: json['username'] as String? ?? '',
      fullName: json['fullName'] as String? ?? '',
      email: json['email'] as String? ?? '',
    );
  }
}

class MobileSupportMessageDetails {
  MobileSupportMessageDetails({
    required this.id,
    required this.subject,
    required this.message,
    required this.isReplied,
    required this.createdAtUtc,
    required this.customer,
    this.adminReply,
    this.updatedAtUtc,
    this.repliedAtUtc,
  });

  final int id;
  final String subject;
  final String message;
  final String? adminReply;
  final bool isReplied;
  final DateTime createdAtUtc;
  final DateTime? updatedAtUtc;
  final DateTime? repliedAtUtc;
  final MobileSupportMessageCustomer customer;

  factory MobileSupportMessageDetails.fromJson(Map<String, dynamic> json) {
    return MobileSupportMessageDetails(
      id: json['id'] as int? ?? 0,
      subject: json['subject'] as String? ?? '',
      message: json['message'] as String? ?? '',
      adminReply: json['adminReply'] as String?,
      isReplied: json['isReplied'] as bool? ?? false,
      createdAtUtc: DateTime.parse(json['createdAtUtc'] as String),
      updatedAtUtc: json['updatedAtUtc'] == null
          ? null
          : DateTime.parse(json['updatedAtUtc'] as String),
      repliedAtUtc: json['repliedAtUtc'] == null
          ? null
          : DateTime.parse(json['repliedAtUtc'] as String),
      customer: MobileSupportMessageCustomer.fromJson(
        json['customer'] as Map<String, dynamic>? ?? const <String, dynamic>{},
      ),
    );
  }
}
