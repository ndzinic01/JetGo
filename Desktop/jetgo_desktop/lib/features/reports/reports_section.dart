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
  final Map<BusinessReportType, SavedReportFile> _lastReports = {};
  final Set<BusinessReportType> _busyReports = {};
  final Set<BusinessReportType> _printingReports = {};

  DateTime? _from;
  DateTime? _to;
  ReportFileFormat _format = ReportFileFormat.pdf;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 1180
            ? 2
            : 1;

        return ListView(
          padding: EdgeInsets.zero,
          children: [
            _buildHeaderCard(),
            const SizedBox(height: 16),
            _buildFiltersCard(),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              _buildErrorPanel(_errorMessage!),
            ],
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: BusinessReportType.values.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                mainAxisExtent: 310,
              ),
              itemBuilder: (context, index) {
                final type = BusinessReportType.values[index];
                return _buildReportCard(type);
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeaderCard() {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.analytics_rounded,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Poslovni izvjestaji',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Generisanje prijavljenih PDF izvjestaja za prodaju, popunjenost letova, finansije i korisnike.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFiltersCard() {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Parametri izvjestaja',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _DateChip(
                  label: 'Period od',
                  value: _from,
                  onTap: () => _pickDate(isFrom: true),
                  onClear: _from == null
                      ? null
                      : () {
                          setState(() {
                            _from = null;
                            _errorMessage = null;
                          });
                        },
                ),
                _DateChip(
                  label: 'Period do',
                  value: _to,
                  onTap: () => _pickDate(isFrom: false),
                  onClear: _to == null
                      ? null
                      : () {
                          setState(() {
                            _to = null;
                            _errorMessage = null;
                          });
                        },
                ),
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<ReportFileFormat>(
                    initialValue: _format,
                    decoration: const InputDecoration(
                      labelText: 'Format',
                      prefixIcon: Icon(Icons.picture_as_pdf_rounded),
                    ),
                    items: ReportFileFormat.values
                        .map(
                          (format) => DropdownMenuItem<ReportFileFormat>(
                            value: format,
                            child: Text(format.label),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }

                      setState(() {
                        _format = value;
                      });
                    },
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _resetFilters,
                  icon: const Icon(Icons.filter_alt_off_rounded),
                  label: const Text('Ocisti'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportCard(BusinessReportType type) {
    final theme = Theme.of(context);
    final isBusy = _busyReports.contains(type);
    final isPrinting = _printingReports.contains(type);
    final lastFile = _lastReports[type];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _iconFor(type),
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        type.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        type.description,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Spacer(),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: isBusy || isPrinting
                      ? null
                      : () => _downloadReport(type),
                  icon: isBusy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download_rounded),
                  label: const Text('Preuzmi'),
                ),
                OutlinedButton.icon(
                  onPressed: isBusy || isPrinting
                      ? null
                      : () => _printReport(type),
                  icon: isPrinting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.print_rounded),
                  label: const Text('Ispisi'),
                ),
                OutlinedButton.icon(
                  onPressed: lastFile == null || isBusy || isPrinting
                      ? null
                      : () => _openFolder(lastFile),
                  icon: const Icon(Icons.folder_open_rounded),
                  label: const Text('Folder'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _buildLastFilePanel(lastFile),
          ],
        ),
      ),
    );
  }

  Widget _buildLastFilePanel(SavedReportFile? file) {
    final theme = Theme.of(context);

    if (file == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'PDF jos nije generisan za odabrani izvjestaj.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            file.fileName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Sacuvano: ${_formatDateTime(file.savedAtLocal)}',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorPanel(String message) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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

  Future<void> _downloadReport(BusinessReportType type) async {
    if (!_validatePeriod()) {
      return;
    }

    setState(() {
      _busyReports.add(type);
      _errorMessage = null;
    });

    try {
      final file = await _service.downloadReport(
        token: widget.token,
        type: type,
        format: _format,
        fromLocal: _from,
        toLocal: _to,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _lastReports[type] = file;
      });
      _showMessage('${type.title} je sacuvan u JetGoReports folder.');
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
        _errorMessage = '${type.title} trenutno nije moguce generisati.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _busyReports.remove(type);
        });
      }
    }
  }

  Future<void> _printReport(BusinessReportType type) async {
    if (!_validatePeriod()) {
      return;
    }

    setState(() {
      _printingReports.add(type);
      _errorMessage = null;
    });

    try {
      final file = await _service.downloadReport(
        token: widget.token,
        type: type,
        format: _format,
        fromLocal: _from,
        toLocal: _to,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _lastReports[type] = file;
      });

      await _service.printReport(file.filePath);

      if (!mounted) {
        return;
      }

      _showMessage('${type.title} je poslan na ispis.');
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
        _errorMessage = 'PDF je generisan, ali ga nije moguce automatski poslati na ispis.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _printingReports.remove(type);
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

  Future<void> _pickDate({required bool isFrom}) async {
    final initialDate = isFrom
        ? (_from ?? DateTime.now())
        : (_to ?? _from ?? DateTime.now());
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
        _from = picked;
      } else {
        _to = picked;
      }
      _errorMessage = null;
    });
  }

  bool _validatePeriod() {
    if (_from != null && _to != null && _from!.isAfter(_to!)) {
      setState(() {
        _errorMessage = 'Datum "Period do" mora biti veci ili jednak datumu "Period od".';
      });
      return false;
    }

    return true;
  }

  void _resetFilters() {
    setState(() {
      _from = null;
      _to = null;
      _format = ReportFileFormat.pdf;
      _errorMessage = null;
    });
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

  IconData _iconFor(BusinessReportType type) {
    return switch (type) {
      BusinessReportType.sales => Icons.trending_up_rounded,
      BusinessReportType.occupancy => Icons.event_seat_rounded,
      BusinessReportType.financial => Icons.account_balance_wallet_rounded,
      BusinessReportType.users => Icons.group_rounded,
    };
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
    final dateLabel = value == null ? 'Odaberite datum' : '$day.$month.${value!.year}';

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
