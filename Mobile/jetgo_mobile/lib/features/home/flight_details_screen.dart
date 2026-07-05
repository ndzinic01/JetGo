import 'package:flutter/material.dart';

import '../../core/network/api_exception.dart';
import 'mobile_data_service.dart';
import 'mobile_display.dart';
import 'mobile_models.dart';
import 'reservation_details_screen.dart';

class FlightDetailsScreen extends StatefulWidget {
  const FlightDetailsScreen({
    required this.token,
    required this.flightId,
    super.key,
  });

  final String token;
  final int flightId;

  @override
  State<FlightDetailsScreen> createState() => _FlightDetailsScreenState();
}

class _FlightDetailsScreenState extends State<FlightDetailsScreen> {
  final MobileDataService _dataService = MobileDataService();
  final Set<String> _selectedSeats = <String>{};
  int _additionalBaggageCount = 0;

  MobileFlightDetails? _details;
  bool _isLoading = true;
  bool _isSubmitting = false;
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
      _selectedSeats.clear();
      _additionalBaggageCount = 0;
    });

    try {
      final details = await _dataService.fetchFlightDetails(
        token: widget.token,
        flightId: widget.flightId,
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
        _errorMessage = 'Detalji leta trenutno nisu dostupni.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _createReservation() async {
    final details = _details;
    if (details == null || _selectedSeats.isEmpty) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final reservation = await _dataService.createReservation(
        token: widget.token,
        flightId: details.id,
        seatNumbers: _selectedSeats.toList()..sort(),
        additionalBaggageCount: _additionalBaggageCount,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rezervacija je uspjesno kreirana.')),
      );

      await Navigator.of(context).pushReplacement<bool, bool>(
        MaterialPageRoute<bool>(
          builder: (_) => ReservationDetailsScreen(
            token: widget.token,
            reservationId: reservation.id,
            markDirtyOnPop: true,
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
          content: Text('Rezervaciju trenutno nije moguce kreirati.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _toggleSeat(String seatNumber, bool isSelected) {
    if (isSelected) {
      if (_selectedSeats.length >= 6) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Maksimalno je dozvoljeno odabrati 6 sjedista.'),
          ),
        );
        return;
      }

      setState(() {
        _selectedSeats.add(seatNumber);
      });
      return;
    }

    setState(() {
      _selectedSeats.remove(seatNumber);
    });
  }

  double _selectedSeatsTotal(MobileFlightDetails details) {
    return details.basePrice * _selectedSeats.length;
  }

  double _selectedBaggageTotal(MobileFlightDetails details) {
    return details.additionalBaggageUnitPrice * _additionalBaggageCount;
  }

  double _reservationTotal(MobileFlightDetails details) {
    return _selectedSeatsTotal(details) + _selectedBaggageTotal(details);
  }

  @override
  Widget build(BuildContext context) {
    final details = _details;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalji leta'),
        actions: [
          IconButton(
            tooltip: 'Osvjezi',
            onPressed: _isLoading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _buildBody(context, details),
      bottomNavigationBar: details == null || _errorMessage != null
          ? null
          : SafeArea(
              minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: FilledButton.icon(
                onPressed: _selectedSeats.isEmpty || _isSubmitting
                    ? null
                    : _createReservation,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.confirmation_num_rounded),
                label: Text(
                  _isSubmitting
                      ? 'Kreiranje...'
                      : 'Rezervisi (${_selectedSeats.length}) - ${MobileDisplay.formatMoney(_reservationTotal(details), details.currency)}',
                ),
              ),
            ),
    );
  }

  Widget _buildBody(BuildContext context, MobileFlightDetails? details) {
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

    if (details == null) {
      return const Center(child: Text('Let nije pronadjen.'));
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
                          '${details.flightNumber} - ${details.routeCode}',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      _StatusChip(
                        label: MobileDisplay.flightStatusLabel(details.status),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${details.departureAirport.cityName} (${details.departureAirport.iataCode}) -> ${details.arrivalAirport.cityName} (${details.arrivalAirport.iataCode})',
                  ),
                  const SizedBox(height: 6),
                  Text('${details.airline.name} (${details.airline.code})'),
                  const SizedBox(height: 8),
                  Text(
                    'Polazak: ${MobileDisplay.formatDateTime(details.departureAtUtc)}',
                  ),
                  Text(
                    'Dolazak: ${MobileDisplay.formatDateTime(details.arrivalAtUtc)}',
                  ),
                  const SizedBox(height: 8),
                  Text('Trajanje: ${details.durationMinutes} min'),
                  Text(
                    'Cijena po sjedistu: ${MobileDisplay.formatMoney(details.basePrice, details.currency)}',
                  ),
                  Text(
                    'Dodatni kofer do 23 kg: ${MobileDisplay.formatMoney(details.additionalBaggageUnitPrice, details.currency)}',
                  ),
                  Text(
                    'Slobodna sjedista: ${details.availableSeats}/${details.totalSeats}',
                  ),
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
                    'Odabir sjedista',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Odaberite najmanje jedno, a najvise 6 sjedista.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  if (details.availableSeatNumbers.isEmpty)
                    const Text('Trenutno nema slobodnih sjedista za odabir.')
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: details.availableSeatNumbers
                          .map(
                            (seatNumber) => FilterChip(
                              label: Text(seatNumber),
                              selected: _selectedSeats.contains(seatNumber),
                              onSelected: (selected) =>
                                  _toggleSeat(seatNumber, selected),
                            ),
                          )
                          .toList(),
                    ),
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
                    'Dodatni prtljag',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Po jednoj rezervaciji mozete dodati do 6 dodatnih komada prtljaga.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    initialValue: _additionalBaggageCount,
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
                            unitPrice: details.additionalBaggageUnitPrice,
                            currency: details.currency,
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
                        _additionalBaggageCount = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pregled cijene',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Sjedista: ${_selectedSeats.length} - ${MobileDisplay.formatMoney(_selectedSeatsTotal(details), details.currency)}',
                        ),
                        Text(
                          'Dodatni prtljag: ${MobileDisplay.baggageOfferLabel(_additionalBaggageCount)} - ${MobileDisplay.formatMoney(_selectedBaggageTotal(details), details.currency)}',
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Ukupno za rezervaciju: ${MobileDisplay.formatMoney(_reservationTotal(details), details.currency)}',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
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
