import '../reference_data/reference_data_models.dart';
import '../../core/network/api_client.dart';
import 'reservations_models.dart';

class ReservationsService {
  ReservationsService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<PagedResult<ReservationItem>> fetchReservations({
    required String token,
    String? searchText,
    int? flightId,
    ReservationStatusValue? status,
    int pageSize = 100,
  }) async {
    final response = await _apiClient.getJson(
      '/api/Reservations',
      token: token,
      queryParameters: <String, String>{
        'page': '1',
        'pageSize': pageSize.toString(),
        if (searchText != null && searchText.trim().isNotEmpty)
          'searchText': searchText.trim(),
        if (flightId != null) 'flightId': flightId.toString(),
        if (status != null) 'status': status.value.toString(),
      },
    );

    return _mapPagedResult(response, ReservationItem.fromJson);
  }

  Future<ReservationDetails> getReservation({
    required String token,
    required int id,
  }) async {
    final response = await _apiClient.getJson(
      '/api/Reservations/$id',
      token: token,
    );

    return ReservationDetails.fromJson(response);
  }

  Future<ReservationDetails> cancelReservation({
    required String token,
    required int id,
    String? reason,
  }) async {
    final response = await _apiClient.postJson(
      '/api/Reservations/$id/cancel',
      token: token,
      body: <String, dynamic>{
        'reason': _normalizeReason(reason),
      },
    );

    return ReservationDetails.fromJson(response);
  }

  Future<ReservationDetails> completeReservation({
    required String token,
    required int id,
    String? reason,
  }) async {
    final response = await _apiClient.postJson(
      '/api/Reservations/$id/complete',
      token: token,
      body: <String, dynamic>{
        'reason': _normalizeReason(reason),
      },
    );

    return ReservationDetails.fromJson(response);
  }

  String? _normalizeReason(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }

    return trimmed;
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
