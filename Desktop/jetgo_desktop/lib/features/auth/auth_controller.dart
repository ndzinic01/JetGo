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
      final session = await _authService.login(
        username: username.trim(),
        password: password,
      );

      if (!session.user.isAdmin) {
        _errorMessage =
            'Ovaj desktop klijent je namijenjen samo administratorima.';
        _session = null;
        return false;
      }

      _session = session;
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

  void updateCurrentUser({
    required String firstName,
    required String lastName,
    required String email,
    String? phoneNumber,
  }) {
    final session = _session;
    if (session == null) {
      return;
    }

    _session = session.copyWith(
      user: session.user.copyWith(
        firstName: firstName,
        lastName: lastName,
        email: email,
        phoneNumber: phoneNumber,
      ),
    );

    notifyListeners();
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
