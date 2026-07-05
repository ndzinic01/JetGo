import 'package:flutter/material.dart';

import '../../core/network/api_exception.dart';
import 'users_models.dart';
import 'users_service.dart';

class UsersSection extends StatefulWidget {
  const UsersSection({
    required this.token,
    required this.currentUserId,
    super.key,
  });

  final String token;
  final String currentUserId;

  @override
  State<UsersSection> createState() => _UsersSectionState();
}

class _UsersSectionState extends State<UsersSection> {
  static const List<String> _supportedRoles = ['Admin', 'User'];

  final UsersService _service = UsersService();
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  bool _isDetailsLoading = false;
  String? _errorMessage;
  String? _detailsErrorMessage;

  List<AdminUserItem> _users = const [];
  AdminUserDetails? _selectedDetails;
  String? _selectedUserId;

  String? _roleFilter;
  bool? _isActiveFilter;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers({bool showLoader = true}) async {
    if (showLoader) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    } else {
      setState(() {
        _errorMessage = null;
      });
    }

    try {
      final response = await _service.fetchUsers(
        token: widget.token,
        searchText: _searchController.text,
        roleName: _roleFilter,
        isActive: _isActiveFilter,
      );

      _users = response.items;

      if (_users.isEmpty) {
        _selectedUserId = null;
        _selectedDetails = null;
        _detailsErrorMessage = null;
      } else {
        final selectedExists = _selectedUserId != null &&
            _users.any((item) => item.userId == _selectedUserId);
        final nextUserId =
            selectedExists ? _selectedUserId! : _users.first.userId;
        await _loadUserDetails(nextUserId, showLoader: false);
      }
    } on ApiException catch (error) {
      _errorMessage = error.message;
    } catch (_) {
      _errorMessage = 'Korisnici trenutno nisu dostupni. Pokusajte ponovo.';
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadUserDetails(
    String userId, {
    bool showLoader = true,
  }) async {
    if (showLoader) {
      setState(() {
        _isDetailsLoading = true;
        _detailsErrorMessage = null;
      });
    } else {
      setState(() {
        _detailsErrorMessage = null;
      });
    }

    try {
      final details = await _service.getUser(
        token: widget.token,
        userId: userId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _selectedUserId = userId;
        _selectedDetails = details;
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _detailsErrorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _detailsErrorMessage = 'Detalji korisnika trenutno nisu dostupni.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isDetailsLoading = false;
        });
      }
    }
  }

  Future<void> _handleRefresh() async {
    await _loadUsers();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _openEditDialog() async {
    final details = _selectedDetails;
    if (details == null) {
      return;
    }

    final value = await showDialog<_EditUserFormValue>(
      context: context,
      builder: (context) => _EditUserDialog(
        initial: details,
        supportedRoles: _supportedRoles,
        isCurrentUser: details.userId == widget.currentUserId,
      ),
    );

    if (value == null) {
      return;
    }

    try {
      final updated = await _service.updateUser(
        token: widget.token,
        userId: details.userId,
        firstName: value.firstName,
        lastName: value.lastName,
        email: value.email,
        phoneNumber: value.phoneNumber,
        imageUrl: value.imageUrl,
        roles: value.roles,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _selectedDetails = updated;
      });
      await _loadUsers(showLoader: false);
      _showMessage('Korisnik je uspjesno azuriran.');
    } on ApiException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Azuriranje korisnika trenutno nije dostupno.');
    }
  }

  Future<void> _toggleActivation() async {
    final details = _selectedDetails;
    if (details == null) {
      return;
    }

    final nextActive = !details.isActive;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(nextActive ? 'Aktiviraj korisnika' : 'Deaktiviraj korisnika'),
          content: Text(
            nextActive
                ? 'Da li ste sigurni da zelite aktivirati korisnika @${details.username}?'
                : 'Da li ste sigurni da zelite deaktivirati korisnika @${details.username}?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Odustani'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Potvrdi'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      final updated = await _service.updateActivation(
        token: widget.token,
        userId: details.userId,
        isActive: nextActive,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _selectedDetails = updated;
      });
      await _loadUsers(showLoader: false);
      _showMessage(
        nextActive
            ? 'Korisnik je uspjesno aktiviran.'
            : 'Korisnik je uspjesno deaktiviran.',
      );
    } on ApiException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Promjena aktivacije trenutno nije dostupna.');
    }
  }

  Future<void> _openResetPasswordDialog() async {
    final details = _selectedDetails;
    if (details == null) {
      return;
    }

    final value = await showDialog<_ResetPasswordFormValue>(
      context: context,
      builder: (context) => const _ResetPasswordDialog(),
    );

    if (value == null) {
      return;
    }

    try {
      await _service.resetPassword(
        token: widget.token,
        userId: details.userId,
        newPassword: value.newPassword,
        confirmPassword: value.confirmPassword,
      );

      if (!mounted) {
        return;
      }

      _showMessage('Lozinka je uspjesno resetovana.');
    } on ApiException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Reset lozinke trenutno nije dostupan.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildToolbar(),
        const SizedBox(height: 16),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 3,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: _buildListContent(),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: _buildDetailsContent(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildToolbar() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                onSubmitted: (_) => _loadUsers(),
                decoration: const InputDecoration(
                  labelText: 'Pretraga korisnika',
                  hintText: 'Username, ime, email ili telefon',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
            ),
            const SizedBox(width: 12),
            IconButton(
              tooltip: 'Osvjezi',
              onPressed: _handleRefresh,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 180,
                child: DropdownButtonFormField<String?>(
                  key: ValueKey<String?>(_roleFilter),
                  initialValue: _roleFilter,
                  decoration: const InputDecoration(labelText: 'Rola'),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Sve role'),
                    ),
                    ..._supportedRoles.map(
                      (role) => DropdownMenuItem<String?>(
                        value: role,
                        child: Text(role),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _roleFilter = value;
                    });
                    _loadUsers();
                  },
                ),
              ),
              SizedBox(
                width: 180,
                child: DropdownButtonFormField<bool?>(
                  key: ValueKey<bool?>(_isActiveFilter),
                  initialValue: _isActiveFilter,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: const [
                    DropdownMenuItem<bool?>(
                      value: null,
                      child: Text('Svi statusi'),
                    ),
                    DropdownMenuItem<bool?>(
                      value: true,
                      child: Text('Aktivni'),
                    ),
                    DropdownMenuItem<bool?>(
                      value: false,
                      child: Text('Neaktivni'),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _isActiveFilter = value;
                    });
                    _loadUsers();
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildListContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return _CenteredMessage(
        icon: Icons.cloud_off_rounded,
        title: 'Nije moguce ucitati korisnike',
        message: _errorMessage!,
      );
    }

    if (_users.isEmpty) {
      return const _CenteredMessage(
        icon: Icons.group_off_rounded,
        title: 'Nema korisnika za prikaz',
        message: 'Pokusajte druge filtere ili pretragu.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Korisnici (${_users.length})',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        Expanded(
          child: SingleChildScrollView(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Korisnicko ime')),
                  DataColumn(label: Text('Ime i prezime')),
                  DataColumn(label: Text('Email')),
                  DataColumn(label: Text('Telefon')),
                  DataColumn(label: Text('Uloge')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Rezervacije')),
                  DataColumn(label: Text('Placanja')),
                ],
                rows: _users.map((item) {
                  final isSelected = item.userId == _selectedUserId;
                  return DataRow(
                    selected: isSelected,
                    onSelectChanged: (_) => _loadUserDetails(item.userId),
                    cells: [
                      DataCell(Text('@${item.username}')),
                      DataCell(
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 180),
                          child: Text(
                            item.fullName.trim().isEmpty
                                ? '-'
                                : item.fullName,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      DataCell(
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 220),
                          child: Text(
                            item.email,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      DataCell(Text(item.phoneNumber?.trim().isNotEmpty == true
                          ? item.phoneNumber!
                          : '-')),
                      DataCell(Text(item.roles.join(', '))),
                      DataCell(Text(item.isActive ? 'Aktivan' : 'Neaktivan')),
                      DataCell(Text(item.reservationsCount.toString())),
                      DataCell(Text(item.paymentsCount.toString())),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailsContent() {
    if (_isDetailsLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_detailsErrorMessage != null) {
      return _CenteredMessage(
        icon: Icons.error_outline_rounded,
        title: 'Detalji nisu dostupni',
        message: _detailsErrorMessage!,
      );
    }

    final details = _selectedDetails;
    if (details == null) {
      return const _CenteredMessage(
        icon: Icons.touch_app_rounded,
        title: 'Odaberite korisnika',
        message: 'Kliknite red iz tabele da otvorite detalje i admin akcije.',
      );
    }

    final isCurrentUser = details.userId == widget.currentUserId;
    final canDeactivate = !(isCurrentUser && details.isActive);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    details.fullName.trim().isEmpty
                        ? details.username
                        : details.fullName,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  Text('@${details.username}'),
                  const SizedBox(height: 4),
                  Text(details.email),
                ],
              ),
            ),
            _StatusBadge(label: details.isActive ? 'Aktivan' : 'Neaktivan'),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton.icon(
              onPressed: _openEditDialog,
              icon: const Icon(Icons.edit_rounded),
              label: const Text('Uredi'),
            ),
            Tooltip(
              message: canDeactivate
                  ? 'Promijeni status korisnika'
                  : 'Ne mozete deaktivirati vlastiti nalog.',
              child: OutlinedButton.icon(
                onPressed: canDeactivate || !details.isActive
                    ? _toggleActivation
                    : null,
                icon: Icon(
                  details.isActive
                      ? Icons.person_off_rounded
                      : Icons.verified_user_rounded,
                ),
                label: Text(details.isActive ? 'Deaktiviraj' : 'Aktiviraj'),
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: _openResetPasswordDialog,
              icon: const Icon(Icons.lock_reset_rounded),
              label: const Text('Resetuj lozinku'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Expanded(
          child: ListView(
            children: [
              _DetailsBlock(
                title: 'Profil',
                rows: [
                  _DetailsRow('Ime', details.firstName),
                  _DetailsRow('Prezime', details.lastName),
                  _DetailsRow(
                    'Telefon',
                    details.phoneNumber?.trim().isNotEmpty == true
                        ? details.phoneNumber!
                        : '-',
                  ),
                  _DetailsRow(
                    'URL slike',
                    details.imageUrl?.trim().isNotEmpty == true
                        ? details.imageUrl!
                        : '-',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _DetailsBlock(
                title: 'Uloge i status',
                rows: [
                  _DetailsRow(
                    'Uloge',
                    details.roles.isEmpty ? '-' : details.roles.join(', '),
                  ),
                  _DetailsRow(
                    'Status',
                    details.isActive ? 'Aktivan' : 'Neaktivan',
                  ),
                  _DetailsRow(
                    'Lockout do',
                    _formatDateTime(details.lockoutEndUtc),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _DetailsBlock(
                title: 'Statistika',
                rows: [
                  _DetailsRow(
                    'Rezervacije',
                    details.reservationsCount.toString(),
                  ),
                  _DetailsRow('Placanja', details.paymentsCount.toString()),
                  _DetailsRow(
                    'Poruke podrske',
                    details.supportMessagesCount.toString(),
                  ),
                  _DetailsRow(
                    'Historija pretrage',
                    details.searchHistoryCount.toString(),
                  ),
                  _DetailsRow(
                    'Neprocitane notifikacije',
                    details.unreadNotificationsCount.toString(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _DetailsBlock(
                title: 'Audit',
                rows: [
                  _DetailsRow('ID korisnika', details.userId),
                  _DetailsRow('Kreiran', _formatDateTime(details.createdAtUtc)),
                  _DetailsRow(
                    'Zadnji update',
                    _formatDateTime(details.updatedAtUtc),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) {
      return '-';
    }

    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day.$month.${local.year} $hour:$minute';
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

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
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
                  width: 130,
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

class _EditUserDialog extends StatefulWidget {
  const _EditUserDialog({
    required this.initial,
    required this.supportedRoles,
    required this.isCurrentUser,
  });

  final AdminUserDetails initial;
  final List<String> supportedRoles;
  final bool isCurrentUser;

  @override
  State<_EditUserDialog> createState() => _EditUserDialogState();
}

class _EditUserDialogState extends State<_EditUserDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneNumberController;
  late final TextEditingController _imageUrlController;
  late List<String> _selectedRoles;

  @override
  void initState() {
    super.initState();
    _firstNameController =
        TextEditingController(text: widget.initial.firstName);
    _lastNameController = TextEditingController(text: widget.initial.lastName);
    _emailController = TextEditingController(text: widget.initial.email);
    _phoneNumberController =
        TextEditingController(text: widget.initial.phoneNumber ?? '');
    _imageUrlController = TextEditingController(text: widget.initial.imageUrl ?? '');
    _selectedRoles = List<String>.from(widget.initial.roles);
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneNumberController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Uredi korisnika'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _firstNameController,
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
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: (value) {
                    final email = value?.trim() ?? '';
                    if (email.isEmpty || !email.contains('@')) {
                      return 'Unesite validan email.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneNumberController,
                  decoration: const InputDecoration(labelText: 'Telefon'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _imageUrlController,
                  decoration: const InputDecoration(labelText: 'URL slike'),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Uloge',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: widget.supportedRoles.map((role) {
                    final isSelected = _selectedRoles.contains(role);
                    final isLockedAdminRole = widget.isCurrentUser &&
                        role == 'Admin' &&
                        isSelected;

                    return FilterChip(
                      label: Text(role),
                      selected: isSelected,
                      onSelected: isLockedAdminRole
                          ? null
                          : (selected) {
                              setState(() {
                                if (selected) {
                                  if (!_selectedRoles.contains(role)) {
                                    _selectedRoles = [..._selectedRoles, role];
                                  }
                                } else {
                                  _selectedRoles =
                                      _selectedRoles.where((item) => item != role).toList();
                                }
                              });
                            },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
                if (_selectedRoles.isEmpty)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Korisnik mora imati barem jednu rolu.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Odustani'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) {
              return;
            }
            if (_selectedRoles.isEmpty) {
              setState(() {});
              return;
            }

            Navigator.of(context).pop(
              _EditUserFormValue(
                firstName: _firstNameController.text.trim(),
                lastName: _lastNameController.text.trim(),
                email: _emailController.text.trim(),
                phoneNumber: _phoneNumberController.text.trim(),
                imageUrl: _imageUrlController.text.trim(),
                roles: _selectedRoles,
              ),
            );
          },
          child: const Text('Sacuvaj'),
        ),
      ],
    );
  }
}

class _ResetPasswordDialog extends StatefulWidget {
  const _ResetPasswordDialog();

  @override
  State<_ResetPasswordDialog> createState() => _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends State<_ResetPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reset lozinke'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _newPasswordController,
                obscureText: _obscureNew,
                decoration: InputDecoration(
                  labelText: 'Nova lozinka',
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() {
                        _obscureNew = !_obscureNew;
                      });
                    },
                    icon: Icon(
                      _obscureNew
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                    ),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.length < 4) {
                    return 'Lozinka mora imati najmanje 4 karaktera.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirm,
                decoration: InputDecoration(
                  labelText: 'Potvrda lozinke',
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() {
                        _obscureConfirm = !_obscureConfirm;
                      });
                    },
                    icon: Icon(
                      _obscureConfirm
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                    ),
                  ),
                ),
                validator: (value) {
                  if (value != _newPasswordController.text) {
                    return 'Potvrda lozinke mora odgovarati novoj lozinci.';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Odustani'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) {
              return;
            }

            Navigator.of(context).pop(
              _ResetPasswordFormValue(
                newPassword: _newPasswordController.text,
                confirmPassword: _confirmPasswordController.text,
              ),
            );
          },
          child: const Text('Resetuj'),
        ),
      ],
    );
  }
}

class _EditUserFormValue {
  const _EditUserFormValue({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phoneNumber,
    required this.imageUrl,
    required this.roles,
  });

  final String firstName;
  final String lastName;
  final String email;
  final String phoneNumber;
  final String imageUrl;
  final List<String> roles;
}

class _ResetPasswordFormValue {
  const _ResetPasswordFormValue({
    required this.newPassword,
    required this.confirmPassword,
  });

  final String newPassword;
  final String confirmPassword;
}
