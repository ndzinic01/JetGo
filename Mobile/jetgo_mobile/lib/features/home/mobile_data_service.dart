import '../../core/network/api_client.dart';
import 'mobile_models.dart';

class MobileDataService {
  MobileDataService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<PagedResult<MobileFlight>> fetchFlights({
    required String token,
    String? searchText,
  }) async {
    final response = await _apiClient.getJson(
      '/api/Flights',
      token: token,
      queryParameters: <String, String>{
        'page': '1',
        'pageSize': '20',
        if (searchText != null && searchText.trim().isNotEmpty)
          'searchText': searchText.trim(),
      },
    );

    return _mapPagedResult(response, MobileFlight.fromJson);
  }

  Future<MobileFlightDetails> fetchFlightDetails({
    required String token,
    required int flightId,
  }) async {
    final response = await _apiClient.getJson(
      '/api/Flights/$flightId',
      token: token,
    );

    return MobileFlightDetails.fromJson(response);
  }

  Future<PagedResult<MobileReservation>> fetchMyReservations({
    required String token,
  }) async {
    final response = await _apiClient.getJson(
      '/api/Reservations/my',
      token: token,
      queryParameters: const <String, String>{
        'page': '1',
        'pageSize': '20',
      },
    );

    return _mapPagedResult(response, MobileReservation.fromJson);
  }

  Future<MobileReservationDetails> fetchReservationDetails({
    required String token,
    required int reservationId,
  }) async {
    final response = await _apiClient.getJson(
      '/api/Reservations/$reservationId',
      token: token,
    );

    return MobileReservationDetails.fromJson(response);
  }

  Future<MobileReservationDetails> createReservation({
    required String token,
    required int flightId,
    required List<String> seatNumbers,
  }) async {
    final response = await _apiClient.postJson(
      '/api/Reservations',
      token: token,
      body: <String, dynamic>{
        'flightId': flightId,
        'seatNumbers': seatNumbers,
      },
    );

    return MobileReservationDetails.fromJson(response);
  }

  Future<PagedResult<NewsArticleSummary>> fetchNews({
    required String token,
  }) async {
    final response = await _apiClient.getJson(
      '/api/News',
      token: token,
      queryParameters: const <String, String>{
        'page': '1',
        'pageSize': '20',
      },
    );

    return _mapPagedResult(response, NewsArticleSummary.fromJson);
  }

  Future<MobileProfile> fetchMyProfile({
    required String token,
  }) async {
    final response = await _apiClient.getJson(
      '/api/Profile/me',
      token: token,
    );

    return MobileProfile.fromJson(response);
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
