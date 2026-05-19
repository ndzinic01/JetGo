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
