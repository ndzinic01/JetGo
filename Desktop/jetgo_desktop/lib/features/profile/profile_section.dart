import 'package:flutter/material.dart';

import '../auth/auth_controller.dart';
import '../../core/network/api_exception.dart';
import 'profile_models.dart';
import 'profile_service.dart';

class ProfileSection extends StatefulWidget {
  const ProfileSection({
    required this.token,
    required this.authController,
    super.key,
  });

  final String token;
  final AuthController authController;

  @override
  State<ProfileSection> createState() => _ProfileSectionState();
}

class _ProfileSectionState extends State<ProfileSection> {
  final ProfileService _service = ProfileService();

  AdminProfile? _profile;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final profile = await _service.fetchMyProfile(token: widget.token);

      if (!mounted) {
        return;
      }

      setState(() {
        _profile = profile;
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = 'Profil trenutno nije dostupan. Pokusajte ponovo.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _openEditDialog() async {
    final profile = _profile;
    if (profile == null) {
      return;
    }

    final updated = await showDialog<AdminProfile>(
      context: context,
      builder: (context) => _EditProfileDialog(
        token: widget.token,
        profile: profile,
        service: _service,
      ),
    );

    if (updated == null || !mounted) {
      return;
    }

    setState(() {
      _profile = updated;
    });

    widget.authController.updateCurrentUser(
      firstName: updated.firstName,
      lastName: updated.lastName,
      email: updated.email,
      phoneNumber: updated.phoneNumber,
    );

    _showMessage('Profil je uspjesno azuriran.');
  }

  Future<void> _openChangePasswordDialog() async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (context) => _ChangePasswordDialog(
        token: widget.token,
        service: _service,
      ),
    );

    if (changed == true && mounted) {
      _showMessage('Lozinka je uspjesno promijenjena.');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return _CenteredMessage(
        icon: Icons.error_outline_rounded,
        title: 'Profil nije dostupan',
        message: _errorMessage!,
      );
    }

