import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/network/api_exception.dart';
import 'notifications_models.dart';
import 'notifications_service.dart';

class NotificationsSection extends StatefulWidget {
  const NotificationsSection({required this.token, super.key});

  final String token;

  @override
  State<NotificationsSection> createState() => _NotificationsSectionState();
}

class _NotificationsSectionState extends State<NotificationsSection> {
  static const int _pageSize = 100;
  static final RegExp _flightNumberPattern = RegExp(
    r'\bJG(?:-[A-Z]+)*-?\d+\b',
    caseSensitive: false,
  );

  final NotificationsService _service = NotificationsService();
  final TextEditingController _flightNumberController = TextEditingController();
  Timer? _filterDebounce;

  bool _isLoading = true;
  String? _errorMessage;
  List<AdminNotificationItem> _notifications = const [];
  int _page = 1;
  int _totalPages = 1;
  int _totalCount = 0;
  bool _hasPreviousPage = false;
  bool _hasNextPage = false;

  DateTime? _createdFrom;
  DateTime? _createdTo;

  @override
  void initState() {
    super.initState();
    _flightNumberController.addListener(_handleFilterTextChanged);
    _loadNotifications();
  }

  @override
  void dispose() {
    _filterDebounce?.cancel();
    _flightNumberController.dispose();
    super.dispose();
  }

  void _handleFilterTextChanged() {
    _filterDebounce?.cancel();
    _filterDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) {
        return;
      }

