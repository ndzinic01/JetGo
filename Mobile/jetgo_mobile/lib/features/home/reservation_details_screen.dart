import 'package:flutter/material.dart';

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
      final details = await _dataService.fetchReservationDetails(
        token: widget.token,
        reservationId: widget.reservationId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _details = details;
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
          Navigator.of(context).pop(widget.markDirtyOnPop);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Detalji rezervacije'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () {
              Navigator.of(context).pop(widget.markDirtyOnPop);
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
                  Text('${details.flightNumber} - ${details.routeCode}'),
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
                  if (details.canInitiatePayment) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Rezervacija je spremna za payment korak na backendu.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ),
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
