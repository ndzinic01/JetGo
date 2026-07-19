import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/network/api_exception.dart';
import '../reference_data/reference_data_models.dart';
import '../reference_data/reference_data_service.dart';
import 'flights_routes_models.dart';
import 'flights_routes_service.dart';

enum FlightsRoutesTab {
  destinations,
  flights,
}

class FlightsRoutesSection extends StatefulWidget {
  const FlightsRoutesSection({required this.token, super.key});

  final String token;

  @override
  State<FlightsRoutesSection> createState() => _FlightsRoutesSectionState();
}

class _FlightsRoutesSectionState extends State<FlightsRoutesSection> {
  final FlightsRoutesService _service = FlightsRoutesService();
  final ReferenceDataService _referenceDataService = ReferenceDataService();
  final TextEditingController _destinationSearchController =
      TextEditingController();
  final TextEditingController _flightSearchController = TextEditingController();
  Timer? _searchDebounce;

  FlightsRoutesTab _selectedTab = FlightsRoutesTab.destinations;
  bool _isLoading = true;
  String? _errorMessage;

  List<DestinationItem> _destinations = const [];
  List<FlightItem> _flights = const [];

  List<AirportItem> _airportOptions = const [];
  List<AirlineItem> _airlineOptions = const [];
  List<DestinationItem> _destinationOptions = const [];

  int? _destinationDepartureFilter;
  int? _destinationArrivalFilter;
  bool? _destinationStatusFilter;

  int? _flightDepartureFilter;
  int? _flightArrivalFilter;
  int? _flightAirlineFilter;
  FlightStatusValue? _flightStatusFilter;

  @override
  void initState() {
    super.initState();
    _destinationSearchController.addListener(_handleSearchChanged);
    _flightSearchController.addListener(_handleSearchChanged);
    _loadInitial();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _destinationSearchController.dispose();
    _flightSearchController.dispose();
    super.dispose();
  }

