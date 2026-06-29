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
  ReservationsReportPreview? _reservationsPreview;
  bool _isReservationsDownloading = false;
  bool _isReservationsPreviewLoading = true;
  String? _reservationsError;
  String? _reservationsPreviewError;

  PaymentReportStatus? _paymentStatus;
  DateTime? _paymentFrom;
  DateTime? _paymentTo;
  SavedReportFile? _lastPaymentsReport;
  PaymentsReportPreview? _paymentsPreview;
  bool _isPaymentsDownloading = false;
  bool _isPaymentsPreviewLoading = true;
  String? _paymentsError;
  String? _paymentsPreviewError;

  @override
  void initState() {
    super.initState();
    _loadReservationsPreview();
    _loadPaymentsPreview();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final reservationCard = _buildReservationsCard();
        final paymentCard = _buildPaymentsCard();

        if (constraints.maxWidth >= 1180) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: reservationCard),
              const SizedBox(width: 16),
              Expanded(child: paymentCard),
            ],
          );
        }

        return ListView(
          children: [
            reservationCard,
            const SizedBox(height: 16),
            paymentCard,
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
              'Prije downloada dobijate preview broja rezervacija, iznosa i nekoliko zadnjih stavki koje ulaze u izvjestaj.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 18),
            _buildReservationFilters(),
            const SizedBox(height: 18),
            _buildReservationPreviewPanel(),
            const SizedBox(height: 18),
            _buildActionRow(
              isDownloading: _isReservationsDownloading,
              onDownload: _downloadReservationsReport,
              onReset: _resetReservationFilters,
              onRefreshPreview: _loadReservationsPreview,
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
              'Preview prikazuje koliko payment stavki odgovara filteru, stanje po statusima i koje valute trenutno ulaze u PDF.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 18),
            _buildPaymentFilters(),
            const SizedBox(height: 18),
            _buildPaymentsPreviewPanel(),
            const SizedBox(height: 18),
            _buildActionRow(
              isDownloading: _isPaymentsDownloading,
              onDownload: _downloadPaymentsReport,
              onReset: _resetPaymentFilters,
              onRefreshPreview: _loadPaymentsPreview,
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
        DropdownButtonFormField<ReservationReportStatus?>(
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
            _loadReservationsPreview();
          },
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
                      _loadReservationsPreview();
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
                      _loadReservationsPreview();
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
        DropdownButtonFormField<PaymentReportStatus?>(
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
            _loadPaymentsPreview();
          },
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
                      _loadPaymentsPreview();
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
                      _loadPaymentsPreview();
                    },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildReservationPreviewPanel() {
    if (_isReservationsPreviewLoading) {
      return const _PreviewStatePanel(
        icon: Icons.hourglass_top_rounded,
        title: 'Ucitavanje preview-a',
        message: 'Pripremamo pregled rezervacija za odabrane filtere.',
        isLoading: true,
      );
    }

    if (_reservationsPreviewError != null) {
      return _PreviewStatePanel(
        icon: Icons.cloud_off_rounded,
        title: 'Preview nije dostupan',
        message: _reservationsPreviewError!,
      );
    }

    final preview = _reservationsPreview;
    if (preview == null) {
      return const _PreviewStatePanel(
        icon: Icons.info_outline_rounded,
        title: 'Preview nije ucitan',
        message: 'Kliknite "Osvjezi preview" da povucemo pregled.',
      );
    }

    return _PreviewPanel(
      title: 'Preview',
      updatedAtLabel: _formatDateTime(preview.generatedAtLocal),
      metrics: [
        _PreviewMetric(
          label: 'Rezervacije',
          value: preview.totalReservations.toString(),
        ),
        _PreviewMetric(
          label: 'Placene',
          value: preview.paidReservations.toString(),
        ),
        _PreviewMetric(
          label: 'Neplacene',
          value: preview.unpaidReservations.toString(),
        ),
        _PreviewMetric(
          label: 'Sjedista',
          value: preview.totalSeats.toString(),
        ),
      ],
      amounts: preview.amounts,
      emptyMessage:
          'Nema rezervacija za trenutne filtere. PDF ce sadrzavati samo zaglavlje i poruku da nema podataka.',
      sampleItems: preview.sampleItems
          .map(
            (item) => _PreviewSampleRow(
              title: item.reservationCode,
              subtitle:
                  '${_safeText(item.customerName)} • ${item.routeCode} • ${item.statusLabel}',
              meta:
                  '${item.amount.toStringAsFixed(2)} ${item.currency} • ${_formatDateTime(item.createdAtUtc.toLocal())}',
            ),
          )
          .toList(),
    );
  }

  Widget _buildPaymentsPreviewPanel() {
    if (_isPaymentsPreviewLoading) {
      return const _PreviewStatePanel(
        icon: Icons.hourglass_top_rounded,
        title: 'Ucitavanje preview-a',
        message: 'Pripremamo pregled payment stavki za odabrane filtere.',
        isLoading: true,
      );
    }

    if (_paymentsPreviewError != null) {
      return _PreviewStatePanel(
        icon: Icons.cloud_off_rounded,
        title: 'Preview nije dostupan',
        message: _paymentsPreviewError!,
      );
    }

    final preview = _paymentsPreview;
    if (preview == null) {
      return const _PreviewStatePanel(
        icon: Icons.info_outline_rounded,
        title: 'Preview nije ucitan',
        message: 'Kliknite "Osvjezi preview" da povucemo pregled.',
      );
    }

    return _PreviewPanel(
      title: 'Preview',
      updatedAtLabel: _formatDateTime(preview.generatedAtLocal),
      metrics: [
        _PreviewMetric(
          label: 'Placanja',
          value: preview.totalPayments.toString(),
        ),
        _PreviewMetric(
          label: 'Paid',
          value: preview.paidPayments.toString(),
        ),
        _PreviewMetric(
          label: 'Refunded',
          value: preview.refundedPayments.toString(),
        ),
        _PreviewMetric(
          label: 'Pending / Failed',
          value: '${preview.pendingPayments} / ${preview.failedPayments}',
        ),
      ],
      amounts: preview.amounts,
      emptyMessage:
          'Nema payment stavki za trenutne filtere. PDF ce se svejedno generisati, ali bez konkretnih redova.',
      sampleItems: preview.sampleItems
          .map(
            (item) => _PreviewSampleRow(
              title: item.reservationCode,
              subtitle:
                  '${_safeText(item.customerName)} • ${item.routeCode} • ${item.statusLabel}',
              meta:
                  '${item.amount.toStringAsFixed(2)} ${item.currency} • ${_formatDateTime(item.createdAtUtc.toLocal())}',
            ),
          )
          .toList(),
    );
  }

  Widget _buildActionRow({
    required bool isDownloading,
    required Future<void> Function() onDownload,
    required VoidCallback onReset,
    required Future<void> Function() onRefreshPreview,
    required VoidCallback? onOpenFolder,
    required String downloadLabel,
  }) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        FilledButton.icon(
          onPressed: isDownloading ? null : onDownload,
          icon: isDownloading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.download_rounded),
          label: Text(downloadLabel),
        ),
        OutlinedButton.icon(
          onPressed: isDownloading ? null : onRefreshPreview,
          icon: const Icon(Icons.preview_rounded),
          label: const Text('Osvjezi preview'),
        ),
        OutlinedButton.icon(
          onPressed: isDownloading ? null : onReset,
          icon: const Icon(Icons.filter_alt_off_rounded),
          label: const Text('Ocisti filtere'),
        ),
        OutlinedButton.icon(
          onPressed: isDownloading ? null : onOpenFolder,
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

  Future<void> _loadReservationsPreview() async {
    final rangeError = _validateRangeSilently(_reservationFrom, _reservationTo);
    if (rangeError != null) {
      setState(() {
        _reservationsPreviewError = rangeError;
        _isReservationsPreviewLoading = false;
        _reservationsPreview = null;
      });
      return;
    }

    setState(() {
      _isReservationsPreviewLoading = true;
      _reservationsPreviewError = null;
    });

    try {
      final preview = await _service.loadReservationsPreview(
        token: widget.token,
        status: _reservationStatus,
        createdFromLocal: _reservationFrom,
        createdToLocal: _reservationTo,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _reservationsPreview = preview;
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _reservationsPreviewError = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _reservationsPreviewError =
            'Preview rezervacija trenutno nije moguce ucitati.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isReservationsPreviewLoading = false;
        });
      }
    }
  }

  Future<void> _loadPaymentsPreview() async {
    final rangeError = _validateRangeSilently(_paymentFrom, _paymentTo);
    if (rangeError != null) {
      setState(() {
        _paymentsPreviewError = rangeError;
        _isPaymentsPreviewLoading = false;
        _paymentsPreview = null;
      });
      return;
    }

    setState(() {
      _isPaymentsPreviewLoading = true;
      _paymentsPreviewError = null;
    });

    try {
      final preview = await _service.loadPaymentsPreview(
        token: widget.token,
        status: _paymentStatus,
        createdFromLocal: _paymentFrom,
        createdToLocal: _paymentTo,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _paymentsPreview = preview;
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _paymentsPreviewError = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _paymentsPreviewError =
            'Preview placanja trenutno nije moguce ucitati.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isPaymentsPreviewLoading = false;
        });
      }
    }
  }

  Future<void> _downloadReservationsReport() async {
    if (!_validateRangeForAction(_reservationFrom, _reservationTo)) {
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
    if (!_validateRangeForAction(_paymentFrom, _paymentTo)) {
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
    await _loadReservationsPreview();
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
    await _loadPaymentsPreview();
  }

  void _resetReservationFilters() {
    setState(() {
      _reservationStatus = null;
      _reservationFrom = null;
      _reservationTo = null;
      _reservationsError = null;
      _reservationsPreviewError = null;
    });
    _loadReservationsPreview();
  }

  void _resetPaymentFilters() {
    setState(() {
      _paymentStatus = null;
      _paymentFrom = null;
      _paymentTo = null;
      _paymentsError = null;
      _paymentsPreviewError = null;
    });
    _loadPaymentsPreview();
  }

  String? _validateRangeSilently(DateTime? from, DateTime? to) {
    if (from != null && to != null && from.isAfter(to)) {
      return 'Datum "from" mora biti manji ili jednak datumu "to".';
    }

    return null;
  }

  bool _validateRangeForAction(DateTime? from, DateTime? to) {
    final errorMessage = _validateRangeSilently(from, to);
    if (errorMessage == null) {
      return true;
    }

    _showMessage(errorMessage);
    return false;
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

  String _safeText(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? '-' : trimmed;
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

class _PreviewStatePanel extends StatelessWidget {
  const _PreviewStatePanel({
    required this.icon,
    required this.title,
    required this.message,
    this.isLoading = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isLoading)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(icon),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(message),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewPanel extends StatelessWidget {
  const _PreviewPanel({
    required this.title,
    required this.updatedAtLabel,
    required this.metrics,
    required this.amounts,
    required this.sampleItems,
    required this.emptyMessage,
  });

  final String title;
  final String updatedAtLabel;
  final List<_PreviewMetric> metrics;
  final List<ReportAmountSummary> amounts;
  final List<_PreviewSampleRow> sampleItems;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title, style: theme.textTheme.titleMedium),
              const Spacer(),
              Text(
                'Osvjezeno: $updatedAtLabel',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: metrics.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              mainAxisExtent: 78,
            ),
            itemBuilder: (context, index) {
              final metric = metrics[index];
              return _MetricCard(metric: metric);
            },
          ),
          const SizedBox(height: 12),
          Text(
            'Ukupno po valutama',
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          if (amounts.isEmpty)
            Text(
              'Nema iznosa za prikaz.',
              style: theme.textTheme.bodyMedium,
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: amounts
                  .map(
                    (amount) => Chip(
                      label: Text(
                        '${amount.amount.toStringAsFixed(2)} ${amount.currency}',
                      ),
                    ),
                  )
                  .toList(),
            ),
          const SizedBox(height: 16),
          Text(
            'Uzorak stavki',
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          if (sampleItems.isEmpty)
            Text(
              emptyMessage,
              style: theme.textTheme.bodyMedium,
            )
          else
            Column(
              children: sampleItems
                  .map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _PreviewSampleTile(item: item),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class _PreviewMetric {
  const _PreviewMetric({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.metric});

  final _PreviewMetric metric;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            metric.label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          Text(
            metric.value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewSampleRow {
  const _PreviewSampleRow({
    required this.title,
    required this.subtitle,
    required this.meta,
  });

  final String title;
  final String subtitle;
  final String meta;
}

class _PreviewSampleTile extends StatelessWidget {
  const _PreviewSampleTile({required this.item});

  final _PreviewSampleRow item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(item.subtitle),
          const SizedBox(height: 4),
          Text(
            item.meta,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
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