    final profile = _profile;
    if (profile == null) {
      return const _CenteredMessage(
        icon: Icons.person_off_rounded,
        title: 'Profil nije ucitan',
        message: 'Trenutno nema podataka za prikaz.',
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ProfileAvatar(profile: profile),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              profile.fullName,
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 6),
                            Text('@${profile.username}'),
                            const SizedBox(height: 4),
                            Text(profile.email),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton.icon(
                        onPressed: _openEditDialog,
                        icon: const Icon(Icons.edit_rounded),
                        label: const Text('Uredi profil'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: _openChangePasswordDialog,
                        icon: const Icon(Icons.lock_reset_rounded),
                        label: const Text('Promijeni lozinku'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Osvjezi'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          flex: 5,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ListView(
                children: [
                  _DetailsBlock(
                    title: 'Osnovni podaci',
                    rows: [
                      _DetailsRow('Ime', profile.firstName),
                      _DetailsRow('Prezime', profile.lastName),
                      _DetailsRow('Korisnicko ime', '@${profile.username}'),
                      _DetailsRow('Email', profile.email),
                      _DetailsRow(
                        'Telefon',
                        profile.phoneNumber?.trim().isNotEmpty == true
                            ? profile.phoneNumber!
                            : '-',
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _DetailsBlock(
                    title: 'Nalog',
                    rows: [
                      _DetailsRow(
                        'Uloge',
                        profile.roles.isEmpty ? '-' : profile.roles.join(', '),
                      ),
                      _DetailsRow('ID korisnika', profile.userId),
                      _DetailsRow(
                        'URL slike',
                        profile.imageUrl?.trim().isNotEmpty == true
                            ? profile.imageUrl!
                            : '-',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.profile});

  final AdminProfile profile;

  @override
  Widget build(BuildContext context) {
    final initials = _buildInitials(profile.fullName);
    final imageUrl = profile.imageUrl?.trim();

    return CircleAvatar(
      radius: 34,
      backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
      backgroundImage: imageUrl != null && imageUrl.isNotEmpty
          ? NetworkImage(imageUrl)
          : null,
      child: imageUrl != null && imageUrl.isNotEmpty
          ? null
          : Text(
              initials,
              style: Theme.of(context).textTheme.titleMedium,
            ),
    );
  }

  String _buildInitials(String value) {
    final parts = value
        .split(' ')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) {
      return 'JG';
    }

    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }

    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }
}

class _EditProfileDialog extends StatefulWidget {
  const _EditProfileDialog({
    required this.token,
    required this.profile,
    required this.service,
  });

  final String token;
  final AdminProfile profile;
  final ProfileService service;

  @override
  State<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _imageUrlController;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _firstNameController =
        TextEditingController(text: widget.profile.firstName);
    _lastNameController = TextEditingController(text: widget.profile.lastName);
    _emailController = TextEditingController(text: widget.profile.email);
    _phoneController =
        TextEditingController(text: widget.profile.phoneNumber ?? '');
    _imageUrlController =
        TextEditingController(text: widget.profile.imageUrl ?? '');
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
    if (!_formKey.currentState!.validate() || _isSubmitting) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final updated = await widget.service.updateMyProfile(
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
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = 'Izmjena profila trenutno nije dostupna.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Uredi profil'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_errorMessage != null) ...[
                  _InlineError(message: _errorMessage!),
                  const SizedBox(height: 12),
                ],
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _firstNameController,
                        maxLength: 100,
                        decoration: const InputDecoration(labelText: 'Ime'),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Ime je obavezno.';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _lastNameController,
                        maxLength: 100,
                        decoration: const InputDecoration(labelText: 'Prezime'),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Prezime je obavezno.';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  maxLength: 200,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: (value) {
                    final trimmed = value?.trim() ?? '';
                    if (trimmed.isEmpty) {
                      return 'Email je obavezan.';
                    }
                    if (!trimmed.contains('@') || !trimmed.contains('.')) {
                      return 'Unesite validan email.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  maxLength: 30,
                  decoration: const InputDecoration(labelText: 'Telefon'),
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
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Odustani'),
        ),
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
    );
  }
}

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog({
    required this.token,
    required this.service,
  });

  final String token;
  final ProfileService service;

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isSubmitting = false;
  bool _showCurrentPassword = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;
  String? _errorMessage;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _isSubmitting) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await widget.service.changePassword(
        token: widget.token,
        currentPassword: _currentPasswordController.text,
        newPassword: _newPasswordController.text,
        confirmPassword: _confirmPasswordController.text,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = 'Promjena lozinke trenutno nije dostupna.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Promijeni lozinku'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_errorMessage != null) ...[
                  _InlineError(message: _errorMessage!),
                  const SizedBox(height: 12),
                ],
                TextFormField(
                  controller: _currentPasswordController,
                  obscureText: !_showCurrentPassword,
                  decoration: InputDecoration(
                    labelText: 'Trenutna lozinka',
                    suffixIcon: IconButton(
                      tooltip: _showCurrentPassword ? 'Sakrij' : 'Prikazi',
                      onPressed: () {
                        setState(() {
                          _showCurrentPassword = !_showCurrentPassword;
                        });
                      },
                      icon: Icon(
                        _showCurrentPassword
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Trenutna lozinka je obavezna.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _newPasswordController,
                  obscureText: !_showNewPassword,
                  decoration: InputDecoration(
                    labelText: 'Nova lozinka',
                    suffixIcon: IconButton(
                      tooltip: _showNewPassword ? 'Sakrij' : 'Prikazi',
                      onPressed: () {
                        setState(() {
                          _showNewPassword = !_showNewPassword;
                        });
                      },
                      icon: Icon(
                        _showNewPassword
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Nova lozinka je obavezna.';
                    }
                    if (value.length < 4) {
                      return 'Nova lozinka mora imati najmanje 4 karaktera.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: !_showConfirmPassword,
                  decoration: InputDecoration(
                    labelText: 'Potvrda nove lozinke',
                    suffixIcon: IconButton(
                      tooltip: _showConfirmPassword ? 'Sakrij' : 'Prikazi',
                      onPressed: () {
                        setState(() {
                          _showConfirmPassword = !_showConfirmPassword;
                        });
                      },
                      icon: Icon(
                        _showConfirmPassword
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Potvrda lozinke je obavezna.';
                    }
                    if (value != _newPasswordController.text) {
                      return 'Lozinke se ne podudaraju.';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Odustani'),
        ),
        FilledButton.icon(
          onPressed: _isSubmitting ? null : _submit,
          icon: _isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.lock_reset_rounded),
          label: const Text('Sacuvaj novu lozinku'),
        ),
      ],
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
      ),
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 36),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _DetailsBlock extends StatelessWidget {
  const _DetailsBlock({
    required this.title,
    required this.rows,
  });

  final String title;
  final List<_DetailsRow> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 10),
        ...rows.map(
          (row) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 140,
                  child: Text(
                    row.label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(row.value)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DetailsRow {
  const _DetailsRow(this.label, this.value);

  final String label;
  final String value;
}
