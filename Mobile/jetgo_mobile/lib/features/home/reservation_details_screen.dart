import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/network/api_exception.dart';
import 'mobile_data_service.dart';
import 'mobile_display.dart';
import 'mobile_models.dart';

class ReservationDetailsScreen extends StatefulWidget {
  const ReservationDetailsScreen({
    required this.token,
    required this.reservationId,
    this.markDirtyOnPop = false,
    super.key,
  });

  final String token;
  final int reservationId;
  final bool markDirtyOnPop;

  @override
  State<ReservationDetailsScreen> createState() =>
      _ReservationDetailsScreenState();
}

class _ReservationDetailsScreenState extends State<ReservationDetailsScreen> {
  final MobileDataService _dataService = MobileDataService();

  MobileReservationDetails? _details;
  MobilePaymentDetails? _paymentDetails;
  bool _isLoading = true;
  bool _isPaymentSubmitting = false;
  bool _isBaggageSubmitting = false;
  bool _hasOpenedPayPalApproval = false;
  String? _errorMessage;
  bool _markDirtyOnPop = false;

  @override
  void initState() {
    super.initState();
    _markDirtyOnPop = widget.markDirtyOnPop;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final details = await _dataService.fetchReservationDetails(
        token: widget.token,
        reservationId: widget.reservationId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _details = details;
        if (_paymentDetails != null && _paymentDetails!.id != details.paymentId) {
          _paymentDetails = null;
          _hasOpenedPayPalApproval = false;
        }
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
        _errorMessage = 'Detalji rezervacije trenutno nisu dostupni.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<bool>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          Navigator.of(context).pop(_markDirtyOnPop);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Detalji rezervacije'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () {
              Navigator.of(context).pop(_markDirtyOnPop);
            },
          ),
          actions: [
            IconButton(
              tooltip: 'Osvjezi',
              onPressed: _isLoading ? null : _load,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_errorMessage!, textAlign: TextAlign.center),
        ),
      );
    }

    final details = _details;
    if (details == null) {
      return const Center(child: Text('Rezervacija nije pronadjena.'));
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          details.reservationCode,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      _StatusChip(
                        label: MobileDisplay.reservationStatusLabel(
                          details.status,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${MobileDisplay.flightNumberLabel(details.flightNumber)} - ${details.routeCode}',
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${details.departureAirportCode} -> ${details.arrivalAirportCode}',
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Polazak: ${MobileDisplay.formatDateTime(details.departureAtUtc)}',
                  ),
                  Text(
                    'Dolazak: ${MobileDisplay.formatDateTime(details.arrivalAtUtc)}',
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Ukupno: ${MobileDisplay.formatMoney(details.totalAmount, details.currency)}',
                  ),
                  Text(
                    details.isPaid
                        ? 'Placanje je evidentirano.'
                        : 'Placanje jos nije evidentirano.',
                  ),
                  if (_shouldShowPaymentCard(details) &&
                      !details.isPaid &&
                      !_hasPendingPayment(details)) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Rezervacija je spremna za placanje.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (_shouldShowPaymentCard(details)) ...[
            const SizedBox(height: 12),
            _buildPaymentCard(context, details),
          ],
          const SizedBox(height: 12),
          _buildPricingCard(context, details),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Putnik',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  Text(details.customer.fullName),
                  const SizedBox(height: 4),
                  Text(details.customer.email),
                  const SizedBox(height: 4),
                  Text('@${details.customer.username}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildBaggageCard(context, details),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sjedista',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: details.seats
                        .map(
                          (seat) => Chip(
                            label: Text(
                              '${seat.seatNumber} (${MobileDisplay.formatMoney(seat.price, details.currency)})',
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
          ),
          if (details.statusReason != null &&
              details.statusReason!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Napomena',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(details.statusReason!),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPaymentCard(
    BuildContext context,
    MobileReservationDetails details,
  ) {
    final effectivePaymentId = _paymentDetails?.id ?? details.paymentId;
    final effectivePaymentStatus = _paymentDetails?.status ?? details.paymentStatus;
    final paymentStatusLabel =
        MobileDisplay.paymentStatusLabel(effectivePaymentStatus);
    final amount = _paymentDetails?.amount ?? details.totalAmount;
    final currency = _paymentDetails?.currency ?? details.currency;
    final approvalUrl = _paymentDetails?.approvalUrl;
    final hasApprovalUrl = approvalUrl != null && approvalUrl.trim().isNotEmpty;
    final statusReason = _paymentDetails?.statusReason;
    final canInitializePayment =
        !details.isPaid && (details.canInitiatePayment || _hasPendingPayment(details));
    final canConfirmPayment =
        !details.isPaid && effectivePaymentId != null && effectivePaymentStatus == 1;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Placanje',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                _StatusChip(label: paymentStatusLabel),
              ],
            ),
            const SizedBox(height: 12),
            Text('Iznos: ${MobileDisplay.formatMoney(amount, currency)}'),
            Text('Servis placanja: ${_paymentDetails?.provider ?? 'PayPal'}'),
            Text(
              effectivePaymentId == null
                  ? 'Placanje jos nije inicirano.'
                  : 'ID placanja: $effectivePaymentId',
            ),
            if (statusReason != null && statusReason.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(statusReason),
            ],
            if (details.canUpdateBaggage && !details.isPaid) ...[
              const SizedBox(height: 8),
              Text(
                'Ako promijenite dodatni prtljag, ukupni iznos ce se preracunati. Ako je PayPal placanje vec bilo pokrenuto, trebate ga otvoriti ponovo za novi iznos.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (hasApprovalUrl) ...[
              const SizedBox(height: 8),
              Text(
                'Korak 1: otvorite PayPal i odobrite placanje. Kada se vratite u aplikaciju, pojavit ce se korak za zavrsetak placanja.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (!hasApprovalUrl && canConfirmPayment) ...[
              const SizedBox(height: 8),
              Text(
                'Ako ste PayPal odobrenje vec uradili ranije, sada mozete kliknuti "2. Zavrsi placanje".',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 16),
            if (canInitializePayment || canConfirmPayment)
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  if (canInitializePayment)
                    FilledButton.icon(
                      onPressed: _isPaymentSubmitting
                          ? null
                          : hasApprovalUrl
                              ? () => _openApprovalUrl(approvalUrl)
                              : () => _initializePayment(details),
                      icon: _isPaymentSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.open_in_new_rounded),
                      label: Text(
                        hasApprovalUrl
                            ? '1. Otvori PayPal'
                            : _hasPendingPayment(details)
                                ? 'Provjeri PayPal link'
                                : '1. Pokreni PayPal',
                      ),
                    ),
                  if (canConfirmPayment &&
                      (_hasOpenedPayPalApproval || !hasApprovalUrl))
                    OutlinedButton.icon(
                      onPressed: _isPaymentSubmitting
                          ? null
                          : () => _confirmPayment(effectivePaymentId),
                      icon: const Icon(Icons.verified_rounded),
                      label: const Text('2. Zavrsi placanje'),
                    ),
                ],
              )
            else
              Text(
                details.isPaid
                    ? 'Placanje je zavrseno i evidentirano na rezervaciji.'
                    : 'Trenutno nema dostupnih payment akcija za ovu rezervaciju.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPricingCard(
    BuildContext context,
    MobileReservationDetails details,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cijena rezervacije',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Text(
              'Sjedista: ${MobileDisplay.formatMoney(details.seatsTotalAmount, details.currency)}',
            ),
            Text(
              'Ponuda: ${MobileDisplay.baggageOfferLabel(details.additionalBaggageCount)}',
            ),
            Text(
              'Dodatni prtljag: ${MobileDisplay.formatMoney(details.additionalBaggageTotalAmount, details.currency)}',
            ),
            const SizedBox(height: 6),
            Text(
              'Ukupno: ${MobileDisplay.formatMoney(details.totalAmount, details.currency)}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBaggageCard(
    BuildContext context,
    MobileReservationDetails details,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Dodatni prtljag',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (details.canUpdateBaggage)
                  OutlinedButton.icon(
                    onPressed: _isBaggageSubmitting
                        ? null
                        : () => _openBaggageDialog(details),
                    icon: _isBaggageSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.luggage_rounded),
                    label: const Text('Izmijeni'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Ponuda: ${MobileDisplay.baggageOfferLabel(details.additionalBaggageCount)}',
            ),
            Text(
              'Cijena po komadu: ${MobileDisplay.formatMoney(details.additionalBaggageUnitPrice, details.currency)}',
            ),
            Text(
              'Ukupno za prtljag: ${MobileDisplay.formatMoney(details.additionalBaggageTotalAmount, details.currency)}',
            ),
            if (!details.canUpdateBaggage) ...[
              const SizedBox(height: 8),
              Text(
                'Prtljag vise nije moguce mijenjati za ovu rezervaciju.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  bool _shouldShowPaymentCard(MobileReservationDetails details) {
    return details.canInitiatePayment || details.paymentId != null || details.isPaid;
  }

  bool _hasPendingPayment(MobileReservationDetails details) {
    final paymentStatus = _paymentDetails?.status ?? details.paymentStatus;
    return details.paymentId != null && !details.isPaid && paymentStatus == 1;
  }

  Future<void> _initializePayment(MobileReservationDetails details) async {
    setState(() {
      _isPaymentSubmitting = true;
    });

    try {
      final payment = await _dataService.initializePayment(
        token: widget.token,
        reservationId: details.id,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _paymentDetails = payment;
        _hasOpenedPayPalApproval = false;
        _markDirtyOnPop = true;
      });

      final approvalUrl = payment.approvalUrl?.trim();
      if (approvalUrl != null && approvalUrl.isNotEmpty) {
        await _openApprovalUrl(approvalUrl);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              payment.status == 1
                  ? 'Approval link trenutno nije dostupan. Ako ste PayPal vec odobrili ranije, kliknite "2. Zavrsi placanje".'
                  : 'Placanje je inicirano, ali approval link trenutno nije dostupan.',
            ),
          ),
        );
      }

      await _load();
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Placanje trenutno nije moguce inicirati.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isPaymentSubmitting = false;
        });
      }
    }
  }

  Future<void> _confirmPayment(int paymentId) async {
    setState(() {
      _isPaymentSubmitting = true;
    });

    try {
      final payment = await _dataService.confirmPayment(
        token: widget.token,
        paymentId: paymentId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _paymentDetails = payment;
        _hasOpenedPayPalApproval = false;
        _markDirtyOnPop = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Placanje je uspjesno potvrdeno.'),
        ),
      );

      await _load();
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Placanje trenutno nije moguce potvrditi.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isPaymentSubmitting = false;
        });
      }
    }
  }

  Future<void> _openBaggageDialog(MobileReservationDetails details) async {
    final selectedCount = await showDialog<int>(
      context: context,
      builder: (context) => _BaggageCountDialog(
        initialValue: details.additionalBaggageCount,
        unitPrice: details.additionalBaggageUnitPrice,
        currency: details.currency,
      ),
    );

    if (selectedCount == null || selectedCount == details.additionalBaggageCount) {
      return;
    }

    setState(() {
      _isBaggageSubmitting = true;
    });

    try {
      final updated = await _dataService.updateReservationBaggage(
        token: widget.token,
        reservationId: details.id,
        additionalBaggageCount: selectedCount,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _details = updated;
        _paymentDetails = null;
        _hasOpenedPayPalApproval = false;
        _markDirtyOnPop = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Dodatni prtljag je azuriran. Ako je placanje bilo pokrenuto, otvorite PayPal ponovo za novi iznos.',
          ),
        ),
      );
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dodatni prtljag trenutno nije moguce azurirati.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isBaggageSubmitting = false;
        });
      }
    }
  }

  Future<void> _openApprovalUrl(String approvalUrl) async {
    if (mounted) {
      setState(() {
        _hasOpenedPayPalApproval = true;
      });
    }

    final uri = Uri.tryParse(approvalUrl);
    if (uri == null) {
      await _copyApprovalUrl(approvalUrl);
      return;
    }

    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!launched) {
      await _copyApprovalUrl(approvalUrl);
    }
  }

  Future<void> _copyApprovalUrl(String approvalUrl) async {
    await Clipboard.setData(ClipboardData(text: approvalUrl));
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Approval link je kopiran.')),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelMedium),
    );
  }
}

