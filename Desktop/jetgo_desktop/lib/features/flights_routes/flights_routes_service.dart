import '../reference_data/reference_data_models.dart';
import '../../core/network/api_client.dart';
import 'flights_routes_models.dart';

class FlightsRoutesService {
  FlightsRoutesService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<PagedResult<DestinationItem>> fetchDestinations({
    required String token,
    String? searchText,
    int? departureAirportId,
    int? arrivalAirportId,
    bool? isActive,
    int pageSize = 100,
  }) async {
    final response = await _apiClient.getJson(
      '/api/admin/destinations',
      token: token,
      queryParameters: <String, String>{
        'page': '1',
        'pageSize': pageSize.toString(),
        if (searchText != null && searchText.trim().isNotEmpty)
          'searchText': searchText.trim(),
        if (departureAirportId != null)
          'departureAirportId': departureAirportId.toString(),
        if (arrivalAirportId != null)
          'arrivalAirportId': arrivalAirportId.toString(),
        if (isActive != null) 'isActive': isActive.toString(),
      },
    );

    return _mapPagedResult(response, DestinationItem.fromJson);
  }

  Future<DestinationDetails> getDestination({
    required String token,
    required int id,
  }) async {
    final response = await _apiClient.getJson(
      '/api/admin/destinations/$id',
      token: token,
    );

    return DestinationDetails.fromJson(response);
  }

  Future<DestinationDetails> createDestination({
    required String token,
    required int departureAirportId,
    required int arrivalAirportId,
    required bool isActive,
  }) async {
    final response = await _apiClient.postJson(
      '/api/admin/destinations',
      token: token,
      body: <String, dynamic>{
        'departureAirportId': departureAirportId,
        'arrivalAirportId': arrivalAirportId,
        'isActive': isActive,
      },
    );

    return DestinationDetails.fromJson(response);
  }

  Future<DestinationDetails> updateDestination({
    required String token,
    required int id,
    required int departureAirportId,
    required int arrivalAirportId,
    required bool isActive,
  }) async {
    final response = await _apiClient.putJson(
      '/api/admin/destinations/$id',
      token: token,
      body: <String, dynamic>{
        'departureAirportId': departureAirportId,
        'arrivalAirportId': arrivalAirportId,
        'isActive': isActive,
      },
    );

    return DestinationDetails.fromJson(response);
  }

  Future<void> deleteDestination({
    required String token,
    required int id,
  }) async {
    await _apiClient.delete(
      '/api/admin/destinations/$id',
      token: token,
    );
  }

  Future<PagedResult<FlightItem>> fetchFlights({
    required String token,
    String? searchText,
    int? departureAirportId,
    int? arrivalAirportId,
    int? airlineId,
    FlightStatusValue? status,
    int pageSize = 100,
  }) async {
    final response = await _apiClient.getJson(
      '/api/admin/flights',
      token: token,
      queryParameters: <String, String>{
        'page': '1',
        'pageSize': pageSize.toString(),
        if (searchText != null && searchText.trim().isNotEmpty)
          'searchText': searchText.trim(),
        if (departureAirportId != null)
          'departureAirportId': departureAirportId.toString(),
        if (arrivalAirportId != null)
          'arrivalAirportId': arrivalAirportId.toString(),
        if (airlineId != null) 'airlineId': airlineId.toString(),
        if (status != null) 'status': status.value.toString(),
      },
    );

    return _mapPagedResult(response, FlightItem.fromJson);
  }

  Future<FlightDetails> getFlight({
    required String token,
    required int id,
  }) async {
    final response = await _apiClient.getJson(
      '/api/admin/flights/$id',
      token: token,
    );

    return FlightDetails.fromJson(response);
  }

  Future<FlightDetails> createFlight({
    required String token,
    required int airlineId,
    required int destinationId,
    required String flightNumber,
    required DateTime departureAtUtc,
    required DateTime arrivalAtUtc,
    required double basePrice,
    required int totalSeats,
    required FlightStatusValue status,
  }) async {
    final response = await _apiClient.postJson(
      '/api/admin/flights',
      token: token,
      body: <String, dynamic>{
        'airlineId': airlineId,
        'destinationId': destinationId,
        'flightNumber': flightNumber.trim(),
        'departureAtUtc': departureAtUtc.toUtc().toIso8601String(),
        'arrivalAtUtc': arrivalAtUtc.toUtc().toIso8601String(),
        'basePrice': basePrice,
        'totalSeats': totalSeats,
        'status': status.value,
      },
    );

    return FlightDetails.fromJson(response);
  }

  Future<FlightDetails> updateFlight({
    required String token,
    required int id,
    required int airlineId,
    required int destinationId,
    required String flightNumber,
    required DateTime departureAtUtc,
    required DateTime arrivalAtUtc,
    required double basePrice,
    required int totalSeats,
    required FlightStatusValue status,
  }) async {
    final response = await _apiClient.putJson(
      '/api/admin/flights/$id',
      token: token,
      body: <String, dynamic>{
        'airlineId': airlineId,
        'destinationId': destinationId,
        'flightNumber': flightNumber.trim(),
        'departureAtUtc': departureAtUtc.toUtc().toIso8601String(),
        'arrivalAtUtc': arrivalAtUtc.toUtc().toIso8601String(),
        'basePrice': basePrice,
        'totalSeats': totalSeats,
        'status': status.value,
      },
    );

    return FlightDetails.fromJson(response);
  }

  Future<void> deleteFlight({
    required String token,
    required int id,
  }) async {
    await _apiClient.delete(
      '/api/admin/flights/$id',
      token: token,
    );
  }

  PagedResult<T> _mapPagedResult<T>(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final rawItems = (json['items'] as List<dynamic>? ?? const []);

    return PagedResult<T>(
      items: rawItems
          .map((item) => fromJson(item as Map<String, dynamic>))
          .toList(),
      page: json['page'] as int? ?? 1,
      pageSize: json['pageSize'] as int? ?? rawItems.length,
      totalCount: json['totalCount'] as int? ?? rawItems.length,
      totalPages: json['totalPages'] as int? ?? 1,
      hasPreviousPage: json['hasPreviousPage'] as bool? ?? false,
      hasNextPage: json['hasNextPage'] as bool? ?? false,
    );
  }
}
