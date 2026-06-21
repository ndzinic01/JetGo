import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../features/auth/auth_controller.dart';
import '../features/auth/auth_service.dart';
import '../features/auth/login_screen.dart';
import '../features/home/admin_shell_screen.dart';

class JetGoDesktopApp extends StatefulWidget {
  const JetGoDesktopApp({super.key});

  @override
  State<JetGoDesktopApp> createState() => _JetGoDesktopAppState();
}

class _JetGoDesktopAppState extends State<JetGoDesktopApp> {
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
          title: 'JetGo Desktop',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.themeData,
          home: _authController.isAuthenticated
              ? AdminShellScreen(authController: _authController)
              : LoginScreen(authController: _authController),
        );
      },
    );
  }
}
