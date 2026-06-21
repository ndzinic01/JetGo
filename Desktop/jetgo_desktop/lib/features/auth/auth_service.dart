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
}
