import '../../core/network/api_client.dart';
import 'auth_models.dart';

class AuthService {
  AuthService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<AuthSession> login({
    required String username,
    required String password,
  }) async {
    final response = await _apiClient.postJson(
      '/api/Auth/login',
      body: <String, dynamic>{
        'username': username,
        'password': password,
      },
    );

    return AuthSession.fromJson(response);
  }

  Future<AuthSession> register({
    required String username,
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    required String confirmPassword,
    String? phoneNumber,
  }) async {
    final response = await _apiClient.postJson(
      '/api/Auth/register',
      body: <String, dynamic>{
        'username': username,
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'phoneNumber': phoneNumber,
        'password': password,
        'confirmPassword': confirmPassword,
      },
    );

    return AuthSession.fromJson(response);
  }

  Future<PasswordResetRequestResult> requestPasswordReset({
    required String email,
  }) async {
    final response = await _apiClient.postJson(
      '/api/Auth/request-password-reset',
      body: <String, dynamic>{
        'email': email,
      },
    );

    return PasswordResetRequestResult.fromJson(response);
  }

  Future<void> resetPassword({
    required String email,
    required String token,
    required String newPassword,
    required String confirmPassword,
  }) async {
    await _apiClient.postJson(
      '/api/Auth/reset-password',
      body: <String, dynamic>{
        'email': email,
        'token': token,
        'newPassword': newPassword,
        'confirmPassword': confirmPassword,
      },
    );
  }
}
