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

class DestinationItem {
  DestinationItem({
    required this.id,
    required this.routeCode,
    required this.isActive,
    required this.departureAirport,
    required this.arrivalAirport,
    required this.upcomingFlightsCount,
    required this.lowestBasePrice,
    required this.nextDepartureAtUtc,
  });

  final int id;
  final String routeCode;
  final bool isActive;
  final AirportSummary departureAirport;
  final AirportSummary arrivalAirport;
  final int upcomingFlightsCount;
  final double? lowestBasePrice;
  final DateTime? nextDepartureAtUtc;

  factory DestinationItem.fromJson(Map<String, dynamic> json) {
    return DestinationItem(
      id: json['id'] as int? ?? 0,
      routeCode: json['routeCode'] as String? ?? '',
      isActive: json['isActive'] as bool? ?? false,
      departureAirport: AirportSummary.fromJson(
        json['departureAirport'] as Map<String, dynamic>? ?? const {},
      ),
      arrivalAirport: AirportSummary.fromJson(
        json['arrivalAirport'] as Map<String, dynamic>? ?? const {},
      ),
      upcomingFlightsCount: json['upcomingFlightsCount'] as int? ?? 0,
      lowestBasePrice: (json['lowestBasePrice'] as num?)?.toDouble(),
      nextDepartureAtUtc: json['nextDepartureAtUtc'] == null
          ? null
          : DateTime.parse(json['nextDepartureAtUtc'] as String),
    );
  }
}

class DestinationDetails {
  DestinationDetails({
    required this.id,
    required this.routeCode,
    required this.isActive,
    required this.departureAirport,
    required this.arrivalAirport,
    required this.totalFlightsCount,
    required this.upcomingFlightsCount,
    required this.lowestBasePrice,
    required this.nextDepartureAtUtc,
  });

  final int id;
  final String routeCode;
  final bool isActive;
  final AirportSummary departureAirport;
  final AirportSummary arrivalAirport;
  final int totalFlightsCount;
  final int upcomingFlightsCount;
  final double? lowestBasePrice;
  final DateTime? nextDepartureAtUtc;

  factory DestinationDetails.fromJson(Map<String, dynamic> json) {
    return DestinationDetails(
      id: json['id'] as int? ?? 0,
      routeCode: json['routeCode'] as String? ?? '',
      isActive: json['isActive'] as bool? ?? false,
      departureAirport: AirportSummary.fromJson(
        json['departureAirport'] as Map<String, dynamic>? ?? const {},
      ),
      arrivalAirport: AirportSummary.fromJson(
        json['arrivalAirport'] as Map<String, dynamic>? ?? const {},
      ),
      totalFlightsCount: json['totalFlightsCount'] as int? ?? 0,
      upcomingFlightsCount: json['upcomingFlightsCount'] as int? ?? 0,
      lowestBasePrice: (json['lowestBasePrice'] as num?)?.toDouble(),
      nextDepartureAtUtc: json['nextDepartureAtUtc'] == null
          ? null
          : DateTime.parse(json['nextDepartureAtUtc'] as String),
    );
  }
}

class FlightItem {
  FlightItem({
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
  final FlightStatusValue status;

  factory FlightItem.fromJson(Map<String, dynamic> json) {
    return FlightItem(
      id: json['id'] as int? ?? 0,
      flightNumber: json['flightNumber'] as String? ?? '',
      routeCode: json['routeCode'] as String? ?? '',
      airline: AirlineSummary.fromJson(
        json['airline'] as Map<String, dynamic>? ?? const {},
      ),
      departureAirport: AirportSummary.fromJson(
        json['departureAirport'] as Map<String, dynamic>? ?? const {},
      ),
      arrivalAirport: AirportSummary.fromJson(
        json['arrivalAirport'] as Map<String, dynamic>? ?? const {},
      ),
      departureAtUtc: DateTime.parse(json['departureAtUtc'] as String),
      arrivalAtUtc: DateTime.parse(json['arrivalAtUtc'] as String),
      durationMinutes: json['durationMinutes'] as int? ?? 0,
      basePrice: (json['basePrice'] as num?)?.toDouble() ?? 0,
      currency: json['currency'] as String? ?? 'BAM',
      availableSeats: json['availableSeats'] as int? ?? 0,
      totalSeats: json['totalSeats'] as int? ?? 0,
      status: FlightStatusValue.fromValue(json['status'] as int? ?? 1),
    );
  }
}

class FlightDetails {
  FlightDetails({
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
  final FlightStatusValue status;
  final List<String> availableSeatNumbers;

  factory FlightDetails.fromJson(Map<String, dynamic> json) {
    return FlightDetails(
      id: json['id'] as int? ?? 0,
      destinationId: json['destinationId'] as int? ?? 0,
      flightNumber: json['flightNumber'] as String? ?? '',
      routeCode: json['routeCode'] as String? ?? '',
      airline: AirlineSummary.fromJson(
        json['airline'] as Map<String, dynamic>? ?? const {},
      ),
      departureAirport: AirportSummary.fromJson(
        json['departureAirport'] as Map<String, dynamic>? ?? const {},
      ),
      arrivalAirport: AirportSummary.fromJson(
        json['arrivalAirport'] as Map<String, dynamic>? ?? const {},
      ),
      departureAtUtc: DateTime.parse(json['departureAtUtc'] as String),
      arrivalAtUtc: DateTime.parse(json['arrivalAtUtc'] as String),
      durationMinutes: json['durationMinutes'] as int? ?? 0,
      basePrice: (json['basePrice'] as num?)?.toDouble() ?? 0,
      currency: json['currency'] as String? ?? 'BAM',
      availableSeats: json['availableSeats'] as int? ?? 0,
      totalSeats: json['totalSeats'] as int? ?? 0,
      reservedSeats: json['reservedSeats'] as int? ?? 0,
      status: FlightStatusValue.fromValue(json['status'] as int? ?? 1),
      availableSeatNumbers:
          (json['availableSeatNumbers'] as List<dynamic>? ?? const [])
              .map((item) => item as String)
              .toList(),
    );
  }
}

enum FlightStatusValue {
  scheduled(1, 'Scheduled'),
  delayed(2, 'Delayed'),
  cancelled(3, 'Cancelled'),
  completed(4, 'Completed');

  const FlightStatusValue(this.value, this.label);

  final int value;
  final String label;

  static FlightStatusValue fromValue(int value) {
    return FlightStatusValue.values.firstWhere(
      (item) => item.value == value,
      orElse: () => FlightStatusValue.scheduled,
    );
  }
}
