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

class CountryItem {
  CountryItem({
    required this.id,
    required this.name,
    required this.isoCode,
    required this.citiesCount,
  });

  final int id;
  final String name;
  final String isoCode;
  final int citiesCount;

  factory CountryItem.fromJson(Map<String, dynamic> json) {
    return CountryItem(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      isoCode: json['isoCode'] as String? ?? '',
      citiesCount: json['citiesCount'] as int? ?? 0,
    );
  }
}

class CountryDetails {
  CountryDetails({
    required this.id,
    required this.name,
    required this.isoCode,
    required this.citiesCount,
    required this.createdAtUtc,
    this.updatedAtUtc,
  });

  final int id;
  final String name;
  final String isoCode;
  final int citiesCount;
  final DateTime createdAtUtc;
  final DateTime? updatedAtUtc;

  factory CountryDetails.fromJson(Map<String, dynamic> json) {
    return CountryDetails(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      isoCode: json['isoCode'] as String? ?? '',
      citiesCount: json['citiesCount'] as int? ?? 0,
      createdAtUtc: DateTime.parse(json['createdAtUtc'] as String),
      updatedAtUtc: json['updatedAtUtc'] == null
          ? null
          : DateTime.parse(json['updatedAtUtc'] as String),
    );
  }
}

class CityItem {
  CityItem({
    required this.id,
    required this.name,
    required this.countryId,
    required this.countryName,
    required this.countryIsoCode,
    required this.airportsCount,
  });

  final int id;
  final String name;
  final int countryId;
  final String countryName;
  final String countryIsoCode;
  final int airportsCount;

  factory CityItem.fromJson(Map<String, dynamic> json) {
    return CityItem(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      countryId: json['countryId'] as int? ?? 0,
      countryName: json['countryName'] as String? ?? '',
      countryIsoCode: json['countryIsoCode'] as String? ?? '',
      airportsCount: json['airportsCount'] as int? ?? 0,
    );
  }
}

class CityDetails {
  CityDetails({
    required this.id,
    required this.name,
    required this.countryId,
    required this.countryName,
    required this.countryIsoCode,
    required this.airportsCount,
    required this.createdAtUtc,
    this.updatedAtUtc,
  });

  final int id;
  final String name;
  final int countryId;
  final String countryName;
  final String countryIsoCode;
  final int airportsCount;
  final DateTime createdAtUtc;
  final DateTime? updatedAtUtc;

  factory CityDetails.fromJson(Map<String, dynamic> json) {
    return CityDetails(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      countryId: json['countryId'] as int? ?? 0,
      countryName: json['countryName'] as String? ?? '',
      countryIsoCode: json['countryIsoCode'] as String? ?? '',
      airportsCount: json['airportsCount'] as int? ?? 0,
      createdAtUtc: DateTime.parse(json['createdAtUtc'] as String),
      updatedAtUtc: json['updatedAtUtc'] == null
          ? null
          : DateTime.parse(json['updatedAtUtc'] as String),
    );
  }
}

class AirportItem {
  AirportItem({
    required this.id,
    required this.name,
    required this.iataCode,
    required this.cityId,
    required this.cityName,
    required this.countryId,
    required this.countryName,
    required this.relatedDestinationsCount,
    this.latitude,
    this.longitude,
  });

  final int id;
  final String name;
  final String iataCode;
  final int cityId;
  final String cityName;
  final int countryId;
  final String countryName;
  final double? latitude;
  final double? longitude;
  final int relatedDestinationsCount;

  factory AirportItem.fromJson(Map<String, dynamic> json) {
    return AirportItem(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      iataCode: json['iataCode'] as String? ?? '',
      cityId: json['cityId'] as int? ?? 0,
      cityName: json['cityName'] as String? ?? '',
      countryId: json['countryId'] as int? ?? 0,
      countryName: json['countryName'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      relatedDestinationsCount: json['relatedDestinationsCount'] as int? ?? 0,
    );
  }
}

class AirportDetails {
  AirportDetails({
    required this.id,
    required this.name,
    required this.iataCode,
    required this.cityId,
    required this.cityName,
    required this.countryId,
    required this.countryName,
    required this.departureDestinationsCount,
    required this.arrivalDestinationsCount,
    required this.createdAtUtc,
    this.latitude,
    this.longitude,
    this.updatedAtUtc,
  });

  final int id;
  final String name;
  final String iataCode;
  final int cityId;
  final String cityName;
  final int countryId;
  final String countryName;
  final double? latitude;
  final double? longitude;
  final int departureDestinationsCount;
  final int arrivalDestinationsCount;
  final DateTime createdAtUtc;
  final DateTime? updatedAtUtc;

  factory AirportDetails.fromJson(Map<String, dynamic> json) {
    return AirportDetails(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      iataCode: json['iataCode'] as String? ?? '',
      cityId: json['cityId'] as int? ?? 0,
      cityName: json['cityName'] as String? ?? '',
      countryId: json['countryId'] as int? ?? 0,
      countryName: json['countryName'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      departureDestinationsCount:
          json['departureDestinationsCount'] as int? ?? 0,
      arrivalDestinationsCount: json['arrivalDestinationsCount'] as int? ?? 0,
      createdAtUtc: DateTime.parse(json['createdAtUtc'] as String),
      updatedAtUtc: json['updatedAtUtc'] == null
          ? null
          : DateTime.parse(json['updatedAtUtc'] as String),
    );
  }
}

class AirlineItem {
  AirlineItem({
    required this.id,
    required this.name,
    required this.code,
    required this.isActive,
    required this.flightsCount,
    this.logoUrl,
  });

  final int id;
  final String name;
  final String code;
  final String? logoUrl;
  final bool isActive;
  final int flightsCount;

  factory AirlineItem.fromJson(Map<String, dynamic> json) {
    return AirlineItem(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      code: json['code'] as String? ?? '',
      logoUrl: json['logoUrl'] as String?,
      isActive: json['isActive'] as bool? ?? false,
      flightsCount: json['flightsCount'] as int? ?? 0,
    );
  }
}

class AirlineDetails {
  AirlineDetails({
    required this.id,
    required this.name,
    required this.code,
    required this.isActive,
    required this.flightsCount,
    required this.createdAtUtc,
    this.logoUrl,
    this.updatedAtUtc,
  });

  final int id;
  final String name;
  final String code;
  final String? logoUrl;
  final bool isActive;
  final int flightsCount;
  final DateTime createdAtUtc;
  final DateTime? updatedAtUtc;

  factory AirlineDetails.fromJson(Map<String, dynamic> json) {
    return AirlineDetails(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      code: json['code'] as String? ?? '',
      logoUrl: json['logoUrl'] as String?,
      isActive: json['isActive'] as bool? ?? false,
      flightsCount: json['flightsCount'] as int? ?? 0,
      createdAtUtc: DateTime.parse(json['createdAtUtc'] as String),
      updatedAtUtc: json['updatedAtUtc'] == null
          ? null
          : DateTime.parse(json['updatedAtUtc'] as String),
    );
  }
}
