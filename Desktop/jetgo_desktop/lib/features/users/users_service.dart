import '../../core/network/api_client.dart';
import '../reference_data/reference_data_models.dart';
import 'users_models.dart';

class UsersService {
  UsersService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<PagedResult<AdminUserItem>> fetchUsers({
    required String token,
    String? searchText,
    String? roleName,
    bool? isActive,
    int pageSize = 100,
  }) async {
    final response = await _apiClient.getJson(
      '/api/admin/users',
      token: token,
      queryParameters: <String, String>{
        'page': '1',
        'pageSize': pageSize.toString(),
        if (searchText != null && searchText.trim().isNotEmpty)
          'searchText': searchText.trim(),
        if (roleName != null && roleName.trim().isNotEmpty)
          'roleName': roleName.trim(),
        if (isActive != null) 'isActive': isActive.toString(),
      },
    );

    return _mapPagedResult(response, AdminUserItem.fromJson);
  }

  Future<AdminUserDetails> getUser({
    required String token,
    required String userId,
  }) async {
    final response = await _apiClient.getJson(
      '/api/admin/users/$userId',
      token: token,
    );

    return AdminUserDetails.fromJson(response);
  }

  Future<AdminUserDetails> updateUser({
    required String token,
    required String userId,
    required String firstName,
    required String lastName,
    required String email,
    String? phoneNumber,
    String? imageUrl,
    required List<String> roles,
  }) async {
    final response = await _apiClient.putJson(
      '/api/admin/users/$userId',
      token: token,
      body: <String, dynamic>{
        'firstName': firstName.trim(),
        'lastName': lastName.trim(),
        'email': email.trim(),
        'phoneNumber': _normalizeNullable(phoneNumber),
        'imageUrl': _normalizeNullable(imageUrl),
        'roles': roles,
      },
    );

    return AdminUserDetails.fromJson(response);
  }

  Future<AdminUserDetails> updateActivation({
    required String token,
    required String userId,
    required bool isActive,
  }) async {
    final response = await _apiClient.postJson(
      '/api/admin/users/$userId/activation',
      token: token,
      body: <String, dynamic>{'isActive': isActive},
    );

    return AdminUserDetails.fromJson(response);
  }

  Future<void> resetPassword({
    required String token,
    required String userId,
    required String newPassword,
    required String confirmPassword,
  }) async {
    await _apiClient.postJson(
      '/api/admin/users/$userId/reset-password',
      token: token,
      body: <String, dynamic>{
        'newPassword': newPassword,
        'confirmPassword': confirmPassword,
      },
    );
  }

  String? _normalizeNullable(String? value) {
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
