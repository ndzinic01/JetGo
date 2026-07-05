import '../../core/network/api_client.dart';
import 'profile_models.dart';

class ProfileService {
  ProfileService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<AdminProfile> fetchMyProfile({
    required String token,
  }) async {
    final response = await _apiClient.getJson(
      '/api/Profile/me',
      token: token,
    );

    return AdminProfile.fromJson(response);
  }

  Future<AdminProfile> updateMyProfile({
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
      body: {
        'firstName': firstName.trim(),
        'lastName': lastName.trim(),
        'email': email.trim(),
        'phoneNumber': phoneNumber?.trim(),
        'imageUrl': imageUrl?.trim(),
      },
    );

    return AdminProfile.fromJson(response);
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
      body: {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
        'confirmPassword': confirmPassword,
      },
    );
  }
}