      _loadNotifications(showLoader: false, page: 1);
    });
  }

  Future<void> _loadNotifications({bool showLoader = true, int? page}) async {
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
      final response = await _service.fetchNotifications(
        token: widget.token,
        flightNumber: _flightNumberController.text,
        createdFromUtc: _createdFrom == null
            ? null
            : DateTime(
                _createdFrom!.year,
                _createdFrom!.month,
                _createdFrom!.day,
              ).toUtc(),
        createdToUtc: _createdTo == null
            ? null
            : DateTime(
                _createdTo!.year,
                _createdTo!.month,
                _createdTo!.day,
                23,
                59,
                59,
                999,
              ).toUtc(),
        page: page ?? _page,
        pageSize: _pageSize,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _notifications = response.items;
        _page = response.page;
        _totalPages = response.totalPages;
        _totalCount = response.totalCount;
        _hasPreviousPage = response.hasPreviousPage;
        _hasNextPage = response.hasNextPage;
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
        _errorMessage = 'Sistemske notifikacije trenutno nisu dostupne.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pickDate({required bool isStartDate}) async {
    final initialDate = isStartDate
        ? _createdFrom ?? DateTime.now()
        : _createdTo ?? _createdFrom ?? DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
    );

    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      if (isStartDate) {
        _createdFrom = picked;
        if (_createdTo != null && _createdTo!.isBefore(picked)) {
          _createdTo = picked;
        }
      } else {
        _createdTo = picked;
      }
    });

    await _loadNotifications(page: 1);
  }

  void _clearFilters() {
    _filterDebounce?.cancel();
    _flightNumberController.clear();
    setState(() {
      _createdFrom = null;
      _createdTo = null;
    });
    _loadNotifications(page: 1);
  }

  Future<void> _handleRefresh() async {
    await _loadNotifications();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildToolbar(),
        const SizedBox(height: 16),
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _buildContent(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildToolbar() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 280,
          child: TextField(
            controller: _flightNumberController,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Broj leta',
              hintText: 'npr. JG101',
              prefixIcon: Icon(Icons.flight_takeoff_rounded),
            ),
            onSubmitted: (_) => _loadNotifications(page: 1),
          ),
        ),
        _DateFilterButton(
          label: 'Od datuma',
          value: _formatDate(_createdFrom),
          onPressed: () => _pickDate(isStartDate: true),
        ),
        _DateFilterButton(
          label: 'Do datuma',
          value: _formatDate(_createdTo),
          onPressed: () => _pickDate(isStartDate: false),
        ),
        OutlinedButton.icon(
          onPressed: _clearFilters,
          icon: const Icon(Icons.filter_alt_off_rounded),
          label: const Text('Ocisti'),
        ),
        IconButton(
          tooltip: 'Osvjezi',
          onPressed: _handleRefresh,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return _CenteredMessage(
        icon: Icons.cloud_off_rounded,
        title: 'Nije moguce ucitati notifikacije',
        message: _errorMessage!,
      );
    }

    if (_notifications.isEmpty) {
      return const _CenteredMessage(
        icon: Icons.notifications_none_rounded,
        title: 'Nema notifikacija za prikaz',
        message: 'Pokusajte drugi broj leta ili datumski period.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Sistemske notifikacije ($_totalCount)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (_totalPages > 1) ...[
              const Spacer(),
              Text(
                'Stranica $_page od $_totalPages',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Scrollbar(
            thumbVisibility: true,
            child: SingleChildScrollView(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Datum i vrijeme')),
                    DataColumn(label: Text('Broj leta')),
                    DataColumn(label: Text('Tip promjene')),
                    DataColumn(label: Text('Korisnik')),
                    DataColumn(label: Text('Poruka')),
                    DataColumn(label: Text('Status')),
                  ],
                  rows: _notifications.map((item) {
                    return DataRow(
                      cells: [
                        DataCell(Text(_formatDateTime(item.createdAtUtc))),
                        DataCell(Text(_displayFlightNumber(item))),
                        DataCell(_TypeBadge(label: _displayTypeLabel(item))),
                        DataCell(
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 210),
                            child: Tooltip(
                              message: item.recipientEmail,
                              child: Text(
                                item.recipientName.isEmpty
                                    ? item.recipientEmail
                                    : item.recipientName,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 420),
                            child: Tooltip(
                              message: item.body,
                              child: Text(
                                item.body,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                        DataCell(_StatusBadge(status: item.status)),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildFooter(),
      ],
    );
  }

  Widget _buildFooter() {
    if (_totalPages <= 1) {
      return Align(
        alignment: Alignment.centerRight,
        child: Text(
          'Prikazano ${_notifications.length} od $_totalCount',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return Row(
      children: [
        OutlinedButton.icon(
          onPressed: _hasPreviousPage
              ? () => _loadNotifications(page: _page - 1)
              : null,
          icon: const Icon(Icons.chevron_left_rounded),
          label: const Text('Prethodna'),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: _hasNextPage
              ? () => _loadNotifications(page: _page + 1)
              : null,
          icon: const Icon(Icons.chevron_right_rounded),
          label: const Text('Sljedeca'),
        ),
        const Spacer(),
        Text(
          'Prikazano ${_notifications.length} od $_totalCount',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  String _displayTypeLabel(AdminNotificationItem item) {
    if (item.type != NotificationTypeValue.system) {
      return item.type.label;
    }

    final title = item.title.trim();
    return title.isEmpty ? item.type.label : title;
  }

  String _displayFlightNumber(AdminNotificationItem item) {
    final storedFlightNumber = item.flightNumber?.trim();
    if (storedFlightNumber != null && storedFlightNumber.isNotEmpty) {
      return storedFlightNumber;
    }

    return _extractFlightNumber(item.title) ??
        _extractFlightNumber(item.body) ??
        '-';
  }

  String? _extractFlightNumber(String value) {
    final match = _flightNumberPattern.firstMatch(value.toUpperCase());
    return match?.group(0);
  }

  String _formatDate(DateTime? value) {
    if (value == null) {
      return 'Nije odabrano';
    }

    return '${_twoDigits(value.day)}.${_twoDigits(value.month)}.${value.year}';
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) {
      return '-';
    }

    final local = value.toLocal();
    return '${_twoDigits(local.day)}.${_twoDigits(local.month)}.${local.year} ${_twoDigits(local.hour)}:${_twoDigits(local.minute)}';
  }

  String _twoDigits(int value) => value.toString().padLeft(2, '0');
}

class _DateFilterButton extends StatelessWidget {
  const _DateFilterButton({
    required this.label,
    required this.value,
    required this.onPressed,
  });

  final String label;
  final String value;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.calendar_month_rounded),
        label: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelSmall),
            Text(value, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final NotificationStatusValue status;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isRead = status == NotificationStatusValue.read;
    final color = isRead ? colorScheme.secondary : colorScheme.tertiary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        status.label,
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
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
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
