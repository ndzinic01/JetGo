import '../../core/network/api_client.dart';
import '../reference_data/reference_data_models.dart';
import 'support_models.dart';

class SupportService {
  SupportService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<PagedResult<SupportMessageItem>> fetchMessages({
    required String token,
    String? searchText,
    bool? isReplied,
    int pageSize = 100,
  }) async {
    final response = await _apiClient.getJson(
      '/api/SupportMessages',
      token: token,
      queryParameters: <String, String>{
        'page': '1',
        'pageSize': pageSize.toString(),
        if (searchText != null && searchText.trim().isNotEmpty)
          'searchText': searchText.trim(),
        if (isReplied != null) 'isReplied': isReplied.toString(),
      },
    );

    return _mapPagedResult(response, SupportMessageItem.fromJson);
  }

  Future<SupportMessageDetails> getMessage({
    required String token,
    required int id,
  }) async {
    final response = await _apiClient.getJson(
      '/api/SupportMessages/$id',
      token: token,
    );

    return SupportMessageDetails.fromJson(response);
  }

  Future<SupportMessageDetails> replyToMessage({
    required String token,
    required int id,
    required String adminReply,
  }) async {
    final response = await _apiClient.postJson(
      '/api/SupportMessages/$id/reply',
      token: token,
      body: <String, dynamic>{
        'adminReply': adminReply.trim(),
      },
    );

    return SupportMessageDetails.fromJson(response);
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
