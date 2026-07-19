import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/network/api_exception.dart';
import 'payments_models.dart';
import 'payments_service.dart';

class PaymentsSection extends StatefulWidget {
  const PaymentsSection({required this.token, super.key});

  final String token;

  @override
  State<PaymentsSection> createState() => _PaymentsSectionState();
}

class _PaymentsSectionState extends State<PaymentsSection> {
  final PaymentsService _service = PaymentsService();
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  bool _isLoading = true;
  bool _isDetailsLoading = false;
  bool _isDebugLoading = false;
  String? _errorMessage;
  String? _detailsErrorMessage;
  String? _debugErrorMessage;

  List<PaymentItem> _payments = const [];
  PaymentDetails? _selectedDetails;
  int? _selectedPaymentId;
  PaymentStatusValue? _statusFilter;
  PayPalDebugSnapshot? _debugSnapshot;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearchChanged);
    _loadPayments();
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

      _loadPayments(showLoader: false);
    });
  }

  Future<void> _loadPayments({bool showLoader = true}) async {
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
      final response = await _service.fetchPayments(
        token: widget.token,
        searchText: _searchController.text,
        status: _statusFilter,
      );

      _payments = response.items;

      if (_payments.isEmpty) {
        _selectedPaymentId = null;
        _selectedDetails = null;
        _detailsErrorMessage = null;
        _debugSnapshot = null;
        _debugErrorMessage = null;
      } else {
        final selectedExists = _selectedPaymentId != null &&
            _payments.any((item) => item.id == _selectedPaymentId);
        final nextId = selectedExists ? _selectedPaymentId! : _payments.first.id;
        await _loadPaymentDetails(nextId, showLoader: false);
      }
    } on ApiException catch (error) {
      _errorMessage = error.message;
    } catch (_) {
      _errorMessage = 'Placanja trenutno nisu dostupna. Pokusajte ponovo.';
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadPaymentDetails(
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
      final details = await _service.getPayment(
        token: widget.token,
        id: id,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _selectedPaymentId = id;
        _selectedDetails = details;
        _debugSnapshot = null;
        _debugErrorMessage = null;
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
        _detailsErrorMessage = 'Detalji placanja trenutno nisu dostupni.';
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
    await _loadPayments();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _openRefundDialog() async {
    final details = _selectedDetails;
    if (details == null) {
      return;
    }

    final reason = await showDialog<String>(
      context: context,
      builder: (context) => _RefundDialog(
        reservationCode: details.reservationCode,
        amountLabel:
            '${details.amount.toStringAsFixed(2)} ${details.currency}',
      ),
    );

    if (reason == null) {
      return;
    }

    try {
      final updated = await _service.refundPayment(
        token: widget.token,
        id: details.id,
        reason: reason,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _selectedDetails = updated;
        _debugSnapshot = null;
        _debugErrorMessage = null;
      });
      await _loadPayments(showLoader: false);
      _showMessage('Placanje je uspjesno refundirano.');
    } on ApiException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Refund trenutno nije dostupan.');
    }
  }

  Future<void> _openDebugDialog() async {
    final details = _selectedDetails;
    if (details == null) {
      return;
    }

    setState(() {
      _isDebugLoading = true;
      _debugErrorMessage = null;
    });

    try {
      final snapshot = await _service.getPayPalDebugSnapshot(
        token: widget.token,
        id: details.id,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _debugSnapshot = snapshot;
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _debugErrorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _debugErrorMessage = 'PayPal debug trenutno nije dostupan.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isDebugLoading = false;
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
                onSubmitted: (_) => _loadPayments(),
                decoration: const InputDecoration(
                  labelText: 'Pretraga placanja',
                  hintText: 'Kod rezervacije, kupac, servis ili ruta',
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
            child: DropdownButtonFormField<PaymentStatusValue?>(
              key: ValueKey<PaymentStatusValue?>(_statusFilter),
              initialValue: _statusFilter,
              decoration: const InputDecoration(labelText: 'Status'),
              items: [
                const DropdownMenuItem<PaymentStatusValue?>(
                  value: null,
                  child: Text('Svi statusi'),
                ),
                ...PaymentStatusValue.values.map(
                  (status) => DropdownMenuItem<PaymentStatusValue?>(
                    value: status,
                    child: Text(status.label),
                  ),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _statusFilter = value;
                });
                _loadPayments();
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
        title: 'Nije moguce ucitati placanja',
        message: _errorMessage!,
      );
    }

    if (_payments.isEmpty) {
      return const _CenteredMessage(
        icon: Icons.payments_outlined,
        title: 'Nema placanja za prikaz',
        message: 'Pokusajte druge filtere ili pretragu.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Placanja (${_payments.length})',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        Expanded(
          child: SingleChildScrollView(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Rezervacija')),
                  DataColumn(label: Text('Kupac')),
                  DataColumn(label: Text('Let')),
                  DataColumn(label: Text('Ruta')),
                  DataColumn(label: Text('Servis')),
                  DataColumn(label: Text('Iznos')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Kreirano')),
                  DataColumn(label: Text('Placeno u')),
                ],
                rows: _payments.map((item) {
                  final isSelected = item.id == _selectedPaymentId;
                  return DataRow(
                    selected: isSelected,
                    onSelectChanged: (_) => _loadPaymentDetails(item.id),
                    cells: [
                      DataCell(Text(item.reservationCode)),
                      DataCell(
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 180),
                          child: Text(
                            item.customerName.trim().isEmpty
                                ? '-'
                                : item.customerName,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      DataCell(Text(item.flightNumber)),
                      DataCell(Text(item.routeCode)),
                      DataCell(Text(item.provider)),
                      DataCell(
                        Text('${item.amount.toStringAsFixed(2)} ${item.currency}'),
                      ),
                      DataCell(Text(item.status.label)),
                      DataCell(Text(_formatDateTime(item.createdAtUtc))),
                      DataCell(Text(_formatDateTime(item.paidAtUtc))),
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
        title: 'Odaberite placanje',
        message: 'Kliknite red iz tabele da otvorite detalje i dostupne akcije.',
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
                    details.reservationCode,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  Text('${details.flightNumber} - ${details.routeCode}'),
                  const SizedBox(height: 4),
                  Text(details.customer.fullName),
                ],
              ),
            ),
            _StatusBadge(label: details.status.label),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            if (details.canBeRefunded)
              FilledButton.icon(
                onPressed: _openRefundDialog,
                icon: const Icon(Icons.reply_all_rounded),
                label: const Text('Refundiraj'),
              ),
            FilledButton.tonalIcon(
              onPressed: _openDebugDialog,
              icon: const Icon(Icons.bug_report_rounded),
              label: const Text('PayPal provjera'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Expanded(
          child: ListView(
            children: [
              _DetailsBlock(
                title: 'Placanje',
                rows: [
                  _DetailsRow('ID placanja', details.id.toString()),
                  _DetailsRow('Servis placanja', details.provider),
                  _DetailsRow(
                    'Iznos',
                    '${details.amount.toStringAsFixed(2)} ${details.currency}',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _DetailsBlock(
                title: 'Status i timeline',
                rows: [
                  _DetailsRow('Status', details.status.label),
                  _DetailsRow('Kreirano', _formatDateTime(details.createdAtUtc)),
                  _DetailsRow('Azurirano', _formatDateTime(details.updatedAtUtc)),
                  _DetailsRow('Placeno u', _formatDateTime(details.paidAtUtc)),
                  _DetailsRow(
                    'Refundirano u',
                    _formatDateTime(details.refundedAtUtc),
                  ),
                  _DetailsRow(
                    'Moze povrat',
                    details.canBeRefunded ? 'Da' : 'Ne',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _DetailsBlock(
                title: 'Kupac',
                rows: [
                  _DetailsRow('Ime i prezime', details.customer.fullName),
                  _DetailsRow('Korisnicko ime', '@${details.customer.username}'),
                  _DetailsRow('Email', details.customer.email),
                  _DetailsRow('ID korisnika', details.customer.userId),
                ],
              ),
              const SizedBox(height: 16),
              _DetailsBlock(
                title: 'Razlog statusa',
                rows: [
                  _DetailsRow(
                    'Napomena',
                    (details.statusReason?.trim().isNotEmpty ?? false)
                        ? details.statusReason!
                        : '-',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildDebugBlock(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDebugBlock() {
    if (_isDebugLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_debugErrorMessage != null) {
      return _DetailsBlock(
        title: 'PayPal provjera',
        rows: [
          _DetailsRow('Greska', _debugErrorMessage!),
        ],
      );
    }

    final debug = _debugSnapshot;
    if (debug == null) {
      return const _DetailsBlock(
        title: 'PayPal provjera',
        rows: [
          _DetailsRow(
            'Stanje',
            'Debug snapshot nije ucitan. Kliknite "PayPal provjera" za provjeru.',
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ..._buildDebugSummaryRows(debug),
        _DetailsBlock(
          title: 'PayPal provjera',
          rows: _buildDebugPrimaryRows(debug),
        ),
        const SizedBox(height: 12),
        _DetailsBlock(
          title: 'Capture zapisi',
          rows: debug.captures.isEmpty
              ? const [_DetailsRow('Capture zapisi', 'Nema capture zapisa.')]
              : debug.captures
                  .map(
                    (capture) => _DetailsRow(
                      capture.id,
                      '${_localizePayPalStatus(capture.status)} - ${capture.amount.toStringAsFixed(2)} ${capture.currency} - ${_formatDateTime(capture.createTimeUtc)}',
                    ),
                  )
                  .toList(),
        ),
      ],
    );
  }

  List<Widget> _buildDebugSummaryRows(PayPalDebugSnapshot debug) {
    if (debug.debugNote == null || debug.debugNote!.trim().isEmpty) {
      return const [];
    }

    return [
      _DetailsBlock(
        title: 'Napomena',
        rows: [
          _DetailsRow('Info', debug.debugNote!),
        ],
      ),
      const SizedBox(height: 12),
    ];
  }

  List<_DetailsRow> _buildDebugPrimaryRows(PayPalDebugSnapshot debug) {
    final isCapture = debug.payPalResourceType.toLowerCase() == 'capture';
    final resourceIdLabel = isCapture ? 'ID capture zapisa' : 'ID narudzbe';
    final resourceStatusLabel =
        isCapture ? 'Status capture zapisa' : 'Status narudzbe';

    return [
      _DetailsRow('Tip resursa', _localizePayPalResourceType(debug.payPalResourceType)),
      _DetailsRow(resourceIdLabel, debug.payPalOrderId),
      _DetailsRow(resourceStatusLabel, _localizePayPalStatus(debug.payPalOrderStatus)),
      _DetailsRow('Status placanja', debug.paymentStatus.label),
      _DetailsRow('Status rezervacije', debug.reservationStatus.label),
      _DetailsRow(
        'URL odobrenja',
        debug.approvalUrl ?? '-',
        linkUrl: debug.approvalUrl,
      ),
    ];
  }

  String _localizePayPalResourceType(String resourceType) {
    switch (resourceType.trim().toUpperCase()) {
      case 'CAPTURE':
        return 'PayPal naplata';
      case 'ORDER':
        return 'PayPal narudzba';
      default:
        return resourceType;
    }
  }

  String _localizePayPalStatus(String status) {
    switch (status.trim().toUpperCase()) {
      case 'CREATED':
        return 'Kreirano';
      case 'SAVED':
        return 'Sacuvano';
      case 'APPROVED':
        return 'Odobreno';
      case 'COMPLETED':
        return 'Zavrseno';
      case 'VOIDED':
        return 'Ponisteno';
      case 'PAYER_ACTION_REQUIRED':
        return 'Potrebna akcija kupca';
      case 'PENDING':
        return 'Na cekanju';
      case 'DECLINED':
        return 'Odbijeno';
      case 'REFUNDED':
        return 'Refundirano';
      case 'FAILED':
        return 'Neuspjelo';
      default:
        return status;
    }
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(row.value),
                      if (row.linkUrl?.trim().isNotEmpty == true) ...[
                        const SizedBox(height: 6),
                        _OpenLinkButton(url: row.linkUrl!),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DetailsRow {
  const _DetailsRow(this.label, this.value, {this.linkUrl});

  final String label;
  final String value;
  final String? linkUrl;
}

class _OpenLinkButton extends StatelessWidget {
  const _OpenLinkButton({required this.url});

  final String url;

  Future<void> _open(BuildContext context) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Link nije validan za otvaranje.')),
      );
      return;
    }

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Otvaranje linka trenutno nije dostupno.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: () => _open(context),
      icon: const Icon(Icons.open_in_new_rounded, size: 18),
      label: const Text('Otvori'),
      style: TextButton.styleFrom(
        padding: EdgeInsets.zero,
        minimumSize: const Size(0, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        alignment: Alignment.centerLeft,
      ),
    );
  }
}

class _RefundDialog extends StatefulWidget {
  const _RefundDialog({
    required this.reservationCode,
    required this.amountLabel,
  });

  final String reservationCode;
  final String amountLabel;

  @override
  State<_RefundDialog> createState() => _RefundDialogState();
}

class _RefundDialogState extends State<_RefundDialog> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Povrat placanja'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Rezervacija: ${widget.reservationCode}'),
              const SizedBox(height: 4),
              Text('Iznos: ${widget.amountLabel}'),
              const SizedBox(height: 12),
              TextFormField(
                controller: _reasonController,
                minLines: 4,
                maxLines: 8,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: 'Razlog refundiranja',
                  alignLabelWithHint: true,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Razlog refundiranja je obavezan.';
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

            Navigator.of(context).pop(_reasonController.text.trim());
          },
          child: const Text('Potvrdi refund'),
        ),
      ],
    );
  }
}