  void _handleSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) {
        return;
      }

      _loadCurrentTab(showLoader: false);
    });
  }

  Future<void> _loadInitial() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _refreshLookups();
      await _loadCurrentTab(showLoader: false);
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
        _errorMessage = 'Rute i letovi trenutno nisu dostupni.';
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshLookups() async {
    final airports = await _referenceDataService.fetchAirports(
      token: widget.token,
      pageSize: 100,
    );
    final airlines = await _referenceDataService.fetchAirlines(
      token: widget.token,
      pageSize: 100,
    );
    final destinations = await _service.fetchDestinations(
      token: widget.token,
      pageSize: 100,
    );

    _airportOptions = airports.items;
    _airlineOptions = airlines.items;
    _destinationOptions = destinations.items;

    if (_destinationDepartureFilter != null &&
        !_airportOptions.any((item) => item.id == _destinationDepartureFilter)) {
      _destinationDepartureFilter = null;
    }

    if (_destinationArrivalFilter != null &&
        !_airportOptions.any((item) => item.id == _destinationArrivalFilter)) {
      _destinationArrivalFilter = null;
    }

    if (_flightDepartureFilter != null &&
        !_airportOptions.any((item) => item.id == _flightDepartureFilter)) {
      _flightDepartureFilter = null;
    }

    if (_flightArrivalFilter != null &&
        !_airportOptions.any((item) => item.id == _flightArrivalFilter)) {
      _flightArrivalFilter = null;
    }

    if (_flightAirlineFilter != null &&
        !_airlineOptions.any((item) => item.id == _flightAirlineFilter)) {
      _flightAirlineFilter = null;
    }
  }

  Future<void> _loadCurrentTab({bool showLoader = true}) async {
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
      switch (_selectedTab) {
        case FlightsRoutesTab.destinations:
          final response = await _service.fetchDestinations(
            token: widget.token,
            searchText: _destinationSearchController.text,
            departureAirportId: _destinationDepartureFilter,
            arrivalAirportId: _destinationArrivalFilter,
            isActive: _destinationStatusFilter,
          );
          _destinations = response.items;
          break;
        case FlightsRoutesTab.flights:
          final response = await _service.fetchFlights(
            token: widget.token,
            searchText: _flightSearchController.text,
            departureAirportId: _flightDepartureFilter,
            arrivalAirportId: _flightArrivalFilter,
            airlineId: _flightAirlineFilter,
            status: _flightStatusFilter,
          );
          _flights = response.items;
          break;
      }
    } on ApiException catch (error) {
      _errorMessage = error.message;
    } catch (_) {
      _errorMessage = 'Podaci trenutno nisu dostupni. Pokusajte ponovo.';
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
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
      await _loadCurrentTab(showLoader: false);
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

  Future<void> _reloadAfterMutation({
    required bool refreshLookups,
  }) async {
    if (refreshLookups) {
      await _refreshLookups();
    }
    await _loadCurrentTab(showLoader: false);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _deleteEntity({
    required String title,
    required Future<void> Function() onDelete,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Potvrda brisanja'),
          content: Text('Da li ste sigurni da zelite obrisati $title?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Odustani'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Obrisi'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await onDelete();
      if (!mounted) {
        return;
      }
      _showMessage('Zapis je uspjesno obrisan.');
    } on ApiException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Brisanje trenutno nije dostupno. Pokusajte ponovo.');
    }
  }

  Future<void> _openDestinationDialog({DestinationDetails? initial}) async {
    final value = await showDialog<_DestinationFormValue>(
      context: context,
      builder: (context) => _DestinationDialog(
        initial: initial,
        airports: _airportOptions,
      ),
    );

    if (value == null) {
      return;
    }

    try {
      if (initial == null) {
        await _service.createDestination(
          token: widget.token,
          departureAirportId: value.departureAirportId,
          arrivalAirportId: value.arrivalAirportId,
          isActive: value.isActive,
        );
      } else {
        await _service.updateDestination(
          token: widget.token,
          id: initial.id,
          departureAirportId: value.departureAirportId,
          arrivalAirportId: value.arrivalAirportId,
          isActive: value.isActive,
        );
      }

      if (!mounted) {
        return;
      }

      await _reloadAfterMutation(refreshLookups: true);
      _showMessage(
        initial == null
            ? 'Ruta je uspjesno dodana.'
            : 'Ruta je uspjesno azurirana.',
      );
    } on ApiException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Spremanje rute trenutno nije dostupno.');
    }
  }

  Future<void> _editDestination(DestinationItem item) async {
    try {
      final details = await _service.getDestination(
        token: widget.token,
        id: item.id,
      );

      if (!mounted) {
        return;
      }

      await _openDestinationDialog(initial: details);
    } on ApiException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Detalji rute trenutno nisu dostupni.');
    }
  }

  Future<void> _openFlightDialog({FlightDetails? initial}) async {
    final value = await showDialog<_FlightFormValue>(
      context: context,
      builder: (context) => _FlightDialog(
        initial: initial,
        airlines: _airlineOptions,
        destinations: _destinationOptions,
      ),
    );

    if (value == null) {
      return;
    }

    try {
      if (initial == null) {
        await _service.createFlight(
          token: widget.token,
          airlineId: value.airlineId,
          destinationId: value.destinationId,
          flightNumber: value.flightNumber,
          departureAtUtc: value.departureAtLocal.toUtc(),
          arrivalAtUtc: value.arrivalAtLocal.toUtc(),
          basePrice: value.basePrice,
          totalSeats: value.totalSeats,
          status: value.status,
        );
      } else {
        await _service.updateFlight(
          token: widget.token,
          id: initial.id,
          airlineId: value.airlineId,
          destinationId: value.destinationId,
          flightNumber: value.flightNumber,
          departureAtUtc: value.departureAtLocal.toUtc(),
          arrivalAtUtc: value.arrivalAtLocal.toUtc(),
          basePrice: value.basePrice,
          totalSeats: value.totalSeats,
          status: value.status,
        );
      }

      if (!mounted) {
        return;
      }

      await _reloadAfterMutation(refreshLookups: true);
      _showMessage(
        initial == null
            ? 'Let je uspjesno dodan.'
            : 'Let je uspjesno azuriran.',
      );
    } on ApiException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Spremanje leta trenutno nije dostupno.');
    }
  }

  Future<void> _editFlight(FlightItem item) async {
    try {
      final details = await _service.getFlight(
        token: widget.token,
        id: item.id,
      );

      if (!mounted) {
        return;
      }

      await _openFlightDialog(initial: details);
    } on ApiException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Detalji leta trenutno nisu dostupni.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: SegmentedButton<FlightsRoutesTab>(
            segments: const [
              ButtonSegment(
                value: FlightsRoutesTab.destinations,
                icon: Icon(Icons.alt_route_rounded),
                label: Text('Rute'),
              ),
              ButtonSegment(
                value: FlightsRoutesTab.flights,
                icon: Icon(Icons.flight_takeoff_rounded),
                label: Text('Letovi'),
              ),
            ],
            selected: <FlightsRoutesTab>{_selectedTab},
            onSelectionChanged: (selection) {
              final next = selection.first;
              if (next == _selectedTab) {
                return;
              }
              setState(() {
                _selectedTab = next;
              });
              _loadCurrentTab();
            },
          ),
        ),
        const SizedBox(height: 16),
        _buildToolbar(context),
        const SizedBox(height: 16),
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _buildContent(context),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildToolbar(BuildContext context) {
    switch (_selectedTab) {
      case FlightsRoutesTab.destinations:
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _destinationSearchController,
                    onSubmitted: (_) => _loadCurrentTab(),
                    decoration: const InputDecoration(
                      labelText: 'Pretraga ruta',
                      hintText: 'Oznaka rute, grad ili IATA kod',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: _airportOptions.length < 2
                      ? null
                      : () => _openDestinationDialog(),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Nova ruta'),
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
                    width: 240,
                    child: DropdownButtonFormField<int?>(
                      key: ValueKey<int?>(_destinationDepartureFilter),
                      initialValue: _destinationDepartureFilter,
                      decoration:
                          const InputDecoration(labelText: 'Polazni aerodrom'),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('Svi polasci'),
                        ),
                        ..._airportOptions.map(
                          (airport) => DropdownMenuItem<int?>(
                            value: airport.id,
                            child: Text(
                              '${airport.iataCode} / ${airport.cityName}',
                            ),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _destinationDepartureFilter = value;
                        });
                        _loadCurrentTab();
                      },
                    ),
                  ),
                  SizedBox(
                    width: 240,
                    child: DropdownButtonFormField<int?>(
                      key: ValueKey<int?>(_destinationArrivalFilter),
                      initialValue: _destinationArrivalFilter,
                      decoration:
                          const InputDecoration(labelText: 'Dolazni aerodrom'),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('Svi dolasci'),
                        ),
                        ..._airportOptions.map(
                          (airport) => DropdownMenuItem<int?>(
                            value: airport.id,
                            child: Text(
                              '${airport.iataCode} / ${airport.cityName}',
                            ),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _destinationArrivalFilter = value;
                        });
                        _loadCurrentTab();
                      },
                    ),
                  ),
                  SizedBox(
                    width: 180,
                    child: DropdownButtonFormField<bool?>(
                      key: ValueKey<bool?>(_destinationStatusFilter),
                      initialValue: _destinationStatusFilter,
                      decoration: const InputDecoration(labelText: 'Status'),
                      items: const [
                        DropdownMenuItem<bool?>(
                          value: null,
                          child: Text('Svi statusi'),
                        ),
                        DropdownMenuItem<bool?>(
                          value: true,
                          child: Text('Aktivne'),
                        ),
                        DropdownMenuItem<bool?>(
                          value: false,
                          child: Text('Neaktivne'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _destinationStatusFilter = value;
                        });
                        _loadCurrentTab();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      case FlightsRoutesTab.flights:
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _flightSearchController,
                    onSubmitted: (_) => _loadCurrentTab(),
                    decoration: const InputDecoration(
                      labelText: 'Pretraga letova',
                      hintText: 'Broj leta, route code ili grad',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed:
                      _airlineOptions.isEmpty || _destinationOptions.isEmpty
                          ? null
                          : () => _openFlightDialog(),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Novi let'),
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
                    child: DropdownButtonFormField<int?>(
                      key: ValueKey<int?>(_flightDepartureFilter),
                      initialValue: _flightDepartureFilter,
                      decoration:
                          const InputDecoration(labelText: 'Polazni aerodrom'),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('Svi polasci'),
                        ),
                        ..._airportOptions.map(
                          (airport) => DropdownMenuItem<int?>(
                            value: airport.id,
                            child: Text(
                              '${airport.iataCode} / ${airport.cityName}',
                            ),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _flightDepartureFilter = value;
                        });
                        _loadCurrentTab();
                      },
                    ),
                  ),
                  SizedBox(
                    width: 220,
                    child: DropdownButtonFormField<int?>(
                      key: ValueKey<int?>(_flightArrivalFilter),
                      initialValue: _flightArrivalFilter,
                      decoration:
                          const InputDecoration(labelText: 'Dolazni aerodrom'),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('Svi dolasci'),
                        ),
                        ..._airportOptions.map(
                          (airport) => DropdownMenuItem<int?>(
                            value: airport.id,
                            child: Text(
                              '${airport.iataCode} / ${airport.cityName}',
                            ),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _flightArrivalFilter = value;
                        });
                        _loadCurrentTab();
                      },
                    ),
                  ),
                  SizedBox(
                    width: 220,
                    child: DropdownButtonFormField<int?>(
                      key: ValueKey<int?>(_flightAirlineFilter),
                      initialValue: _flightAirlineFilter,
                      decoration:
                          const InputDecoration(labelText: 'Aviokompanija'),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('Sve kompanije'),
                        ),
                        ..._airlineOptions.map(
                          (airline) => DropdownMenuItem<int?>(
                            value: airline.id,
                            child: Text('${airline.name} (${airline.code})'),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _flightAirlineFilter = value;
                        });
                        _loadCurrentTab();
                      },
                    ),
                  ),
                  SizedBox(
                    width: 180,
                    child: DropdownButtonFormField<FlightStatusValue?>(
                      key: ValueKey<FlightStatusValue?>(_flightStatusFilter),
                      initialValue: _flightStatusFilter,
                      decoration: const InputDecoration(labelText: 'Status'),
                      items: [
                        const DropdownMenuItem<FlightStatusValue?>(
                          value: null,
                          child: Text('Svi statusi'),
                        ),
                        ...FlightStatusValue.values.map(
                          (status) => DropdownMenuItem<FlightStatusValue?>(
                            value: status,
                            child: Text(status.label),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _flightStatusFilter = value;
                        });
                        _loadCurrentTab();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
    }
  }

  Widget _buildContent(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 36),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    switch (_selectedTab) {
      case FlightsRoutesTab.destinations:
        return _buildDestinationsTable();
      case FlightsRoutesTab.flights:
        return _buildFlightsTable();
    }
  }

  Widget _buildDestinationsTable() {
    if (_destinations.isEmpty) {
        return const _EmptyTableState(
        title: 'Nema ruta za prikaz',
        message: 'Pokusajte druge filtere ili dodajte novu rutu.',
      );
    }

    return _TableScrollWrapper(
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Ruta')),
          DataColumn(label: Text('Polazni aerodrom')),
          DataColumn(label: Text('Dolazni aerodrom')),
          DataColumn(label: Text('Status')),
          DataColumn(label: Text('Naredni let')),
          DataColumn(label: Text('Akcije')),
        ],
        rows: _destinations.map((item) {
          return DataRow(
            cells: [
              DataCell(Text(item.routeCode)),
              DataCell(_AirportCellText(airport: item.departureAirport)),
              DataCell(_AirportCellText(airport: item.arrivalAirport)),
              DataCell(Text(item.isActive ? 'Aktivna' : 'Neaktivna')),
              DataCell(Text(_formatDateTime(item.nextDepartureAtUtc))),
              DataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Uredi',
                      onPressed: () => _editDestination(item),
                      icon: const Icon(Icons.edit_rounded),
                    ),
                    IconButton(
                      tooltip: 'Obrisi',
                      onPressed: () => _deleteEntity(
                        title: item.routeCode,
                        onDelete: () async {
                          await _service.deleteDestination(
                            token: widget.token,
                            id: item.id,
                          );
                          await _reloadAfterMutation(refreshLookups: true);
                        },
                      ),
                      icon: const Icon(Icons.delete_outline_rounded),
                    ),
                  ],
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFlightsTable() {
    if (_flights.isEmpty) {
      return const _EmptyTableState(
        title: 'Nema letova za prikaz',
        message: 'Pokusajte druge filtere ili dodajte novi let.',
      );
    }

    return _TableScrollWrapper(
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Broj leta')),
          DataColumn(label: Text('Ruta')),
          DataColumn(label: Text('Aviokompanija')),
          DataColumn(label: Text('Polazak')),
          DataColumn(label: Text('Dolazak')),
          DataColumn(label: Text('Trajanje')),
          DataColumn(label: Text('Cijena')),
          DataColumn(label: Text('Sjedista')),
          DataColumn(label: Text('Status')),
          DataColumn(label: Text('Akcije')),
        ],
        rows: _flights.map((item) {
          return DataRow(
            cells: [
              DataCell(Text(item.flightNumber)),
              DataCell(Text(item.routeCode)),
              DataCell(Text('${item.airline.name} (${item.airline.code})')),
              DataCell(Text(_formatDateTime(item.departureAtUtc))),
              DataCell(Text(_formatDateTime(item.arrivalAtUtc))),
              DataCell(Text('${item.durationMinutes} min')),
              DataCell(Text('${item.basePrice.toStringAsFixed(2)} ${item.currency}')),
              DataCell(Text('${item.availableSeats}/${item.totalSeats}')),
              DataCell(Text(item.status.label)),
              DataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Uredi',
                      onPressed: () => _editFlight(item),
                      icon: const Icon(Icons.edit_rounded),
                    ),
                    IconButton(
                      tooltip: 'Obrisi',
                      onPressed: () => _deleteEntity(
                        title: item.flightNumber,
                        onDelete: () async {
                          await _service.deleteFlight(
                            token: widget.token,
                            id: item.id,
                          );
                          await _reloadAfterMutation(refreshLookups: true);
                        },
                      ),
                      icon: const Icon(Icons.delete_outline_rounded),
                    ),
                  ],
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
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

class _AirportCellText extends StatelessWidget {
  const _AirportCellText({required this.airport});

  final AirportSummary airport;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 220),
      child: Text(
        '${airport.iataCode} / ${airport.cityName}',
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _TableScrollWrapper extends StatelessWidget {
  const _TableScrollWrapper({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: child,
      ),
    );
  }
}

class _EmptyTableState extends StatelessWidget {
  const _EmptyTableState({
    required this.title,
    required this.message,
  });

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
            const Icon(Icons.inbox_outlined, size: 36),
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

class _DestinationDialog extends StatefulWidget {
  const _DestinationDialog({
    required this.airports,
    this.initial,
  });

  final List<AirportItem> airports;
  final DestinationDetails? initial;

  @override
  State<_DestinationDialog> createState() => _DestinationDialogState();
}

class _DestinationDialogState extends State<_DestinationDialog> {
  final _formKey = GlobalKey<FormState>();
  late int _departureAirportId;
  late int _arrivalAirportId;
  late bool _isActive;

  @override
  void initState() {
    super.initState();
    _departureAirportId = widget.initial?.departureAirport.id ??
        (widget.airports.isNotEmpty ? widget.airports.first.id : 0);
    _arrivalAirportId = widget.initial?.arrivalAirport.id ??
        (widget.airports.length > 1
            ? widget.airports[1].id
            : (widget.airports.isNotEmpty ? widget.airports.first.id : 0));
    _isActive = widget.initial?.isActive ?? true;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.initial == null ? 'Nova ruta' : 'Uredi rutu',
      ),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                initialValue: _departureAirportId == 0 ? null : _departureAirportId,
                decoration: const InputDecoration(
                  labelText: 'Polazni aerodrom',
                ),
                items: widget.airports
                    .map(
                      (airport) => DropdownMenuItem<int>(
                        value: airport.id,
                        child: Text(
                          '${airport.iataCode} / ${airport.cityName}',
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    _departureAirportId = value;
                  });
                },
                validator: (value) {
                  if (value == null || value <= 0) {
                    return 'Polazni aerodrom je obavezan.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _arrivalAirportId == 0 ? null : _arrivalAirportId,
                decoration: const InputDecoration(
                  labelText: 'Dolazni aerodrom',
                ),
                items: widget.airports
                    .map(
                      (airport) => DropdownMenuItem<int>(
                        value: airport.id,
                        child: Text(
                          '${airport.iataCode} / ${airport.cityName}',
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    _arrivalAirportId = value;
                  });
                },
                validator: (value) {
                  if (value == null || value <= 0) {
                    return 'Dolazni aerodrom je obavezan.';
                  }
                  if (value == _departureAirportId) {
                    return 'Polazni i dolazni aerodrom ne mogu biti isti.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _isActive,
                onChanged: (value) {
                  setState(() {
                    _isActive = value;
                  });
                },
                title: const Text('Aktivna ruta'),
                subtitle: const Text(
                  'Neaktivna ruta ostaje u sistemu, ali nije dostupna za nove letove.',
                ),
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

            Navigator.of(context).pop(
              _DestinationFormValue(
                departureAirportId: _departureAirportId,
                arrivalAirportId: _arrivalAirportId,
                isActive: _isActive,
              ),
            );
          },
          child: const Text('Sacuvaj'),
        ),
      ],
    );
  }
}

class _FlightDialog extends StatefulWidget {
  const _FlightDialog({
    required this.airlines,
    required this.destinations,
    this.initial,
  });

  final List<AirlineItem> airlines;
  final List<DestinationItem> destinations;
  final FlightDetails? initial;

  @override
  State<_FlightDialog> createState() => _FlightDialogState();
}

class _FlightDialogState extends State<_FlightDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _flightNumberController;
  late final TextEditingController _basePriceController;
  late final TextEditingController _totalSeatsController;
  late int _airlineId;
  late int _destinationId;
  late FlightStatusValue _status;
  late DateTime _departureAtLocal;
  late DateTime _arrivalAtLocal;

  @override
  void initState() {
    super.initState();
    _flightNumberController =
        TextEditingController(text: widget.initial?.flightNumber ?? '');
    _basePriceController = TextEditingController(
      text: widget.initial?.basePrice.toStringAsFixed(2) ?? '',
    );
    _totalSeatsController = TextEditingController(
      text: widget.initial?.totalSeats.toString() ?? '',
    );
    _airlineId = widget.initial?.airline.id ??
        (widget.airlines.isNotEmpty ? widget.airlines.first.id : 0);
    _destinationId = widget.initial?.destinationId ??
        (widget.destinations.isNotEmpty ? widget.destinations.first.id : 0);
    _status = widget.initial?.status ?? FlightStatusValue.scheduled;
    _departureAtLocal =
        (widget.initial?.departureAtUtc ?? DateTime.now()).toLocal();
    _arrivalAtLocal = (widget.initial?.arrivalAtUtc ??
            DateTime.now().add(const Duration(hours: 2)))
        .toLocal();
  }

  @override
  void dispose() {
    _flightNumberController.dispose();
    _basePriceController.dispose();
    _totalSeatsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null ? 'Novi let' : 'Uredi let'),
      content: SizedBox(
        width: 560,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: _airlineId == 0 ? null : _airlineId,
                  decoration: const InputDecoration(
                    labelText: 'Aviokompanija',
                  ),
                  items: widget.airlines
                      .map(
                        (airline) => DropdownMenuItem<int>(
                          value: airline.id,
                          child: Text('${airline.name} (${airline.code})'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() {
                      _airlineId = value;
                    });
                  },
                  validator: (value) {
                    if (value == null || value <= 0) {
                      return 'Aviokompanija je obavezna.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: _destinationId == 0 ? null : _destinationId,
                  decoration: const InputDecoration(
                    labelText: 'Ruta',
                  ),
                  items: widget.destinations
                      .map(
                        (destination) => DropdownMenuItem<int>(
                          value: destination.id,
                          child: Text(
                            '${destination.routeCode} / ${destination.departureAirport.cityName} -> ${destination.arrivalAirport.cityName}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() {
                      _destinationId = value;
                    });
                  },
                  validator: (value) {
                    if (value == null || value <= 0) {
                      return 'Ruta je obavezna.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _flightNumberController,
                  maxLength: 20,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Broj leta',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Broj leta je obavezan.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                _DateTimePickerField(
                  label: 'Polazak (lokalno vrijeme)',
                  value: _departureAtLocal,
                  onChanged: (value) {
                    setState(() {
                      _departureAtLocal = value;
                    });
                  },
                ),
                const SizedBox(height: 12),
                _DateTimePickerField(
                  label: 'Dolazak (lokalno vrijeme)',
                  value: _arrivalAtLocal,
                  onChanged: (value) {
                    setState(() {
                      _arrivalAtLocal = value;
                    });
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _basePriceController,
                        decoration: const InputDecoration(
                          labelText: 'Osnovna cijena',
                          hintText: 'npr. 149.90',
                        ),
                        validator: (value) {
                          final parsed = _parseDouble(value);
                          if (parsed == null || parsed <= 0) {
                            return 'Cijena mora biti veca od 0.';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _totalSeatsController,
                        decoration: const InputDecoration(
                          labelText: 'Ukupno sjedista',
                        ),
                        validator: (value) {
                          final parsed = int.tryParse((value ?? '').trim());
                          if (parsed == null || parsed < 1 || parsed > 300) {
                            return 'Broj mora biti 1-300.';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<FlightStatusValue>(
                  initialValue: _status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: FlightStatusValue.values
                      .map(
                        (status) => DropdownMenuItem<FlightStatusValue>(
                          value: status,
                          child: Text(status.label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() {
                      _status = value;
                    });
                  },
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Vrijeme se unosi lokalno, a backend ga cuva kao UTC.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
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
          onPressed: () {
            if (!_formKey.currentState!.validate()) {
              return;
            }

            if (!_arrivalAtLocal.isAfter(_departureAtLocal)) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Dolazak mora biti poslije polaska.'),
                ),
              );
              return;
            }

            Navigator.of(context).pop(
              _FlightFormValue(
                airlineId: _airlineId,
                destinationId: _destinationId,
                flightNumber: _flightNumberController.text.trim().toUpperCase(),
                departureAtLocal: _departureAtLocal,
                arrivalAtLocal: _arrivalAtLocal,
                basePrice: _parseDouble(_basePriceController.text)!,
                totalSeats: int.parse(_totalSeatsController.text.trim()),
                status: _status,
              ),
            );
          },
          child: const Text('Sacuvaj'),
        ),
      ],
    );
  }

  double? _parseDouble(String? value) {
    final normalized = (value ?? '').trim().replaceAll(',', '.');
    if (normalized.isEmpty) {
      return null;
    }

    return double.tryParse(normalized);
  }
}

class _DateTimePickerField extends StatelessWidget {
  const _DateTimePickerField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final DateTime value;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: value,
          firstDate: DateTime(2024),
          lastDate: DateTime(2100),
        );

        if (date == null || !context.mounted) {
          return;
        }

        final time = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.fromDateTime(value),
        );

        if (time == null) {
          return;
        }

        onChanged(
          DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          ),
        );
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.schedule_rounded),
        ),
        child: Text('$day.$month.${value.year}  $hour:$minute'),
      ),
    );
  }
}

class _DestinationFormValue {
  const _DestinationFormValue({
    required this.departureAirportId,
    required this.arrivalAirportId,
    required this.isActive,
  });

  final int departureAirportId;
  final int arrivalAirportId;
  final bool isActive;
}

class _FlightFormValue {
  const _FlightFormValue({
    required this.airlineId,
    required this.destinationId,
    required this.flightNumber,
    required this.departureAtLocal,
    required this.arrivalAtLocal,
    required this.basePrice,
    required this.totalSeats,
    required this.status,
  });

  final int airlineId;
  final int destinationId;
  final String flightNumber;
  final DateTime departureAtLocal;
  final DateTime arrivalAtLocal;
  final double basePrice;
  final int totalSeats;
  final FlightStatusValue status;
}
