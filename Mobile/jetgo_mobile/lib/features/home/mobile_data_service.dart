import '../../core/network/api_client.dart';
import 'mobile_models.dart';

class MobileDataService {
  MobileDataService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<PagedResult<MobileFlight>> fetchFlights({
    required String token,
    int page = 1,
    int pageSize = 20,
    String? searchText,
    String? departureSearchText,
    String? arrivalSearchText,
    String? airlineCode,
    DateTime? departureFromUtc,
    DateTime? departureToUtc,
  }) async {
    final query = _pagedQuery(page: page, pageSize: pageSize);
    _addTrimmedQuery(query, 'searchText', searchText);
    _addTrimmedQuery(query, 'departureSearchText', departureSearchText);
    _addTrimmedQuery(query, 'arrivalSearchText', arrivalSearchText);
    _addTrimmedQuery(query, 'airlineCode', airlineCode);
    _addDateTimeQuery(query, 'departureFromUtc', departureFromUtc);
    _addDateTimeQuery(query, 'departureToUtc', departureToUtc);

    final response = await _apiClient.getJson(
      '/api/Flights',
      token: token,
      queryParameters: query,
    );

    return _mapPagedResult(response, MobileFlight.fromJson);
  }

  Future<PagedResult<MobileRecommendedFlight>> fetchRecommendedFlights({
    required String token,
    int page = 1,
    int pageSize = 5,
  }) async {
    final response = await _apiClient.getJson(
      '/api/Recommendations/flights',
      token: token,
      queryParameters: _pagedQuery(page: page, pageSize: pageSize),
    );

    return _mapPagedResult(response, MobileRecommendedFlight.fromJson);
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
    int page = 1,
    int pageSize = 20,
  }) async {
    final response = await _apiClient.getJson(
      '/api/Reservations/my',
      token: token,
      queryParameters: _pagedQuery(page: page, pageSize: pageSize),
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
    required int additionalBaggageCount,
    required List<MobileReservationPassengerInput> passengers,
  }) async {
    final response = await _apiClient.postJson(
      '/api/Reservations',
      token: token,
      body: <String, dynamic>{
        'flightId': flightId,
        'seatNumbers': seatNumbers,
        'additionalBaggageCount': additionalBaggageCount,
        'passengers': passengers.map((item) => item.toJson()).toList(),
      },
    );

    return MobileReservationDetails.fromJson(response);
  }

  Future<MobileReservationDetails> updateReservationBaggage({
    required String token,
    required int reservationId,
    required int additionalBaggageCount,
  }) async {
    final response = await _apiClient.putJson(
      '/api/Reservations/$reservationId/baggage',
      token: token,
      body: <String, dynamic>{'additionalBaggageCount': additionalBaggageCount},
    );

    return MobileReservationDetails.fromJson(response);
  }

  Future<MobileReservationDetails> cancelReservation({
    required String token,
    required int reservationId,
    required String reason,
  }) async {
    final response = await _apiClient.postJson(
      '/api/Reservations/$reservationId/cancel',
      token: token,
      body: <String, dynamic>{'reason': reason.trim()},
    );

    return MobileReservationDetails.fromJson(response);
  }

  Future<MobilePaymentDetails> initializePayment({
    required String token,
    required int reservationId,
  }) async {
    final response = await _apiClient.postJson(
      '/api/Payments/reservations/$reservationId/initialize',
      token: token,
    );

    return MobilePaymentDetails.fromJson(response);
  }

  Future<MobilePaymentDetails> confirmPayment({
    required String token,
    required int paymentId,
  }) async {
    final response = await _apiClient.postJson(
      '/api/Payments/$paymentId/confirm',
      token: token,
      body: const <String, dynamic>{},
    );

    return MobilePaymentDetails.fromJson(response);
  }

  Future<PagedResult<NewsArticleSummary>> fetchNews({
    required String token,
    int page = 1,
    int pageSize = 20,
  }) async {
    final response = await _apiClient.getJson(
      '/api/News',
      token: token,
      queryParameters: _pagedQuery(page: page, pageSize: pageSize),
    );

    return _mapPagedResult(response, NewsArticleSummary.fromJson);
  }

  Future<MobileNotificationSummary> fetchNotificationSummary({
    required String token,
  }) async {
    final response = await _apiClient.getJson(
      '/api/Notifications/summary',
      token: token,
    );

    return MobileNotificationSummary.fromJson(response);
  }

  Future<PagedResult<MobileNotification>> fetchNotifications({
    required String token,
    int page = 1,
    int pageSize = 50,
  }) async {
    final response = await _apiClient.getJson(
      '/api/Notifications',
      token: token,
      queryParameters: _pagedQuery(page: page, pageSize: pageSize),
    );

    return _mapPagedResult(response, MobileNotification.fromJson);
  }

  Future<void> markNotificationAsRead({
    required String token,
    required int notificationId,
  }) async {
    await _apiClient.postJson(
      '/api/Notifications/$notificationId/read',
      token: token,
    );
  }

  Future<void> markAllNotificationsAsRead({required String token}) async {
    await _apiClient.postJson('/api/Notifications/read-all', token: token);
  }

  Future<PagedResult<MobileSupportMessageSummary>> fetchSupportMessages({
    required String token,
    int page = 1,
    int pageSize = 50,
  }) async {
    final response = await _apiClient.getJson(
      '/api/SupportMessages/my',
      token: token,
      queryParameters: _pagedQuery(page: page, pageSize: pageSize),
    );

    return _mapPagedResult(response, MobileSupportMessageSummary.fromJson);
  }

  Future<MobileSupportMessageDetails> fetchSupportMessageDetails({
    required String token,
    required int supportMessageId,
  }) async {
    final response = await _apiClient.getJson(
      '/api/SupportMessages/$supportMessageId',
      token: token,
    );

    return MobileSupportMessageDetails.fromJson(response);
  }

  Future<MobileSupportMessageDetails> createSupportMessage({
    required String token,
    required String subject,
    required String message,
  }) async {
    final response = await _apiClient.postJson(
      '/api/SupportMessages',
      token: token,
      body: <String, dynamic>{
        'subject': subject.trim(),
        'message': message.trim(),
      },
    );

    return MobileSupportMessageDetails.fromJson(response);
  }

  Future<MobileProfile> fetchMyProfile({required String token}) async {
    final response = await _apiClient.getJson('/api/Profile/me', token: token);

    return MobileProfile.fromJson(response);
  }

  Future<MobileProfile> updateMyProfile({
    required String token,
    required String firstName,
    required String lastName,
    required String email,
    String? phoneNumber,
    String? imageUrl,
  }) async {
    final response = await _apiClient.putJson(
      '/api/Profile/me',
      token: token,
      body: <String, dynamic>{
        'firstName': firstName.trim(),
        'lastName': lastName.trim(),
        'email': email.trim(),
        'phoneNumber': phoneNumber?.trim(),
        'imageUrl': imageUrl?.trim(),
      },
    );

    return MobileProfile.fromJson(response);
  }

  Future<void> changePassword({
    required String token,
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    await _apiClient.postJson(
      '/api/Profile/change-password',
      token: token,
      body: <String, dynamic>{
        'currentPassword': currentPassword,
        'newPassword': newPassword,
        'confirmPassword': confirmPassword,
      },
    );
  }

  Map<String, String> _pagedQuery({required int page, required int pageSize}) {
    return <String, String>{
      'page': page.toString(),
      'pageSize': pageSize.toString(),
    };
  }

  void _addTrimmedQuery(Map<String, String> query, String key, String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return;
    }

    query[key] = trimmed;
  }

  void _addDateTimeQuery(
    Map<String, String> query,
    String key,
    DateTime? value,
  ) {
    if (value == null) {
      return;
    }

    query[key] = value.toUtc().toIso8601String();
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
