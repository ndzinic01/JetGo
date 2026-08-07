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
    _usernameController = TextEditingController(text: 'desktop');
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

  Future<void> _openPasswordResetDialog() async {
    final newPassword = await showDialog<String>(
      context: context,
      builder: (context) => _PasswordResetDialog(
        authController: widget.authController,
      ),
    );

    if (!mounted || newPassword == null) {
      return;
    }

    _passwordController.text = newPassword;
    _passwordController.selection = TextSelection.collapsed(
      offset: newPassword.length,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Lozinka je uspjesno promijenjena. Nova lozinka je upisana u polje za prijavu.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1080),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Expanded(
                    flex: 6,
                    child: Container(
                      padding: const EdgeInsets.all(40),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.flight_takeoff_rounded,
                            size: 44,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'JetGo Desktop Admin',
                            style: theme.textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Upravlja referentnim podacima, letovima, rezervacijama i korisnicima kroz jedan miran radni interfejs.',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: const [
                              _FeatureChip(label: 'Drzave / Gradovi'),
                              _FeatureChip(label: 'Aerodromi / Aviokompanije'),
                              _FeatureChip(label: 'Letovi / Rute'),
                              _FeatureChip(label: 'Rezervacije / Korisnici'),
                              _FeatureChip(label: 'Podrska / Izvjestaji'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    flex: 5,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Admin prijava',
                                style: theme.textTheme.headlineSmall,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Koristi administratorski nalog da otvoris desktop modul.',
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
                                  prefixIcon:
                                      Icon(Icons.person_outline_rounded),
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
                                  prefixIcon:
                                      Icon(Icons.lock_outline_rounded),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Unesite lozinku.';
                                  }
                                  return null;
                                },
                              ),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: _openPasswordResetDialog,
                                  child: const Text('Zaboravili ste lozinku?'),
                                ),
                              ),
                              const SizedBox(height: 24),
                              ListenableBuilder(
                                listenable: widget.authController,
                                builder: (context, _) {
                                  return FilledButton.icon(
                                    onPressed: widget.authController.isLoading
                                        ? null
                                        : _submit,
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PasswordResetDialog extends StatefulWidget {
  const _PasswordResetDialog({required this.authController});

  final AuthController authController;

  @override
  State<_PasswordResetDialog> createState() => _PasswordResetDialogState();
}

class _PasswordResetDialogState extends State<_PasswordResetDialog> {
  final _emailFormKey = GlobalKey<FormState>();
  final _resetFormKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  late final TextEditingController _tokenController;
  late final TextEditingController _newPasswordController;
  late final TextEditingController _confirmPasswordController;

  String? _message;
  bool _tokenRequested = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
    _tokenController = TextEditingController();
    _newPasswordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _tokenController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _requestToken() async {
    final currentState = _emailFormKey.currentState;
    if (currentState == null || !currentState.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();

    final result = await widget.authController.requestPasswordReset(
      email: _emailController.text,
    );

    if (!mounted) {
      return;
    }

    if (result == null) {
      _showError();
      return;
    }

    setState(() {
      _tokenRequested = true;
      _message = result.message;
    });
  }

  Future<void> _resetPassword() async {
    final currentState = _resetFormKey.currentState;
    if (currentState == null || !currentState.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();

    final success = await widget.authController.resetPassword(
      email: _emailController.text,
      token: _tokenController.text,
      newPassword: _newPasswordController.text,
      confirmPassword: _confirmPasswordController.text,
    );

    if (!mounted) {
      return;
    }

    if (!success) {
      _showError();
      return;
    }

    Navigator.of(context).pop(_newPasswordController.text);
  }

  void _showError() {
    final message = widget.authController.errorMessage ??
        'Reset lozinke trenutno nije dostupan. Pokusajte ponovo.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) {
      return 'Unesite email adresu.';
    }
    final isValid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
    if (!isValid) {
      return 'Unesite validnu email adresu u formatu korisnik@domena.com.';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Unesite novu lozinku.';
    }
    if (value.length < 4) {
      return 'Nova lozinka mora imati najmanje 4 karaktera.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Reset lozinke'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Form(
                key: _emailFormKey,
                child: TextFormField(
                  controller: _emailController,
                  enabled: !_tokenRequested,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Email adresa',
                    prefixIcon: Icon(Icons.mail_outline_rounded),
                  ),
                  validator: _validateEmail,
                ),
              ),
              const SizedBox(height: 12),
              if (!_tokenRequested) ...[
                Text(
                  'Unesite email adresu administratorskog naloga.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () {
                      if (_emailFormKey.currentState?.validate() ?? false) {
                        setState(() {
                          _tokenRequested = true;
                        });
                      }
                    },
                    child: const Text('Vec imam reset token'),
                  ),
                ),
              ],
              if (_message != null) ...[
                Text(
                  _message!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (_tokenRequested) ...[
                Text(
                  'Unesite token koji ste dobili putem email-a, zatim novu lozinku.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                Form(
                  key: _resetFormKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _tokenController,
                        minLines: 1,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Reset token',
                          prefixIcon: Icon(Icons.key_rounded),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Unesite reset token.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _newPasswordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Nova lozinka',
                          prefixIcon: Icon(Icons.lock_reset_rounded),
                        ),
                        validator: _validatePassword,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Potvrda nove lozinke',
                          prefixIcon: Icon(Icons.lock_outline_rounded),
                        ),
                        validator: (value) {
                          final error = _validatePassword(value);
                          if (error != null) {
                            return error;
                          }
                          if (value != _newPasswordController.text) {
                            return 'Nova lozinka i potvrda moraju biti iste.';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Odustani'),
        ),
        ListenableBuilder(
          listenable: widget.authController,
          builder: (context, _) {
            return FilledButton.icon(
              onPressed: widget.authController.isLoading
                  ? null
                  : (_tokenRequested ? _resetPassword : _requestToken),
              icon: widget.authController.isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      _tokenRequested
                          ? Icons.check_rounded
                          : Icons.mail_outline_rounded,
                    ),
              label: Text(
                widget.authController.isLoading
                    ? 'Obrada...'
                    : (_tokenRequested ? 'Promijeni lozinku' : 'Posalji token'),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _FeatureChip extends StatelessWidget {
  const _FeatureChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label),
    );
  }
}
