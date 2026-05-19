import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../features/auth/auth_controller.dart';
import '../features/auth/auth_service.dart';
import '../features/auth/login_screen.dart';
import '../features/home/home_screen.dart';

class JetGoMobileApp extends StatefulWidget {
  const JetGoMobileApp({super.key});

  @override
  State<JetGoMobileApp> createState() => _JetGoMobileAppState();
}

class _JetGoMobileAppState extends State<JetGoMobileApp> {
  late final AuthController _authController;

  @override
  void initState() {
    super.initState();
    _authController = AuthController(AuthService());
  }

  @override
  void dispose() {
    _authController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _authController,
      builder: (context, _) {
        return MaterialApp(
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
