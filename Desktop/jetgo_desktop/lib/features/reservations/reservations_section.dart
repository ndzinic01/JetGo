import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/network/api_exception.dart';
import '../flights_routes/flights_routes_models.dart';
import '../flights_routes/flights_routes_service.dart';
import 'reservations_models.dart';
import 'reservations_service.dart';

class ReservationsSection extends StatefulWidget {
  const ReservationsSection({required this.token, super.key});

  final String token;

  @override
  State<ReservationsSection> createState() => _ReservationsSectionState();
}

class _ReservationsSectionState extends State<ReservationsSection> {
  final ReservationsService _service = ReservationsService();
  final FlightsRoutesService _flightsService = FlightsRoutesService();
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  bool _isLoading = true;
  bool _isDetailsLoading = false;
  String? _errorMessage;
  String? _detailsErrorMessage;

  List<ReservationItem> _reservations = const [];
  List<FlightItem> _flightOptions = const [];
  ReservationDetails? _selectedDetails;
  int? _selectedReservationId;

  ReservationStatusValue? _statusFilter;
  int? _flightFilter;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearchChanged);
    _loadInitial();
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

      _loadReservations(showLoader: false);
    });
  }

  Future<void> _loadInitial() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _refreshLookups();
      await _loadReservations(showLoader: false);
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.message;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = 'Modul rezervacija trenutno nije dostupan.';
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshLookups() async {
    final flights = await _flightsService.fetchFlights(
      token: widget.token,
      pageSize: 100,
    );

    _flightOptions = flights.items;

    if (_flightFilter != null &&
        !_flightOptions.any((item) => item.id == _flightFilter)) {
      _flightFilter = null;
    }
  }

  Future<void> _loadReservations({bool showLoader = true}) async {
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
      final response = await _service.fetchReservations(
        token: widget.token,
        searchText: _searchController.text,
        flightId: _flightFilter,
        status: _statusFilter,
      );

      _reservations = response.items;

      if (_reservations.isEmpty) {
        _selectedReservationId = null;
        _selectedDetails = null;
        _detailsErrorMessage = null;
      } else {
        final selectedExists =
            _selectedReservationId != null &&
            _reservations.any((item) => item.id == _selectedReservationId);
        final nextId = selectedExists
            ? _selectedReservationId!
            : _reservations.first.id;
        await _loadReservationDetails(nextId, showLoader: false);
      }
    } on ApiException catch (error) {
      _errorMessage = error.message;
    } catch (_) {
      _errorMessage = 'Rezervacije trenutno nisu dostupne. Pokusajte ponovo.';
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadReservationDetails(
    int reservationId, {
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
      final details = await _service.getReservation(
        token: widget.token,
        id: reservationId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _selectedReservationId = reservationId;
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
        _detailsErrorMessage = 'Detalji rezervacije trenutno nisu dostupni.';
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
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _refreshLookups();
      await _loadReservations(showLoader: false);
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.message;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = 'Osvjezavanje trenutno nije dostupno.';
        _isLoading = false;
      });
    }
  }

  Future<void> _changeStatus({
    required String title,
    required Future<ReservationDetails> Function(String? reason) action,
  }) async {
    final reason = await showDialog<String?>(
      context: context,
      builder: (context) => _ReservationReasonDialog(title: title),
    );

    if (reason == null) {
      return;
    }

    final reservationId = _selectedReservationId;
    if (reservationId == null) {
      return;
    }

    try {
      final details = await action(reason);

      if (!mounted) {
        return;
      }

      setState(() {
        _selectedDetails = details;
      });
      await _loadReservations(showLoader: false);
      _showMessage('Status rezervacije je uspjesno azuriran.');
    } on ApiException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Promjena statusa trenutno nije dostupna.');
    }
  }

  Future<void> _handleChangeReservation(ReservationDetails details) async {
    final nowUtc = DateTime.now().toUtc();
    final eligibleFlights =
        _flightOptions
            .where(
              (flight) =>
                  flight.routeCode == details.routeCode &&
                  (flight.status == FlightStatusValue.scheduled ||
                      flight.status == FlightStatusValue.delayed) &&
                  flight.departureAtUtc.toUtc().isAfter(nowUtc),
            )
            .toList()
          ..sort((a, b) => a.departureAtUtc.compareTo(b.departureAtUtc));

    if (!eligibleFlights.any((flight) => flight.id == details.flightId)) {
      final currentFlightOptions = _flightOptions.where(
        (flight) => flight.id == details.flightId,
      );

      if (currentFlightOptions.isNotEmpty) {
        eligibleFlights.insert(0, currentFlightOptions.first);
      }
    }

    if (eligibleFlights.isEmpty) {
      _showMessage(
        'Nema aktivnih letova na istoj ruti za izmjenu rezervacije.',
      );
      return;
    }

    final input = await showDialog<_ReservationChangeInput>(
      context: context,
      builder: (context) => _ReservationChangeDialog(
        token: widget.token,
        details: details,
        flightOptions: eligibleFlights,
        flightsService: _flightsService,
      ),
    );

    if (input == null) {
      return;
    }

    try {
      final updated = await _service.changeReservation(
        token: widget.token,
        id: details.id,
        flightId: input.flightId,
        seatNumbers: input.seatNumbers,
        additionalBaggageCount: input.additionalBaggageCount,
        reason: input.reason,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _selectedReservationId = updated.id;
        _selectedDetails = updated;
      });

      await _refreshLookups();
      await _loadReservations(showLoader: false);
      _showMessage('Rezervacija je uspjesno izmijenjena.');
    } on ApiException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Izmjena rezervacije trenutno nije dostupna.');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
                    child: _buildDetailsContent(context),
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
                onSubmitted: (_) => _loadReservations(),
                decoration: const InputDecoration(
                  labelText: 'Pretraga rezervacija',
                  hintText: 'Kod rezervacije, kupac, broj leta ili ruta',
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
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<ReservationStatusValue?>(
                  key: ValueKey<ReservationStatusValue?>(_statusFilter),
                  initialValue: _statusFilter,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: [
                    const DropdownMenuItem<ReservationStatusValue?>(
                      value: null,
                      child: Text('Svi statusi'),
                    ),
                    ...ReservationStatusValue.values.map(
                      (status) => DropdownMenuItem<ReservationStatusValue?>(
                        value: status,
                        child: Text(status.label),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _statusFilter = value;
                    });
                    _loadReservations();
                  },
                ),
              ),
              SizedBox(
                width: 300,
                child: DropdownButtonFormField<int?>(
                  key: ValueKey<int?>(_flightFilter),
                  initialValue: _flightFilter,
                  decoration: const InputDecoration(labelText: 'Let'),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Svi letovi'),
                    ),
                    ..._flightOptions.map(
                      (flight) => DropdownMenuItem<int?>(
                        value: flight.id,
                        child: Text(
                          '${flight.flightNumber} / ${flight.routeCode}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _flightFilter = value;
                    });
                    _loadReservations();
                  },
                ),
              ),
            ],
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
        title: 'Nije moguce ucitati rezervacije',
        message: _errorMessage!,
      );
    }

    if (_reservations.isEmpty) {
      return const _CenteredMessage(
        icon: Icons.inbox_outlined,
        title: 'Nema rezervacija za prikaz',
        message: 'Pokusajte druge filtere ili pretragu.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Rezervacije (${_reservations.length})',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        Expanded(
          child: SingleChildScrollView(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Kod')),
                  DataColumn(label: Text('Kupac')),
                  DataColumn(label: Text('Let')),
                  DataColumn(label: Text('Ruta')),
                  DataColumn(label: Text('Polazak')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Placanje')),
                  DataColumn(label: Text('Sjedista')),
                  DataColumn(label: Text('Prtljag')),
                  DataColumn(label: Text('Ukupno')),
                ],
                rows: _reservations.map((item) {
                  final isSelected = item.id == _selectedReservationId;
                  return DataRow(
                    selected: isSelected,
                    onSelectChanged: (_) => _loadReservationDetails(item.id),
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
                      DataCell(Text(_formatDateTime(item.departureAtUtc))),
                      DataCell(Text(item.status.label)),
                      DataCell(Text(_paymentSummary(item))),
                      DataCell(Text(item.seatsCount.toString())),
                      DataCell(
                        Text(_compactBaggageLabel(item.additionalBaggageCount)),
                      ),
                      DataCell(
                        Text(
                          '${item.totalAmount.toStringAsFixed(2)} ${item.currency}',
                        ),
                      ),
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

  Widget _buildDetailsContent(BuildContext context) {
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
        title: 'Odaberite rezervaciju',
        message: 'Kliknite red iz tabele da otvorite detalje i admin akcije.',
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
                  Text(
                    '${details.departureAirportCode} -> ${details.arrivalAirportCode}',
                  ),
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
            if (details.canBeCancelled)
              OutlinedButton.icon(
                onPressed: () => _changeStatus(
                  title: 'Otkazi rezervaciju',
                  action: (reason) => _service.cancelReservation(
                    token: widget.token,
                    id: details.id,
                    reason: reason,
                  ),
                ),
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('Otkazi'),
              ),
            if (details.canChangeReservation)
              FilledButton.icon(
                onPressed: () => _handleChangeReservation(details),
                icon: const Icon(Icons.edit_calendar_rounded),
                label: const Text('Izmijeni'),
              ),
          ],
        ),
        const SizedBox(height: 20),
        Expanded(
          child: ListView(
            children: [
              _DetailsBlock(
                title: 'Osnovno',
                rows: [
                  _DetailsRow(
                    'Polazak',
                    _formatDateTime(details.departureAtUtc),
                  ),
                  _DetailsRow('Dolazak', _formatDateTime(details.arrivalAtUtc)),
                  _DetailsRow('Ukupno sjedista', '${details.seats.length}'),
                  _DetailsRow(
                    'Kreirano',
                    _formatDateTime(details.createdAtUtc),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _DetailsBlock(
                title: 'Cijena i prtljag',
                rows: [
                  _DetailsRow(
                    'Sjedista',
                    '${details.seatsTotalAmount.toStringAsFixed(2)} ${details.currency}',
                  ),
                  _DetailsRow(
                    'Ponuda prtljaga',
                    _baggageOfferLabel(details.additionalBaggageCount),
                  ),
                  if (details.additionalBaggageCount > 0)
                    _DetailsRow(
                      'Cijena po komadu',
                      '${details.additionalBaggageUnitPrice.toStringAsFixed(2)} ${details.currency}',
                    ),
                  if (details.additionalBaggageCount > 0)
                    _DetailsRow(
                      'Ukupno prtljag',
                      '${details.additionalBaggageTotalAmount.toStringAsFixed(2)} ${details.currency}',
                    ),
                  _DetailsRow(
                    'Ukupno',
                    '${details.totalAmount.toStringAsFixed(2)} ${details.currency}',
                  ),
                  _DetailsRow(
                    'Moze izmjena prtljaga',
                    details.canUpdateBaggage ? 'Da' : 'Ne',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _DetailsBlock(
                title: 'Kupac',
                rows: [
                  _DetailsRow('Ime i prezime', details.customer.fullName),
                  _DetailsRow(
                    'Korisnicko ime',
                    '@${details.customer.username}',
                  ),
                  _DetailsRow('Email', details.customer.email),
                ],
              ),
              const SizedBox(height: 16),
              if (details.passengers.isNotEmpty) ...[
                const SizedBox(height: 16),
                _DetailsBlock(
                  title: 'Putnici',
                  rows: details.passengers
                      .map(
                        (passenger) => _DetailsRow(
                          passenger.seatNumber,
                          '${passenger.fullName.isEmpty ? 'Putnik' : passenger.fullName} | ${_passengerGenderLabel(passenger.gender)} | Pasos: ${passenger.passportNumber}',
                        ),
                      )
                      .toList(),
                ),
              ],
              _DetailsBlock(
                title: 'Placanje',
                rows: [
                  _DetailsRow(
                    'Status placanja',
                    details.paymentStatus?.label ?? '-',
                  ),
                  _DetailsRow('Placeno', details.isPaid ? 'Da' : 'Ne'),
                  _DetailsRow(
                    'Moze placanje',
                    details.canInitiatePayment ? 'Da' : 'Ne',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _DetailsBlock(
                title: 'Sjedista',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: details.seats
                      .map(
                        (seat) => Chip(
                          label: Text(
                            '${seat.seatNumber} (${seat.price.toStringAsFixed(2)} ${details.currency})',
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 16),
              _DetailsBlock(
                title: 'Status meta',
                rows: [
                  _DetailsRow(
                    'Promijenjeno',
                    _formatDateTime(details.statusChangedAtUtc),
                  ),
                  _DetailsRow(
                    'Promijenio korisnik',
                    details.statusChangedByUserId ?? '-',
                  ),
                  _DetailsRow(
                    'Napomena',
                    (details.statusReason?.trim().isNotEmpty ?? false)
                        ? details.statusReason!
                        : '-',
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _passengerGenderLabel(int gender) {
    switch (gender) {
      case 1:
        return 'Musko';
      case 2:
        return 'Zensko';
      case 3:
        return 'Drugo';
      default:
        return 'Nije navedeno';
    }
  }

  String _paymentSummary(ReservationItem item) {
    if (item.paymentStatus == null) {
      return item.isPaid ? 'Placeno' : '-';
    }
    return item.paymentStatus!.label;
  }

  String _compactBaggageLabel(int count) {
    if (count <= 0) {
      return 'Bez';
    }

    return '${count}x 23 kg';
  }

  String _baggageOfferLabel(int count) {
    if (count <= 0) {
      return 'Bez dodatnog prtljaga';
    }

    final noun = switch (count) {
      1 => 'dodatni kofer',
      2 || 3 || 4 => 'dodatna kofera',
      _ => 'dodatnih kofera',
    };

    return '$count $noun do 23 kg';
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
        style: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _DetailsBlock extends StatelessWidget {
  const _DetailsBlock({required this.title, this.rows, this.child});

  final String title;
  final List<_DetailsRow>? rows;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        if (rows != null)
          ...rows!.map(
            (row) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 130,
                    child: Text(
                      row.label,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(row.value)),
                ],
              ),
            ),
          ),
        ...switch (child) {
          final value? => [value],
          null => const <Widget>[],
        },
      ],
    );
  }
}

class _DetailsRow {
  const _DetailsRow(this.label, this.value);

  final String label;
  final String value;
}

class _ReservationReasonDialog extends StatefulWidget {
  const _ReservationReasonDialog({required this.title});

  final String title;

  @override
  State<_ReservationReasonDialog> createState() =>
      _ReservationReasonDialogState();
}

class _ReservationReasonDialogState extends State<_ReservationReasonDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 460,
        child: TextField(
          controller: _controller,
          maxLength: 500,
          minLines: 3,
          maxLines: 6,
          decoration: const InputDecoration(
            labelText: 'Napomena',
            hintText: 'Opcionalna napomena za promjenu statusa',
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Odustani'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Potvrdi'),
        ),
      ],
    );
  }
}

class _ReservationChangeInput {
  const _ReservationChangeInput({
    required this.flightId,
    required this.seatNumbers,
    required this.additionalBaggageCount,
    required this.reason,
  });

  final int flightId;
  final List<String> seatNumbers;
  final int additionalBaggageCount;
  final String reason;
}

class _ReservationChangeDialog extends StatefulWidget {
  const _ReservationChangeDialog({
    required this.token,
    required this.details,
    required this.flightOptions,
    required this.flightsService,
  });

  final String token;
  final ReservationDetails details;
  final List<FlightItem> flightOptions;
  final FlightsRoutesService flightsService;

  @override
  State<_ReservationChangeDialog> createState() =>
      _ReservationChangeDialogState();
}

class _ReservationChangeDialogState extends State<_ReservationChangeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();

  late int _selectedFlightId;
  late int _baggageCount;
  late Set<String> _selectedSeats;
  FlightDetails? _flightDetails;
  bool _isLoadingFlight = false;
  String? _flightErrorMessage;
  String? _seatErrorMessage;

  @override
  void initState() {
    super.initState();
    _selectedFlightId = widget.details.flightId;
    _baggageCount = widget.details.additionalBaggageCount;
    _selectedSeats = widget.details.seats
        .map((seat) => seat.seatNumber)
        .where((seat) => seat.trim().isNotEmpty)
        .toSet();
    _loadFlightDetails(_selectedFlightId);
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _loadFlightDetails(int flightId) async {
    setState(() {
      _isLoadingFlight = true;
      _flightErrorMessage = null;
    });

    try {
      final details = await widget.flightsService.getFlight(
        token: widget.token,
        id: flightId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _flightDetails = details;
        final availableSeats = _seatOptions.toSet();
        _selectedSeats = _selectedSeats
            .where((seat) => availableSeats.contains(seat))
            .toSet();
        _isLoadingFlight = false;
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _flightDetails = null;
        _flightErrorMessage = error.message;
        _isLoadingFlight = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _flightDetails = null;
        _flightErrorMessage =
            'Sjedista za odabrani let trenutno nisu dostupna.';
        _isLoadingFlight = false;
      });
    }
  }

  List<String> get _seatOptions {
    final seats = <String>{
      ...?_flightDetails?.availableSeatNumbers,
      if (_selectedFlightId == widget.details.flightId)
        ...widget.details.seats.map((seat) => seat.seatNumber),
    };

    return seats.toList()..sort(_compareSeatNumbers);
  }

  double get _baggageUnitPrice {
    final flightPrice = _flightDetails?.additionalBaggageUnitPrice ?? 0;
    if (flightPrice > 0) {
      return flightPrice;
    }

    if (widget.details.additionalBaggageUnitPrice > 0) {
      return widget.details.additionalBaggageUnitPrice;
    }

    return 35;
  }

  double get _newTotalAmount {
    final seatPrice = _flightDetails?.basePrice ?? 0;
    return (seatPrice * _selectedSeats.length) +
        (_baggageCount * _baggageUnitPrice);
  }

  double get _differenceAmount => _newTotalAmount - widget.details.totalAmount;

  String get _currency => _flightDetails?.currency ?? widget.details.currency;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Izmijeni rezervaciju'),
      content: SizedBox(
        width: 660,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${widget.details.reservationCode} - ${widget.details.routeCode}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  key: ValueKey<int>(_selectedFlightId),
                  initialValue: _selectedFlightId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Let'),
                  items: widget.flightOptions
                      .map(
                        (flight) => DropdownMenuItem<int>(
                          value: flight.id,
                          child: Text(
                            '${flight.flightNumber} - ${_formatDateTime(flight.departureAtUtc)}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  validator: (value) => value == null
                      ? 'Odaberite let za izmjenu rezervacije.'
                      : null,
                  onChanged: (value) {
                    if (value == null || value == _selectedFlightId) {
                      return;
                    }

                    setState(() {
                      _selectedFlightId = value;
                      _flightDetails = null;
                      _seatErrorMessage = null;
                      _selectedSeats = value == widget.details.flightId
                          ? widget.details.seats
                                .map((seat) => seat.seatNumber)
                                .toSet()
                          : <String>{};
                    });
                    _loadFlightDetails(value);
                  },
                ),
                const SizedBox(height: 16),
                if (_isLoadingFlight) const LinearProgressIndicator(),
                if (_flightErrorMessage != null) ...[
                  Text(
                    _flightErrorMessage!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                _buildSeatPicker(context),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  key: ValueKey<int>(_baggageCount),
                  initialValue: _baggageCount,
                  decoration: const InputDecoration(
                    labelText: 'Dodatni prtljag',
                  ),
                  items: List.generate(
                    7,
                    (index) => DropdownMenuItem<int>(
                      value: index,
                      child: Text(
                        index == 0 ? 'Bez dodatnog prtljaga' : '$index kom.',
                      ),
                    ),
                  ),
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }

                    setState(() {
                      _baggageCount = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _reasonController,
                  maxLength: 500,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Razlog izmjene',
                    hintText: 'Npr. zahtjev korisnika za drugi datum leta',
                  ),
                  validator: (value) {
                    final trimmed = value?.trim() ?? '';
                    if (trimmed.isEmpty) {
                      return 'Razlog izmjene je obavezan.';
                    }
                    if (trimmed.length < 5) {
                      return 'Razlog izmjene mora imati najmanje 5 karaktera.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                _buildPricePreview(context),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Odustani'),
        ),
        FilledButton(
          onPressed: _isLoadingFlight ? null : _submit,
          child: const Text('Sacuvaj izmjenu'),
        ),
      ],
    );
  }

  Widget _buildSeatPicker(BuildContext context) {
    final seats = _seatOptions;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Sjedista', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        if (seats.isEmpty)
          Text(
            'Odabrani let nema slobodnih sjedista.',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: seats
                .map(
                  (seat) => FilterChip(
                    label: Text(seat),
                    selected: _selectedSeats.contains(seat),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedSeats.add(seat);
                        } else {
                          _selectedSeats.remove(seat);
                        }
                        _seatErrorMessage = null;
                      });
                    },
                  ),
                )
                .toList(),
          ),
        if (_seatErrorMessage != null) ...[
          const SizedBox(height: 8),
          Text(
            _seatErrorMessage!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    );
  }

  Widget _buildPricePreview(BuildContext context) {
    final difference = _differenceAmount;
    final differenceLabel = difference.abs() < 0.005
        ? 'Bez razlike za placanje'
        : difference > 0
        ? 'Doplata ${difference.toStringAsFixed(2)} $_currency'
        : 'Djelimicni refund ${difference.abs().toStringAsFixed(2)} $_currency';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Obracun', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 10),
          _PricePreviewRow(
            label: 'Trenutni iznos',
            value:
                '${widget.details.totalAmount.toStringAsFixed(2)} ${widget.details.currency}',
          ),
          _PricePreviewRow(
            label: 'Novi iznos',
            value: '${_newTotalAmount.toStringAsFixed(2)} $_currency',
          ),
          _PricePreviewRow(label: 'Razlika', value: differenceLabel),
          const SizedBox(height: 8),
          Text(
            'Ako je rezervacija vec placena, sistem automatski pokrece doplatu ili djelimicni refund.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  void _submit() {
    final formValid = _formKey.currentState?.validate() ?? false;

    if (_selectedSeats.isEmpty) {
      setState(() {
        _seatErrorMessage = 'Odaberite najmanje jedno sjediste.';
      });
    }

    if (!formValid || _selectedSeats.isEmpty || _flightDetails == null) {
      return;
    }

    final seats = _selectedSeats.toList()..sort(_compareSeatNumbers);
    Navigator.of(context).pop(
      _ReservationChangeInput(
        flightId: _selectedFlightId,
        seatNumbers: seats,
        additionalBaggageCount: _baggageCount,
        reason: _reasonController.text.trim(),
      ),
    );
  }

  static int _compareSeatNumbers(String first, String second) {
    final numberPattern = RegExp(r'^\d+');
    final firstRow = int.tryParse(numberPattern.stringMatch(first) ?? '');
    final secondRow = int.tryParse(numberPattern.stringMatch(second) ?? '');

    if (firstRow != null && secondRow != null && firstRow != secondRow) {
      return firstRow.compareTo(secondRow);
    }

    return first.compareTo(second);
  }

  static String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day.$month.${local.year} $hour:$minute';
  }
}

class _PricePreviewRow extends StatelessWidget {
  const _PricePreviewRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
