import 'package:flutter/material.dart';

import '../../core/network/api_exception.dart';
import '../../core/validation/input_validators.dart';
import 'mobile_data_service.dart';
import 'mobile_models.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({
    required this.token,
    required this.profile,
    super.key,
  });

  final String token;
  final MobileProfile profile;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final MobileDataService _dataService = MobileDataService();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _imageUrlController;

  bool _isSubmitting = false;
  String? _formErrorMessage;
  ApiException? _serverError;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController(
      text: widget.profile.firstName,
    );
    _lastNameController = TextEditingController(text: widget.profile.lastName);
    _emailController = TextEditingController(text: widget.profile.email);
    _phoneController = TextEditingController(
      text: widget.profile.phoneNumber ?? '',
    );
    _imageUrlController = TextEditingController(
      text: widget.profile.imageUrl ?? '',
    );
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) {
      return;
    }

    setState(() {
      _formErrorMessage = null;
      _serverError = null;
    });

    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final updated = await _dataService.updateMyProfile(
        token: widget.token,
        firstName: _firstNameController.text,
        lastName: _lastNameController.text,
        email: _emailController.text,
        phoneNumber: _phoneController.text,
        imageUrl: _imageUrlController.text,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(updated);
    } on ApiException catch (error) {
      final hasFieldErrors = _hasProfileFieldErrors(error);
      setState(() {
        _serverError = error;
        _formErrorMessage = hasFieldErrors ? null : error.message;
      });
      _formKey.currentState?.validate();
    } catch (_) {
      setState(() {
        _formErrorMessage =
            'Izmjena profila trenutno nije dostupna. Pokusajte ponovo.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  bool _hasProfileFieldErrors(ApiException error) {
    return const [
      'FirstName',
      'LastName',
      'Email',
      'PhoneNumber',
      'ImageUrl',
    ].any((fieldName) => error.fieldError(fieldName) != null);
  }

  void _clearServerErrors() {
    if (_serverError == null && _formErrorMessage == null) {
      return;
    }

    setState(() {
      _serverError = null;
      _formErrorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Uredi profil')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_formErrorMessage != null) ...[
                _InlineFormError(message: _formErrorMessage!),
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: _firstNameController,
                maxLength: 100,
                decoration: const InputDecoration(labelText: 'Ime'),
                onChanged: (_) => _clearServerErrors(),
                validator: (value) {
                  return InputValidators.requiredText(
                        value,
                        fieldName: 'Ime',
                        maxLength: 100,
                      ) ??
                      _serverError?.fieldError('FirstName');
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _lastNameController,
                maxLength: 100,
                decoration: const InputDecoration(labelText: 'Prezime'),
                onChanged: (_) => _clearServerErrors(),
                validator: (value) {
                  return InputValidators.requiredText(
                        value,
                        fieldName: 'Prezime',
                        maxLength: 100,
                      ) ??
                      _serverError?.fieldError('LastName');
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                maxLength: 200,
                decoration: const InputDecoration(labelText: 'Email'),
                onChanged: (_) => _clearServerErrors(),
                validator: (value) {
                  return InputValidators.email(value) ??
                      _serverError?.fieldError('Email');
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                maxLength: 30,
                decoration: const InputDecoration(labelText: 'Telefon'),
                onChanged: (_) => _clearServerErrors(),
                validator: (value) {
                  return InputValidators.phone(value) ??
                      _serverError?.fieldError('PhoneNumber');
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _imageUrlController,
                keyboardType: TextInputType.url,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: 'URL slike',
                  hintText: 'Opcionalno',
                ),
                onChanged: (_) => _clearServerErrors(),
                validator: (_) => _serverError?.fieldError('ImageUrl'),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _isSubmitting ? null : _submit,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_rounded),
                label: const Text('Sacuvaj izmjene'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InlineFormError extends StatelessWidget {
  const _InlineFormError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        message,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onErrorContainer,
        ),
      ),
    );
  }
}
