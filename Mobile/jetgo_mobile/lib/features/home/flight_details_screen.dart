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
  static const _heroImageUrl =
      'https://images.unsplash.com/photo-1436491865332-7a61a109cc05?auto=format&fit=crop&w=1400&q=80';

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

  int _displayAvailableSeats(MobileFlightDetails details) {
    return details.availableSeatNumbers.isNotEmpty
        ? details.availableSeatNumbers.length
        : details.availableSeats;
  }

  int _displayTotalSeats(MobileFlightDetails details) {
    return details.seatNumbers.isNotEmpty
        ? details.seatNumbers.length
        : details.totalSeats;
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
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _buildFlightHero(context, details),
          const SizedBox(height: 12),
          _buildSeatSelectionCard(context, details),
          const SizedBox(height: 12),
          _buildBaggageAndPricingCard(context, details),
        ],
      ),
    );
  }

  Widget _buildFlightHero(BuildContext context, MobileFlightDetails details) {
    final theme = Theme.of(context);
    final imageUrl = _destinationImageFor(
      cityName: details.arrivalAirport.cityName,
      airportCode: details.arrivalAirport.iataCode,
      routeCode: details.routeCode,
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 190,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: theme.colorScheme.secondaryContainer,
                    );
                  },
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.12),
                        Colors.black.withValues(alpha: 0.62),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _HeroBadge(
                            label: MobileDisplay.flightStatusLabel(
                              details.status,
                            ),
                            icon: Icons.schedule_rounded,
                          ),
                          const Spacer(),
                          _HeroBadge(
                            label: MobileDisplay.flightNumberLabel(
                              details.flightNumber,
                            ),
                            icon: Icons.confirmation_num_outlined,
                          ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        '${details.departureAirport.cityName} - ${details.arrivalAirport.cityName}',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${details.departureAirport.iataCode} -> ${details.arrivalAirport.iataCode}  |  ${_formatShortDate(details.departureAtUtc)}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.92),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _MetaBadge(
                      icon: Icons.airlines_rounded,
                      label: details.airline.name,
                    ),
                    _MetaBadge(
                      icon: Icons.sell_outlined,
                      label: MobileDisplay.formatMoney(
                        details.basePrice,
                        details.currency,
                      ),
                    ),
                    _MetaBadge(
                      icon: Icons.event_seat_rounded,
                      label: '${_displayAvailableSeats(details)}/${_displayTotalSeats(details)}',
                    ),
                    _MetaBadge(
                      icon: Icons.route_rounded,
                      label: details.routeCode,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _JourneyOverviewCard(
                  departureCity: details.departureAirport.cityName,
                  departureCode: details.departureAirport.iataCode,
                  departureTime: _formatTime(details.departureAtUtc),
                  arrivalCity: details.arrivalAirport.cityName,
                  arrivalCode: details.arrivalAirport.iataCode,
                  arrivalTime: _formatTime(details.arrivalAtUtc),
                  durationLabel: '${details.durationMinutes} min',
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _InfoBlock(
                        title: 'Aerodrom polaska',
                        value: details.departureAirport.name,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _InfoBlock(
                        title: 'Aerodrom dolaska',
                        value: details.arrivalAirport.name,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _InfoBlock(
                        title: 'Broj leta',
                        value: MobileDisplay.flightNumberLabel(
                          details.flightNumber,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: _InfoBlock(
                        title: 'Ukljuceno',
                        value: '10 kg\nkabinskog prtljaga',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Ukrcavanje pocinje 45 minuta prije polaska. Dodjite na aerodrom ranije radi prijave i sigurnosne kontrole.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeatSelectionCard(BuildContext context, MobileFlightDetails details) {
    final seatLayout = _buildSeatLayout(details);
    final splitIndex = seatLayout.letters.length <= 3
        ? seatLayout.letters.length
        : (seatLayout.letters.length / 2).ceil();
    final leftLetters = seatLayout.letters.take(splitIndex).toList();
    final rightLetters = seatLayout.letters.skip(splitIndex).toList();

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
                    'Izaberite svoje sjediste',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (_selectedSeats.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${_selectedSeats.length} odabrano',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Odaberite slobodna sjedista za ovu rezervaciju. Maksimalno mozete izabrati 6 mjesta odjednom.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),
            if (seatLayout.rows.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Trenutno nema slobodnih sjedista za odabir.',
                ),
              )
            else
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 34, right: 8),
                    child: Row(
                      children: [
                        ...leftLetters.map(
                          (letter) => Expanded(
                            child: Center(child: Text(letter)),
                          ),
                        ),
                        if (rightLetters.isNotEmpty) const SizedBox(width: 20),
                        ...rightLetters.map(
                          (letter) => Expanded(
                            child: Center(child: Text(letter)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...seatLayout.rows.map((row) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 26,
                            child: Text(
                              row.rowLabel,
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                          ),
                          const SizedBox(width: 8),
                          ...leftLetters.map(
                            (letter) => Expanded(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 3),
                                child: _buildSeatCell(
                                  context,
                                  seatNumber: row.seatsByLetter[letter],
                                  details: details,
                                ),
                              ),
                            ),
                          ),
                          if (rightLetters.isNotEmpty) const SizedBox(width: 20),
                          ...rightLetters.map(
                            (letter) => Expanded(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 3),
                                child: _buildSeatCell(
                                  context,
                                  seatNumber: row.seatsByLetter[letter],
                                  details: details,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            const SizedBox(height: 16),
            const _SeatLegendCard(
              items: [
                _SeatLegendItem(
                  color: Color(0xFF4B8EF7),
                  label: 'Slobodno',
                ),
                _SeatLegendItem(
                  color: Color(0xFFC86565),
                  label: 'Rezervisano',
                ),
                _SeatLegendItem(
                  color: Color(0xFF42B66D),
                  label: 'Odabrano sjediste',
                ),
              ],
            ),
            if (_selectedSeats.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Odabrana sjedista',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      (_selectedSeats.toList()..sort()).join(', '),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Cijena sjedista: ${MobileDisplay.formatMoney(_selectedSeatsTotal(details), details.currency)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .secondaryContainer
                    .withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 28,
                    color: Color(0xFF42B66D),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Kabinski prtljag do 10 kg je ukljucen u cijenu svake karte.',
                      style: Theme.of(context).textTheme.bodyMedium,
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

  Widget _buildSeatCell(
    BuildContext context, {
    required String? seatNumber,
    required MobileFlightDetails details,
  }) {
    if (seatNumber == null) {
      return const SizedBox(height: 34);
    }

    return _buildSeatTile(
      context,
      seatNumber: seatNumber,
      isAvailable: details.availableSeatNumbers.contains(seatNumber),
    );
  }

  Widget _buildSeatTile(
    BuildContext context, {
    required String seatNumber,
    required bool isAvailable,
  }) {
    final isSelected = _selectedSeats.contains(seatNumber);
    final color = isSelected
        ? const Color(0xFF42B66D)
        : isAvailable
            ? const Color(0xFF4B8EF7)
            : const Color(0xFFC86565);

    return Padding(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: !isAvailable
            ? null
            : () => _toggleSeat(seatNumber, !_selectedSeats.contains(seatNumber)),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 34,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            seatNumber.substring(seatNumber.length - 1),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ),
    );
  }

  Widget _buildBaggageAndPricingCard(
    BuildContext context,
    MobileFlightDetails details,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dodatni prtljag i pregled rezervacije',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Text(
              'Kabinski prtljag je ukljucen, a ovdje po potrebi dodajete dodatne kofere prije placanja.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _additionalBaggageCount,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Odaberite ponudu',
              ),
              selectedItemBuilder: (context) => List.generate(
                7,
                (index) => Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    MobileDisplay.baggageOfferLabel(index),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
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
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${details.departureAirport.cityName}(${details.departureAirport.iataCode}) -> ${details.arrivalAirport.cityName}(${details.arrivalAirport.iataCode})',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Broj leta: ${details.flightNumber.trim().isEmpty || details.flightNumber.trim().toLowerCase() == 'string' ? 'Nije unesen' : details.flightNumber.trim().toUpperCase()}',
                  ),
                  Text(
                    'Broj sjedista: ${_selectedSeats.isEmpty ? '-' : (_selectedSeats.toList()..sort()).join(', ')}',
                  ),
                  Text(
                    'Prtljag: ${MobileDisplay.baggageOfferLabel(_additionalBaggageCount)}',
                  ),
                  const Divider(height: 24),
                  Text(
                    'Sjedista: ${MobileDisplay.formatMoney(_selectedSeatsTotal(details), details.currency)}',
                  ),
                  Text(
                    'Dodatni prtljag: ${MobileDisplay.formatMoney(_selectedBaggageTotal(details), details.currency)}',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ukupna cijena: ${MobileDisplay.formatMoney(_reservationTotal(details), details.currency)}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  _SeatLayoutData _buildSeatLayout(MobileFlightDetails details) {
    final sourceSeatNumbers = details.seatNumbers.isNotEmpty
        ? details.seatNumbers
        : _generateFallbackSeatNumbers(details.totalSeats);

    if (sourceSeatNumbers.isEmpty) {
      return const _SeatLayoutData(letters: [], rows: []);
    }

    final parsedSeats = sourceSeatNumbers
        .map(_parseSeatNumber)
        .whereType<_ParsedSeatNumber>()
        .toList()
      ..sort((left, right) {
        final rowComparison = left.rowNumber.compareTo(right.rowNumber);
        if (rowComparison != 0) {
          return rowComparison;
        }

        return left.letter.compareTo(right.letter);
      });

    if (parsedSeats.isEmpty) {
      return const _SeatLayoutData(letters: [], rows: []);
    }

    final letters = <String>[];
    final rowsByNumber = <int, Map<String, String>>{};

    for (final seat in parsedSeats) {
      if (!letters.contains(seat.letter)) {
        letters.add(seat.letter);
      }

      rowsByNumber.putIfAbsent(seat.rowNumber, () => <String, String>{});
      rowsByNumber[seat.rowNumber]![seat.letter] = seat.original;
    }

    final rows = rowsByNumber.entries
        .map(
          (entry) => _SeatRowData(
            rowLabel: entry.key.toString(),
            seatsByLetter: entry.value,
          ),
        )
        .toList()
      ..sort((left, right) => int.parse(left.rowLabel).compareTo(int.parse(right.rowLabel)));

    return _SeatLayoutData(
      letters: letters,
      rows: rows,
    );
  }

  List<String> _generateFallbackSeatNumbers(int totalSeats) {
    if (totalSeats <= 0) {
      return const [];
    }

    final seatNumbers = <String>[];
    const letters = ['A', 'B', 'C', 'D', 'E', 'F'];
    var createdSeats = 0;
    var row = 1;

    while (createdSeats < totalSeats) {
      for (final letter in letters) {
        if (createdSeats >= totalSeats) {
          break;
        }

        seatNumbers.add('$row$letter');
        createdSeats++;
      }

      row++;
    }

    return seatNumbers;
  }

  _ParsedSeatNumber? _parseSeatNumber(String seatNumber) {
    final match = RegExp(r'^(\d+)([A-Za-z]+)$').firstMatch(seatNumber.trim());
    if (match == null) {
      return null;
    }

    return _ParsedSeatNumber(
      original: seatNumber.trim(),
      rowNumber: int.parse(match.group(1)!),
      letter: match.group(2)!.toUpperCase(),
    );
  }

  String _formatShortDate(DateTime value) {
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    return '$day.$month.${local.year}';
  }

  String _formatTime(DateTime value) {
    final local = value.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _destinationImageFor({
    required String cityName,
    required String airportCode,
    required String routeCode,
  }) {
    final key =
        '${cityName.toLowerCase()} ${airportCode.toLowerCase()} ${routeCode.toLowerCase()}';

    if (key.contains('paris') || key.contains('cdg')) {
      return 'https://images.unsplash.com/photo-1499856871958-5b9627545d1a?auto=format&fit=crop&w=900&q=80';
    }
    if (key.contains('rome') || key.contains('rim') || key.contains('fco')) {
      return 'https://images.unsplash.com/photo-1552832230-c0197dd311b5?auto=format&fit=crop&w=900&q=80';
    }
    if (key.contains('istanbul') || key.contains('ist')) {
      return 'https://images.pexels.com/photos/28879119/pexels-photo-28879119.jpeg?cs=srgb&dl=pexels-reojuve-28879119.jpg&fm=jpg';
    }
    if (key.contains('berlin') || key.contains('ber')) {
      return 'https://images.unsplash.com/photo-1560969184-10fe8719e047?auto=format&fit=crop&w=900&q=80';
    }
    if (key.contains('vienna') || key.contains('vie') || key.contains('bec')) {
      return 'https://images.pexels.com/photos/31725340/pexels-photo-31725340.jpeg?cs=srgb&dl=pexels-bidbtc-31725340.jpg&fm=jpg';
    }
    if (key.contains('zagreb') || key.contains('zag')) {
      return 'https://images.pexels.com/photos/27401067/pexels-photo-27401067.jpeg?cs=srgb&dl=pexels-damir-27401067.jpg&fm=jpg';
    }
    if (key.contains('frankfurt') || key.contains('fra')) {
      return 'https://images.pexels.com/photos/19335682/pexels-photo-19335682.jpeg?cs=srgb&dl=pexels-masoodaslami-19335682.jpg&fm=jpg';
    }
    if (key.contains('belgrade') || key.contains('beograd') || key.contains('beg')) {
      return 'https://images.pexels.com/photos/32237254/pexels-photo-32237254.jpeg?cs=srgb&dl=pexels-borishamer-32237254.jpg&fm=jpg';
    }
    if (key.contains('zurich') || key.contains('cirih') || key.contains('zrh')) {
      return 'https://images.unsplash.com/photo-1505764706515-aa95265c5abc?auto=format&fit=crop&w=900&q=80';
    }

    return _heroImageUrl;
  }
}

class _MetaBadge extends StatelessWidget {
  const _MetaBadge({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    );
  }
}

class _HeroBadge extends StatelessWidget {
  const _HeroBadge({
    required this.label,
    required this.icon,
  });

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.36),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _JourneyOverviewCard extends StatelessWidget {
  const _JourneyOverviewCard({
    required this.departureCity,
    required this.departureCode,
    required this.departureTime,
    required this.arrivalCity,
    required this.arrivalCode,
    required this.arrivalTime,
    required this.durationLabel,
  });

  final String departureCity;
  final String departureCode;
  final String departureTime;
  final String arrivalCity;
  final String arrivalCode;
  final String arrivalTime;
  final String durationLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _JourneyPoint(
              title: 'Polazak',
              primary: departureTime,
              secondary: '$departureCity ($departureCode)',
              alignEnd: false,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Column(
              children: [
                Icon(
                  Icons.flight_takeoff_rounded,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 4),
                Text(
                  durationLabel,
                  style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _JourneyPoint(
              title: 'Dolazak',
              primary: arrivalTime,
              secondary: '$arrivalCity ($arrivalCode)',
              alignEnd: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _JourneyPoint extends StatelessWidget {
  const _JourneyPoint({
    required this.title,
    required this.primary,
    required this.secondary,
    required this.alignEnd,
  });

  final String title;
  final String primary;
  final String secondary;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          primary,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 2),
        Text(
          secondary,
          textAlign: alignEnd ? TextAlign.end : TextAlign.start,
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _InfoBlock extends StatelessWidget {
  const _InfoBlock({
    required this.title,
    required this.value,
  });

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _SeatLegendItem {
  const _SeatLegendItem({
    required this.color,
    required this.label,
  });

  final Color color;
  final String label;
}

class _SeatLegendCard extends StatelessWidget {
  const _SeatLegendCard({required this.items});

  final List<_SeatLegendItem> items;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 12,
          runSpacing: 10,
          children: items
              .map(
                (item) => Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: item.color,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        item.label,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _SeatLayoutData {
  const _SeatLayoutData({
    required this.letters,
    required this.rows,
  });

  final List<String> letters;
  final List<_SeatRowData> rows;
}

class _SeatRowData {
  const _SeatRowData({
    required this.rowLabel,
    required this.seatsByLetter,
  });

  final String rowLabel;
  final Map<String, String> seatsByLetter;
}

class _ParsedSeatNumber {
  const _ParsedSeatNumber({
    required this.original,
    required this.rowNumber,
    required this.letter,
  });

  final String original;
  final int rowNumber;
  final String letter;
}
