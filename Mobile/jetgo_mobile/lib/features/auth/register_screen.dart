import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/config/app_config.dart';
import '../../core/validation/input_validators.dart';
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
    _emailController.addListener(_refreshEmailValidationState);
  }

  @override
  void dispose() {
    _emailController.removeListener(_refreshEmailValidationState);
    _firstNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _refreshEmailValidationState() {
    if (mounted) {
      setState(() {});
    }
  }

  Widget? _emailStatusIcon(ThemeData theme) {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      return null;
    }

    final isValid = InputValidators.email(email) == null;
    return Icon(
      isValid ? Icons.check_circle_rounded : Icons.error_outline_rounded,
      color: isValid ? Colors.green.shade600 : theme.colorScheme.error,
    );
  }

  void _normalizePhoneInput(String value) {
    if (!value.startsWith('0')) {
      return;
    }

    final normalized = value.replaceFirst(RegExp(r'^0+'), '');
    _phoneController.value = TextEditingValue(
      text: normalized,
      selection: TextSelection.collapsed(offset: normalized.length),
    );
  }

  Future<void> _submit() async {
    final currentState = _formKey.currentState;
    if (currentState == null || !currentState.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();

    final success = await widget.authController.register(
      username: _usernameController.text.trim(),
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      email: _emailController.text.trim(),
      phoneNumber: '+387${_phoneController.text.trim()}',
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
                      autovalidateMode: AutovalidateMode.onUserInteraction,
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
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[A-Za-zČĆŽŠĐčćžšđ ]'),
                              ),
                              LengthLimitingTextInputFormatter(100),
                            ],
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Ime',
                              helperText: 'Obavezno polje',
                              prefixIcon: Icon(Icons.badge_outlined),
                            ),
                            validator: (value) => InputValidators.personName(
                              value,
                              fieldName: 'Ime',
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _lastNameController,
                            autofillHints: const [AutofillHints.familyName],
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[A-Za-zČĆŽŠĐčćžšđ ]'),
                              ),
                              LengthLimitingTextInputFormatter(100),
                            ],
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Prezime',
                              helperText: 'Obavezno polje',
                              prefixIcon: Icon(Icons.badge_outlined),
                            ),
                            validator: (value) => InputValidators.personName(
                              value,
                              fieldName: 'Prezime',
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _usernameController,
                            autofillHints: const [AutofillHints.username],
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[A-Za-z0-9._-]'),
                              ),
                              LengthLimitingTextInputFormatter(50),
                            ],
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Korisnicko ime',
                              helperText: 'Obavezno polje',
                              prefixIcon: Icon(Icons.person_outline_rounded),
                            ),
                            validator: InputValidators.username,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _emailController,
                            autofillHints: const [AutofillHints.email],
                            inputFormatters: [
                              LengthLimitingTextInputFormatter(200),
                            ],
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              labelText: 'Email adresa',
                              helperText: 'Obavezno polje',
                              hintText: 'korisnik@domena.com',
                              prefixIcon:
                                  const Icon(Icons.mail_outline_rounded),
                              suffixIcon: _emailStatusIcon(theme),
                            ),
                            validator: InputValidators.email,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _phoneController,
                            autofillHints: const [
                              AutofillHints.telephoneNumber,
                            ],
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(9),
                            ],
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.next,
                            onChanged: _normalizePhoneInput,
                            decoration: const InputDecoration(
                              labelText: 'Telefon',
                              helperText: 'Obavezno polje',
                              hintText: '61805861',
                              prefixText: '+387 ',
                              prefixIcon: Icon(Icons.phone_outlined),
                            ),
                            validator: InputValidators.bosniaLocalPhone,
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
                            validator: InputValidators.password,
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
                              final error = InputValidators.password(
                                value,
                                fieldName: 'Potvrda lozinke',
                              );
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
