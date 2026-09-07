import 'package:flutter/foundation.dart';

import '../../core/network/api_exception.dart';
import '../../core/network/api_client.dart';
import 'auth_models.dart';
import 'auth_service.dart';

class AuthController extends ChangeNotifier {
  AuthController(this._authService) {
    ApiClient.onUnauthorized = _handleUnauthorized;
  }

  final AuthService _authService;

  AuthSession? _session;
  bool _isLoading = false;
  String? _errorMessage;

  AuthSession? get session => _session;
  bool get isAuthenticated => _session != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<bool> login({
    required String username,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _session = await _authService.login(
        username: username.trim(),
        password: password,
      );
      return true;
    } on ApiException catch (error) {
      _errorMessage = error.message;
      return false;
    } catch (_) {
      _errorMessage = 'Prijava trenutno nije dostupna. Pokusajte ponovo.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> register({
    required String username,
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    required String confirmPassword,
    String? phoneNumber,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final phone = phoneNumber?.trim();
      _session = await _authService.register(
        username: username.trim(),
        firstName: firstName.trim(),
        lastName: lastName.trim(),
        email: email.trim(),
        phoneNumber: phone == null || phone.isEmpty ? null : phone,
        password: password,
        confirmPassword: confirmPassword,
      );
      return true;
    } on ApiException catch (error) {
      _errorMessage = error.message;
      return false;
    } catch (_) {
      _errorMessage = 'Registracija trenutno nije dostupna. Pokusajte ponovo.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<PasswordResetRequestResult?> requestPasswordReset({
    required String email,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      return await _authService.requestPasswordReset(email: email.trim());
    } on ApiException catch (error) {
      _errorMessage = error.message;
      return null;
    } catch (_) {
      _errorMessage = 'Reset lozinke trenutno nije dostupan. Pokusajte ponovo.';
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> resetPassword({
    required String email,
    required String token,
    required String newPassword,
    required String confirmPassword,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _authService.resetPassword(
        email: email.trim(),
        token: token.trim(),
        newPassword: newPassword,
        confirmPassword: confirmPassword,
      );
      return true;
    } on ApiException catch (error) {
      _errorMessage = error.message;
      return false;
    } catch (_) {
      _errorMessage = 'Reset lozinke trenutno nije dostupan. Pokusajte ponovo.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    final token = _session?.accessToken;

    try {
      if (token != null && token.isNotEmpty) {
        await _authService.logout(token: token);
      }
    } catch (_) {
      // Local logout must still happen if the server cannot be reached.
    } finally {
      _clearSession();
    }
  }

  void _handleUnauthorized() {
    if (_session == null) {
      return;
    }

    _clearSession(
      message: 'Sesija je istekla ili vise nije vazeca. Prijavite se ponovo.',
    );
  }

  void _clearSession({String? message}) {
    _session = null;
    _errorMessage = message;
    notifyListeners();
  }

  @override
  void dispose() {
    ApiClient.onUnauthorized = null;
    super.dispose();
  }
}
