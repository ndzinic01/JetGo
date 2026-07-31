import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../features/auth/auth_controller.dart';
import '../features/auth/auth_service.dart';
import '../features/auth/login_screen.dart';
import '../features/home/home_screen.dart';
import '../features/home/reservation_details_screen.dart';

class JetGoMobileApp extends StatefulWidget {
  const JetGoMobileApp({super.key});

  @override
  State<JetGoMobileApp> createState() => _JetGoMobileAppState();
}

class _JetGoMobileAppState extends State<JetGoMobileApp> {
  late final AuthController _authController;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  late final AppLinks _appLinks;

  StreamSubscription<Uri>? _deepLinkSubscription;
  _PendingPayPalLink? _pendingPayPalLink;
  String? _lastHandledPayPalLink;

  @override
  void initState() {
    super.initState();
    _authController = AuthController(AuthService());
    _authController.addListener(_handleAuthStateChanged);
    _appLinks = AppLinks();
    unawaited(_initializeDeepLinks());
  }

  @override
  void dispose() {
    _deepLinkSubscription?.cancel();
    _authController.removeListener(_handleAuthStateChanged);
    _authController.dispose();
    super.dispose();
  }

  void _handleAuthStateChanged() {
    if (_authController.isAuthenticated && _pendingPayPalLink != null) {
      final pending = _pendingPayPalLink!;
      _pendingPayPalLink = null;
      unawaited(_openPayPalReturnFlow(pending));
    }
  }

  Future<void> _initializeDeepLinks() async {
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleIncomingDeepLink(initialUri);
      }
    } catch (_) {
      // Ignore invalid initial deep links.
    }

    _deepLinkSubscription = _appLinks.uriLinkStream.listen(
      _handleIncomingDeepLink,
      onError: (_) {
        // Ignore malformed runtime deep links.
      },
    );
  }

  void _handleIncomingDeepLink(Uri uri) {
    final parsed = _PendingPayPalLink.tryParse(uri);
    if (parsed == null) {
      return;
    }

    if (_lastHandledPayPalLink == parsed.rawValue) {
      return;
    }

    if (!_authController.isAuthenticated) {
      _pendingPayPalLink = parsed;
      return;
    }

    unawaited(_openPayPalReturnFlow(parsed));
  }

  Future<void> _openPayPalReturnFlow(_PendingPayPalLink link) async {
    final token = _authController.session?.accessToken;
    final navigator = _navigatorKey.currentState;
    if (token == null || navigator == null || link.reservationId == null) {
      return;
    }

    _lastHandledPayPalLink = link.rawValue;

    await navigator.push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ReservationDetailsScreen(
          token: token,
          reservationId: link.reservationId!,
          markDirtyOnPop: true,
          payPalReturnStatus: link.isCancelled
              ? PayPalReturnStatus.cancelled
              : PayPalReturnStatus.approved,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _authController,
      builder: (context, _) {
        return MaterialApp(
          navigatorKey: _navigatorKey,
          title: 'JetGo Mobile',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.themeData,
          home: _authController.isAuthenticated
              ? HomeScreen(authController: _authController)
              : LoginScreen(authController: _authController),
        );
      },
    );
  }
}

class _PendingPayPalLink {
  const _PendingPayPalLink({
    required this.rawValue,
    required this.isCancelled,
    required this.reservationId,
  });

  final String rawValue;
  final bool isCancelled;
  final int? reservationId;

  static _PendingPayPalLink? tryParse(Uri uri) {
    final host = uri.host.toLowerCase();
    if (uri.scheme.toLowerCase() != 'jetgo') {
      return null;
    }

    if (host != 'paypal-return' && host != 'paypal-cancel') {
      return null;
    }

    final reservationId = int.tryParse(
      uri.queryParameters['reservationId']?.trim() ?? '',
    );

    return _PendingPayPalLink(
      rawValue: uri.toString(),
      isCancelled: host == 'paypal-cancel',
      reservationId: reservationId,
    );
  }
}
