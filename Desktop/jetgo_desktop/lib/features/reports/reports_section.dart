import 'package:flutter/material.dart';

import '../../core/network/api_exception.dart';
import 'reports_models.dart';
import 'reports_service.dart';

class ReportsSection extends StatefulWidget {
  const ReportsSection({required this.token, super.key});

  final String token;

  @override
  State<ReportsSection> createState() => _ReportsSectionState();
}

class _ReportsSectionState extends State<ReportsSection> {
  final ReportsService _service = ReportsService();

  ReservationReportStatus? _reservationStatus;
  DateTime? _reservationFrom;
  DateTime? _reservationTo;
  SavedReportFile? _lastReservationsReport;
  bool _isReservationsDownloading = false;
  String? _reservationsError;

  PaymentReportStatus? _paymentStatus;
  DateTime? _paymentFrom;
  DateTime? _paymentTo;
  SavedReportFile? _lastPaymentsReport;
  bool _isPaymentsDownloading = false;
  String? _paymentsError;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cards = <Widget>[
          Expanded(
            child: _buildReservationsCard(),
          ),
          Expanded(
            child: _buildPaymentsCard(),
          ),
        ];

        if (constraints.maxWidth >= 1180) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              cards[0],
              const SizedBox(width: 16),
              cards[1],
            ],
          );
        }

        return ListView(
          children: [
            _buildReservationsCard(),
            const SizedBox(height: 16),
            _buildPaymentsCard(),
          ],
        );
      },
    );
  }

  Widget _buildReservationsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reservations PDF',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Izvjestaj generise backend i vraca PDF sa rezervacijama, ukupnim iznosom i aktivnim filterima.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 18),
            _buildReservationFilters(),
            const SizedBox(height: 18),
            _buildActionRow(
              isLoading: _isReservationsDownloading,
              onDownload: _downloadReservationsReport,
              onReset: _resetReservationFilters,
              onOpenFolder: _lastReservationsReport == null
                  ? null
                  : () => _openFolder(_lastReservationsReport!),
              downloadLabel: 'Preuzmi reservations report',
            ),
            const SizedBox(height: 18),
            _buildResultPanel(
              errorMessage: _reservationsError,
              file: _lastReservationsReport,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Payments PDF',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Izvjestaj sabira payment workflow, paid/refunded statistiku i vraca ga kao PDF spreman za seminarski prilog.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 18),
            _buildPaymentFilters(),
            const SizedBox(height: 18),
            _buildActionRow(
              isLoading: _isPaymentsDownloading,
              onDownload: _downloadPaymentsReport,
              onReset: _resetPaymentFilters,
              onOpenFolder: _lastPaymentsReport == null
                  ? null
                  : () => _openFolder(_lastPaymentsReport!),
              downloadLabel: 'Preuzmi payments report',
            ),
            const SizedBox(height: 18),
            _buildResultPanel(
              errorMessage: _paymentsError,
              file: _lastPaymentsReport,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReservationFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<ReservationReportStatus?>(
                key: ValueKey<ReservationReportStatus?>(_reservationStatus),
                initialValue: _reservationStatus,
                decoration: const InputDecoration(
                  labelText: 'Status rezervacije',
                ),
                items: [
                  const DropdownMenuItem<ReservationReportStatus?>(
                    value: null,
                    child: Text('Svi statusi'),
                  ),
                  ...ReservationReportStatus.values.map(
                    (status) => DropdownMenuItem<ReservationReportStatus?>(
                      value: status,
                      child: Text(status.label),
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _reservationStatus = value;
                  });
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _DateChip(
              label: 'Created from',
              value: _reservationFrom,
              onTap: () => _pickReservationDate(isFrom: true),
              onClear: _reservationFrom == null
                  ? null
                  : () {
                      setState(() {
                        _reservationFrom = null;
                      });
                    },
            ),
            _DateChip(
              label: 'Created to',
              value: _reservationTo,
              onTap: () => _pickReservationDate(isFrom: false),
              onClear: _reservationTo == null
                  ? null
                  : () {
                      setState(() {
                        _reservationTo = null;
                      });
                    },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPaymentFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<PaymentReportStatus?>(
                key: ValueKey<PaymentReportStatus?>(_paymentStatus),
                initialValue: _paymentStatus,
                decoration: const InputDecoration(
                  labelText: 'Status placanja',
                ),
                items: [
                  const DropdownMenuItem<PaymentReportStatus?>(
                    value: null,
                    child: Text('Svi statusi'),
                  ),
                  ...PaymentReportStatus.values.map(
                    (status) => DropdownMenuItem<PaymentReportStatus?>(
                      value: status,
                      child: Text(status.label),
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _paymentStatus = value;
                  });
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _DateChip(
              label: 'Created from',
              value: _paymentFrom,
              onTap: () => _pickPaymentDate(isFrom: true),
              onClear: _paymentFrom == null
                  ? null
                  : () {
                      setState(() {
                        _paymentFrom = null;
                      });
                    },
            ),
            _DateChip(
              label: 'Created to',
              value: _paymentTo,
              onTap: () => _pickPaymentDate(isFrom: false),
              onClear: _paymentTo == null
                  ? null
                  : () {
                      setState(() {
                        _paymentTo = null;
                      });
                    },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionRow({
    required bool isLoading,
    required Future<void> Function() onDownload,
    required VoidCallback onReset,
    required VoidCallback? onOpenFolder,
    required String downloadLabel,
  }) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        FilledButton.icon(
          onPressed: isLoading ? null : onDownload,
          icon: isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.download_rounded),
          label: Text(downloadLabel),
        ),
        OutlinedButton.icon(
          onPressed: isLoading ? null : onReset,
          icon: const Icon(Icons.filter_alt_off_rounded),
          label: const Text('Ocisti filtere'),
        ),
        OutlinedButton.icon(
          onPressed: isLoading ? null : onOpenFolder,
          icon: const Icon(Icons.folder_open_rounded),
          label: const Text('Otvori folder'),
        ),
      ],
    );
  }

  Widget _buildResultPanel({
    required String? errorMessage,
    required SavedReportFile? file,
  }) {
    final theme = Theme.of(context);

    if (errorMessage != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          errorMessage,
          style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
        ),
      );
    }

    if (file == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'PDF jos nije preuzet. Nakon downloada bice sacuvan u Downloads/JetGoReports.',
          style: theme.textTheme.bodyMedium,
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            file.fileName,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          _ResultRow('Sacuvano', _formatDateTime(file.savedAtLocal)),
          _ResultRow('Lokacija', file.filePath),
          _ResultRow('Content type', file.contentType),
        ],
      ),
    );
  }

  Future<void> _downloadReservationsReport() async {
    if (!_validateRange(_reservationFrom, _reservationTo)) {
      return;
    }

    setState(() {
      _isReservationsDownloading = true;
      _reservationsError = null;
    });

    try {
      final file = await _service.downloadReservationsReport(
        token: widget.token,
        status: _reservationStatus,
        createdFromLocal: _reservationFrom,
        createdToLocal: _reservationTo,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _lastReservationsReport = file;
      });
      _showMessage('Reservations report je sacuvan u JetGoReports folder.');
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _reservationsError = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _reservationsError =
            'Reservations report trenutno nije moguce preuzeti.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isReservationsDownloading = false;
        });
      }
    }
  }

  Future<void> _downloadPaymentsReport() async {
    if (!_validateRange(_paymentFrom, _paymentTo)) {
      return;
    }

    setState(() {
      _isPaymentsDownloading = true;
      _paymentsError = null;
    });

    try {
      final file = await _service.downloadPaymentsReport(
        token: widget.token,
        status: _paymentStatus,
        createdFromLocal: _paymentFrom,
        createdToLocal: _paymentTo,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _lastPaymentsReport = file;
      });
      _showMessage('Payments report je sacuvan u JetGoReports folder.');
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _paymentsError = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _paymentsError = 'Payments report trenutno nije moguce preuzeti.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isPaymentsDownloading = false;
        });
      }
    }
  }

  Future<void> _openFolder(SavedReportFile file) async {
    try {
      await _service.openContainingFolder(file.filePath);
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showMessage('Folder sa izvjestajem nije moguce otvoriti automatski.');
    }
  }

  Future<void> _pickReservationDate({required bool isFrom}) async {
    final initialDate = isFrom
        ? (_reservationFrom ?? DateTime.now())
        : (_reservationTo ?? _reservationFrom ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      if (isFrom) {
        _reservationFrom = picked;
      } else {
        _reservationTo = picked;
      }
    });
  }

  Future<void> _pickPaymentDate({required bool isFrom}) async {
    final initialDate = isFrom
        ? (_paymentFrom ?? DateTime.now())
        : (_paymentTo ?? _paymentFrom ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      if (isFrom) {
        _paymentFrom = picked;
      } else {
        _paymentTo = picked;
      }
    });
  }

  void _resetReservationFilters() {
    setState(() {
      _reservationStatus = null;
      _reservationFrom = null;
      _reservationTo = null;
      _reservationsError = null;
    });
  }

  void _resetPaymentFilters() {
    setState(() {
      _paymentStatus = null;
      _paymentFrom = null;
      _paymentTo = null;
      _paymentsError = null;
    });
  }

  bool _validateRange(DateTime? from, DateTime? to) {
    if (from != null && to != null && from.isAfter(to)) {
      _showMessage('Datum "from" mora biti manji ili jednak datumu "to".');
      return false;
    }

    return true;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day.$month.${local.year} $hour:$minute';
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({
    required this.label,
    required this.value,
    required this.onTap,
    required this.onClear,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final day = value?.day.toString().padLeft(2, '0');
    final month = value?.month.toString().padLeft(2, '0');
    final dateLabel = value == null
        ? 'Odaberite datum'
        : '$day.$month.${value!.year}';

    return Container(
      constraints: const BoxConstraints(minWidth: 220),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: onTap,
            icon: const Icon(Icons.calendar_month_rounded),
            tooltip: label,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(dateLabel, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
          if (onClear != null)
            IconButton(
              onPressed: onClear,
              icon: const Icon(Icons.close_rounded),
              tooltip: 'Ocisti datum',
            ),
        ],
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 84,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
