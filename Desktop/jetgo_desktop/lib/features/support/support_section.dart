import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/network/api_exception.dart';
import 'support_models.dart';
import 'support_service.dart';

class SupportSection extends StatefulWidget {
  const SupportSection({required this.token, super.key});

  final String token;

  @override
  State<SupportSection> createState() => _SupportSectionState();
}

class _SupportSectionState extends State<SupportSection> {
  final SupportService _service = SupportService();
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  bool _isLoading = true;
  bool _isDetailsLoading = false;
  bool _isReplySubmitting = false;
  String? _errorMessage;
  String? _detailsErrorMessage;

  List<SupportMessageItem> _messages = const [];
  SupportMessageDetails? _selectedDetails;
  int? _selectedMessageId;

  bool? _isRepliedFilter;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearchChanged);
    _loadMessages();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _handleSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) {
        return;
      }

      _loadMessages(showLoader: false);
    });
  }

  Future<void> _loadMessages({bool showLoader = true}) async {
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
      final response = await _service.fetchMessages(
        token: widget.token,
        searchText: _searchController.text,
        isReplied: _isRepliedFilter,
      );

      _messages = response.items;

      if (_messages.isEmpty) {
        _selectedMessageId = null;
        _selectedDetails = null;
        _detailsErrorMessage = null;
      } else {
        final selectedExists = _selectedMessageId != null &&
            _messages.any((item) => item.id == _selectedMessageId);
        final nextId = selectedExists ? _selectedMessageId! : _messages.first.id;
        await _loadMessageDetails(nextId, showLoader: false);
      }
    } on ApiException catch (error) {
      _errorMessage = error.message;
    } catch (_) {
      _errorMessage = 'Poruke podrske trenutno nisu dostupne. Pokusajte ponovo.';
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMessageDetails(
    int id, {
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
      final details = await _service.getMessage(
        token: widget.token,
        id: id,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _selectedMessageId = id;
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
        _detailsErrorMessage = 'Detalji poruke trenutno nisu dostupni.';
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
    await _loadMessages();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _openReplyDialog() async {
    final details = _selectedDetails;
    if (details == null) {
      return;
    }

    final value = await showDialog<String>(
      context: context,
      builder: (context) => _SupportReplyDialog(
        subject: details.subject,
        initialReply: details.adminReply,
      ),
    );

    if (value == null) {
      return;
    }

    setState(() {
      _isReplySubmitting = true;
    });

    try {
      final updated = await _service.replyToMessage(
        token: widget.token,
        id: details.id,
        adminReply: value,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _selectedDetails = updated;
      });
      _showMessage(
        details.isReplied
            ? 'Admin odgovor je uspjesno azuriran.'
            : 'Admin odgovor je uspjesno poslan.',
      );
      await _loadMessages(showLoader: false);
    } on ApiException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Slanje odgovora trenutno nije dostupno.');
    } finally {
      if (mounted) {
        setState(() {
          _isReplySubmitting = false;
        });
      }
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
                onSubmitted: (_) => _loadMessages(),
                decoration: const InputDecoration(
                  labelText: 'Pretraga poruka podrske',
                  hintText: 'Naslov, sadrzaj, korisnik ili email',
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
          child: SizedBox(
            width: 180,
            child: DropdownButtonFormField<bool?>(
              key: ValueKey<bool?>(_isRepliedFilter),
              initialValue: _isRepliedFilter,
              decoration: const InputDecoration(labelText: 'Status odgovora'),
              items: const [
                DropdownMenuItem<bool?>(
                  value: null,
                  child: Text('Sve poruke'),
                ),
                DropdownMenuItem<bool?>(
                  value: false,
                  child: Text('Bez odgovora'),
                ),
                DropdownMenuItem<bool?>(
                  value: true,
                  child: Text('Odgovorene'),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _isRepliedFilter = value;
                });
                _loadMessages();
              },
            ),
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
        title: 'Nije moguce ucitati poruke podrske',
        message: _errorMessage!,
      );
    }

    if (_messages.isEmpty) {
      return const _CenteredMessage(
        icon: Icons.mark_email_unread_outlined,
        title: 'Nema poruka za prikaz',
        message: 'Pokusajte druge filtere ili pretragu.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Upiti podrske (${_messages.length})',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        Expanded(
          child: SingleChildScrollView(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Naslov')),
                  DataColumn(label: Text('Kupac')),
                  DataColumn(label: Text('Email')),
                  DataColumn(label: Text('Pregled')),
                  DataColumn(label: Text('Kreirano')),
                  DataColumn(label: Text('Odgovor')),
                  DataColumn(label: Text('Odgovoreno u')),
                ],
                rows: _messages.map((item) {
                  final isSelected = item.id == _selectedMessageId;
                  return DataRow(
                    selected: isSelected,
                    onSelectChanged: (_) => _loadMessageDetails(item.id),
                    cells: [
                      DataCell(
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 220),
                          child: Text(
                            item.subject,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      DataCell(
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 160),
                          child: Text(
                            item.customerName,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      DataCell(
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 220),
                          child: Text(
                            item.customerEmail,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      DataCell(
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 280),
                          child: Text(
                            item.messagePreview,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      DataCell(Text(_formatDateTime(item.createdAtUtc))),
                      DataCell(
                        Text(item.isReplied ? 'Odgovoreno' : 'Ceka odgovor'),
                      ),
                      DataCell(Text(_formatDateTime(item.repliedAtUtc))),
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
        title: 'Odaberite poruku',
        message: 'Kliknite red iz tabele da otvorite detalje i admin odgovor.',
      );
    }

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
                    details.subject,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(details.customer.fullName),
                  const SizedBox(height: 4),
                  Text(details.customer.email),
                ],
              ),
            ),
            _StatusBadge(label: details.isReplied ? 'Odgovoreno' : 'Na cekanju'),
          ],
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _isReplySubmitting ? null : _openReplyDialog,
          icon: Icon(
            details.isReplied ? Icons.edit_note_rounded : Icons.reply_rounded,
          ),
          label: Text(
            _isReplySubmitting
                ? 'Slanje...'
                : details.isReplied
                ? 'Uredi odgovor'
                : 'Odgovori',
          ),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: ListView(
            children: [
              _DetailsBlock(
                title: 'Kupac',
                rows: [
                  _DetailsRow('Ime i prezime', details.customer.fullName),
                  _DetailsRow('Korisnicko ime', '@${details.customer.username}'),
                  _DetailsRow('Email', details.customer.email),
                  _DetailsRow('ID korisnika', details.customer.userId),
                ],
                body: 'Profil korisnika koji je poslao upit podrsci.',
              ),
              const SizedBox(height: 16),
              _DetailsBlock(
                title: 'Poruka korisnika',
                rows: [
                  _DetailsRow('Kreirano', _formatDateTime(details.createdAtUtc)),
                  _DetailsRow(
                    'Zadnji update',
                    _formatDateTime(details.updatedAtUtc),
                  ),
                ],
                body: details.message,
              ),
              const SizedBox(height: 16),
              _DetailsBlock(
                title: 'Admin odgovor',
                rows: [
                  _DetailsRow(
                    'Status',
                    details.isReplied ? 'Odgovoreno' : 'Ceka odgovor',
                  ),
                  _DetailsRow(
                    'Odgovoreno u',
                    _formatDateTime(details.repliedAtUtc),
                  ),
                ],
                body: (details.adminReply?.trim().isNotEmpty ?? false)
                    ? details.adminReply!
                    : 'Jos nema admin odgovora.',
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
    required this.body,
  });

  final String title;
  final List<_DetailsRow> rows;
  final String body;

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
                  width: 120,
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
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(body),
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

class _SupportReplyDialog extends StatefulWidget {
  const _SupportReplyDialog({
    required this.subject,
    this.initialReply,
  });

  final String subject;
  final String? initialReply;

  @override
  State<_SupportReplyDialog> createState() => _SupportReplyDialogState();
}

class _SupportReplyDialogState extends State<_SupportReplyDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _replyController;

  @override
  void initState() {
    super.initState();
    _replyController = TextEditingController(text: widget.initialReply ?? '');
  }

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasInitialReply = widget.initialReply?.trim().isNotEmpty == true;

    return AlertDialog(
      title: Text(hasInitialReply ? 'Uredi odgovor' : 'Odgovori na upit'),
      content: SizedBox(
        width: 560,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.subject,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _replyController,
                minLines: 6,
                maxLines: 10,
                maxLength: 4000,
                decoration: const InputDecoration(
                  labelText: 'Admin odgovor',
                  alignLabelWithHint: true,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Odgovor administratora je obavezan.';
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

            Navigator.of(context).pop(_replyController.text.trim());
          },
          child: Text(hasInitialReply ? 'Sacuvaj odgovor' : 'Posalji odgovor'),
        ),
      ],
    );
  }
}