class _BaggageCountDialog extends StatefulWidget {
  const _BaggageCountDialog({
    required this.initialValue,
    required this.unitPrice,
    required this.currency,
  });

  final int initialValue;
  final double unitPrice;
  final String currency;

  @override
  State<_BaggageCountDialog> createState() => _BaggageCountDialogState();
}

class _BaggageCountDialogState extends State<_BaggageCountDialog> {
  late int _selectedValue;

  @override
  void initState() {
    super.initState();
    _selectedValue = widget.initialValue;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Dodatni prtljag'),
      content: SizedBox(
        width: 360,
        child: DropdownButtonFormField<int>(
          initialValue: _selectedValue,
          decoration: const InputDecoration(
            labelText: 'Ponuda za dodatni prtljag',
          ),
          items: List.generate(
            7,
            (index) => DropdownMenuItem<int>(
              value: index,
              child: Text(
                MobileDisplay.baggageOfferLabel(
                  index,
                  unitPrice: widget.unitPrice,
                  currency: widget.currency,
                  includePrice: true,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          onChanged: (value) {
            if (value == null) {
              return;
            }

            setState(() {
              _selectedValue = value;
            });
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Odustani'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_selectedValue),
          child: const Text('Sacuvaj'),
        ),
      ],
    );
  }
}
