import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import 'auth_controller.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({required this.authController, super.key});

  final AuthController authController;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _usernameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _passwordController;
  late final TextEditingController _confirmPasswordController;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController();
    _lastNameController = TextEditingController();
    _usernameController = TextEditingController();
    _emailController = TextEditingController();
    _phoneController = TextEditingController();
    _passwordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final currentState = _formKey.currentState;
    if (currentState == null || !currentState.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();

    final success = await widget.authController.register(
      username: _usernameController.text,
      firstName: _firstNameController.text,
      lastName: _lastNameController.text,
      email: _emailController.text,
      phoneNumber: _phoneController.text,
      password: _passwordController.text,
      confirmPassword: _confirmPasswordController.text,
    );

    if (!mounted) {
      return;
    }

    if (!success) {
      final errorMessage = widget.authController.errorMessage ??
          'Registracija nije uspjela. Pokusajte ponovo.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Nalog je uspjesno kreiran.')),
    );
    Navigator.of(context).pop(_usernameController.text.trim());
  }

  String? _requiredText(
    String? value,
    String label, {
    int maxLength = 100,
  }) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return '$label je obavezno polje.';
    }
    if (text.length > maxLength) {
      return '$label moze imati maksimalno $maxLength karaktera.';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) {
      return 'Email adresa je obavezna.';
    }
    final isValid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
    if (!isValid) {
      return 'Email adresa mora biti u formatu korisnik@domena.com.';
    }
    if (email.length > 200) {
      return 'Email adresa moze imati maksimalno 200 karaktera.';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    final phone = value?.trim() ?? '';
    if (phone.isEmpty) {
      return null;
    }
    final isValid = RegExp(r'^\+?[0-9][0-9\s\-\/]{6,19}$').hasMatch(phone);
    if (!isValid) {
      return 'Broj telefona mora biti u formatu +38761123456 ili 061123456.';
    }
    if (phone.length > 30) {
      return 'Broj telefona moze imati maksimalno 30 karaktera.';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Lozinka je obavezna.';
    }
    if (value.length < 4) {
      return 'Lozinka mora imati najmanje 4 karaktera.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registracija'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: AutofillGroup(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.person_add_alt_1_rounded,
                            size: 36,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Kreirajte nalog',
                            style: theme.textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Nakon registracije automatski ulazite u JetGo Mobile.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 24),
                          TextFormField(
                            controller: _firstNameController,
                            autofillHints: const [AutofillHints.givenName],
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Ime',
                              prefixIcon: Icon(Icons.badge_outlined),
                            ),
                            validator: (value) => _requiredText(value, 'Ime'),
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _lastNameController,
                            autofillHints: const [AutofillHints.familyName],
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Prezime',
                              prefixIcon: Icon(Icons.badge_outlined),
                            ),
                            validator: (value) =>
                                _requiredText(value, 'Prezime'),
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _usernameController,
                            autofillHints: const [AutofillHints.username],
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Korisnicko ime',
                              prefixIcon: Icon(Icons.person_outline_rounded),
                            ),
                            validator: (value) => _requiredText(
                              value,
                              'Korisnicko ime',
                              maxLength: 50,
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _emailController,
                            autofillHints: const [AutofillHints.email],
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Email adresa',
                              prefixIcon: Icon(Icons.mail_outline_rounded),
                            ),
                            validator: _validateEmail,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _phoneController,
                            autofillHints: const [
                              AutofillHints.telephoneNumber,
                            ],
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Telefon',
                              hintText: '+38761123456',
                              prefixIcon: Icon(Icons.phone_outlined),
                            ),
                            validator: _validatePhone,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _passwordController,
                            autofillHints: const [AutofillHints.newPassword],
                            obscureText: true,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Lozinka',
                              prefixIcon: Icon(Icons.lock_outline_rounded),
                            ),
                            validator: _validatePassword,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _confirmPasswordController,
                            autofillHints: const [AutofillHints.newPassword],
                            obscureText: true,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _submit(),
                            decoration: const InputDecoration(
                              labelText: 'Potvrda lozinke',
                              prefixIcon: Icon(Icons.lock_reset_rounded),
                            ),
                            validator: (value) {
                              final error = _validatePassword(value);
                              if (error != null) {
                                return error;
                              }
                              if (value != _passwordController.text) {
                                return 'Lozinka i potvrda lozinke moraju biti iste.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 22),
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
                                    : const Icon(Icons.check_rounded),
                                label: Text(
                                  widget.authController.isLoading
                                      ? 'Kreiranje naloga...'
                                      : 'Kreiraj nalog',
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.arrow_back_rounded),
                            label: const Text('Nazad na prijavu'),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'API: ${AppConfig.apiBaseUrlLabel}',
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
      ),
    );
  }
}
