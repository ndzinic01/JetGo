import 'package:flutter/foundation.dart';

import '../../core/network/api_exception.dart';
import 'auth_models.dart';
import 'auth_service.dart';

class AuthController extends ChangeNotifier {
  AuthController(this._authService);

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

  void logout() {
    _session = null;
    _errorMessage = null;
    notifyListeners();
  }
}
