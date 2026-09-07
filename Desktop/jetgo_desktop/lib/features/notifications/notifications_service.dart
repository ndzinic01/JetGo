import '../../core/network/api_client.dart';
import '../reference_data/reference_data_models.dart';
import 'notifications_models.dart';

class NotificationsService {
  NotificationsService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<PagedResult<AdminNotificationItem>> fetchNotifications({
    required String token,
    String? searchText,
    String? flightNumber,
    NotificationStatusValue? status,
    NotificationTypeValue? type,
    DateTime? createdFromUtc,
    DateTime? createdToUtc,
    int page = 1,
    int pageSize = 100,
  }) async {
    final response = await _apiClient.getJson(
      '/api/Notifications/admin',
      token: token,
      queryParameters: <String, String>{
        'page': page.toString(),
        'pageSize': pageSize.toString(),
        if (searchText != null && searchText.trim().isNotEmpty)
          'searchText': searchText.trim(),
        if (flightNumber != null && flightNumber.trim().isNotEmpty)
          'flightNumber': flightNumber.trim().toUpperCase(),
        if (status != null) 'status': status.value.toString(),
        if (type != null) 'type': type.value.toString(),
        if (createdFromUtc != null)
          'createdFromUtc': createdFromUtc.toUtc().toIso8601String(),
        if (createdToUtc != null)
          'createdToUtc': createdToUtc.toUtc().toIso8601String(),
      },
    );

    return _mapPagedResult(response, AdminNotificationItem.fromJson);
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
