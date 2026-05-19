import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import 'auth_controller.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({required this.authController, super.key});

  final AuthController authController;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(text: 'mobile');
    _passwordController = TextEditingController(text: 'test');
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final currentState = _formKey.currentState;
    if (currentState == null || !currentState.validate()) {
      return;
    }

    final success = await widget.authController.login(
      username: _usernameController.text,
      password: _passwordController.text,
    );

    if (!mounted || success) {
      return;
    }

    final errorMessage = widget.authController.errorMessage ??
        'Prijava nije uspjela. Pokusajte ponovo.';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(errorMessage)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.flight_takeoff_rounded,
                          size: 36,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'JetGo Mobile',
                          style: theme.textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Prijavite se da pregledate letove, rezervacije, novosti i svoj profil.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _usernameController,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Korisnicko ime',
                            prefixIcon: Icon(Icons.person_outline_rounded),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Unesite korisnicko ime.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: true,
                          onFieldSubmitted: (_) => _submit(),
                          decoration: const InputDecoration(
                            labelText: 'Lozinka',
                            prefixIcon: Icon(Icons.lock_outline_rounded),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Unesite lozinku.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        ListenableBuilder(
                          listenable: widget.authController,
                          builder: (context, _) {
                            return FilledButton.icon(
                              onPressed:
                                  widget.authController.isLoading ? null : _submit,
                              icon: widget.authController.isLoading
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.login_rounded),
                              label: Text(
                                widget.authController.isLoading
                                    ? 'Prijava u toku...'
                                    : 'Prijavi se',
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'API: ${AppConfig.apiBaseUrl}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
