import 'package:flutter/material.dart';

import '../../core/network/api_exception.dart';
import 'reference_data_models.dart';
import 'reference_data_service.dart';

enum ReferenceDataTab {
  countries,
  cities,
  airports,
  airlines,
}

class ReferenceDataSection extends StatefulWidget {
  const ReferenceDataSection({required this.token, super.key});

  final String token;

  @override
  State<ReferenceDataSection> createState() => _ReferenceDataSectionState();
}

class _ReferenceDataSectionState extends State<ReferenceDataSection> {
  final ReferenceDataService _service = ReferenceDataService();
  final TextEditingController _countrySearchController =
      TextEditingController();
  final TextEditingController _citySearchController = TextEditingController();
  final TextEditingController _airportSearchController =
      TextEditingController();
  final TextEditingController _airlineSearchController =
      TextEditingController();

  ReferenceDataTab _selectedTab = ReferenceDataTab.countries;
  bool _isLoading = true;
  String? _errorMessage;

  List<CountryItem> _countries = const [];
  List<CityItem> _cities = const [];
  List<AirportItem> _airports = const [];
  List<AirlineItem> _airlines = const [];

  List<CountryItem> _allCountries = const [];
  List<CityItem> _allCities = const [];

  int? _cityCountryFilter;
  int? _airportCountryFilter;
  int? _airportCityFilter;
  bool? _airlineStatusFilter;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  @override
  void dispose() {
    _countrySearchController.dispose();
    _citySearchController.dispose();
    _airportSearchController.dispose();
    _airlineSearchController.dispose();
    super.dispose();
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
        _errorMessage = 'Reference podaci trenutno nisu dostupni.';
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshLookups() async {
    final countries = await _service.fetchCountries(
      token: widget.token,
      pageSize: 100,
    );
    final cities = await _service.fetchCities(
      token: widget.token,
      pageSize: 100,
    );

    _allCountries = countries.items;
    _allCities = cities.items;

    if (_cityCountryFilter != null &&
        !_allCountries.any((item) => item.id == _cityCountryFilter)) {
      _cityCountryFilter = null;
    }

    if (_airportCountryFilter != null &&
        !_allCountries.any((item) => item.id == _airportCountryFilter)) {
      _airportCountryFilter = null;
    }

    if (_airportCityFilter != null &&
        !_allCities.any((item) => item.id == _airportCityFilter)) {
      _airportCityFilter = null;
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
        case ReferenceDataTab.countries:
          final response = await _service.fetchCountries(
            token: widget.token,
            searchText: _countrySearchController.text,
          );
          _countries = response.items;
          break;
        case ReferenceDataTab.cities:
          final response = await _service.fetchCities(
            token: widget.token,
            searchText: _citySearchController.text,
            countryId: _cityCountryFilter,
          );
          _cities = response.items;
          break;
        case ReferenceDataTab.airports:
          final response = await _service.fetchAirports(
            token: widget.token,
            searchText: _airportSearchController.text,
            countryId: _airportCountryFilter,
            cityId: _airportCityFilter,
          );
          _airports = response.items;
          break;
        case ReferenceDataTab.airlines:
          final response = await _service.fetchAirlines(
            token: widget.token,
            searchText: _airlineSearchController.text,
            isActive: _airlineStatusFilter,
          );
          _airlines = response.items;
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

  Future<void> _openCountryDialog({CountryDetails? initial}) async {
    final value = await showDialog<_CountryFormValue>(
      context: context,
      builder: (context) => _CountryDialog(initial: initial),
    );

    if (value == null) {
      return;
    }

    try {
      if (initial == null) {
        await _service.createCountry(
          token: widget.token,
          name: value.name,
          isoCode: value.isoCode,
        );
      } else {
        await _service.updateCountry(
          token: widget.token,
          id: initial.id,
          name: value.name,
          isoCode: value.isoCode,
        );
      }

      if (!mounted) {
        return;
      }

      await _reloadAfterMutation(refreshLookups: true);
      _showMessage(
        initial == null
            ? 'Drzava je uspjesno dodana.'
            : 'Drzava je uspjesno azurirana.',
      );
    } on ApiException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Sacuvavanje drzave nije uspjelo.');
    }
  }

  Future<void> _editCountry(CountryItem item) async {
    try {
      final details = await _service.getCountry(token: widget.token, id: item.id);
      if (!mounted) {
        return;
      }
      await _openCountryDialog(initial: details);
    } on ApiException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Detalji drzave nisu dostupni.');
    }
  }

  Future<void> _openCityDialog({CityDetails? initial}) async {
    final value = await showDialog<_CityFormValue>(
      context: context,
      builder: (context) => _CityDialog(
        countries: _allCountries,
        initial: initial,
      ),
    );

    if (value == null) {
      return;
    }

    try {
      if (initial == null) {
        await _service.createCity(
          token: widget.token,
          countryId: value.countryId,
          name: value.name,
        );
      } else {
        await _service.updateCity(
          token: widget.token,
          id: initial.id,
          countryId: value.countryId,
          name: value.name,
        );
      }

      if (!mounted) {
        return;
      }

      await _reloadAfterMutation(refreshLookups: true);
      _showMessage(
        initial == null ? 'Grad je uspjesno dodan.' : 'Grad je uspjesno azuriran.',
      );
    } on ApiException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Sacuvavanje grada nije uspjelo.');
    }
  }

  Future<void> _editCity(CityItem item) async {
    try {
      final details = await _service.getCity(token: widget.token, id: item.id);
      if (!mounted) {
        return;
      }
      await _openCityDialog(initial: details);
    } on ApiException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Detalji grada nisu dostupni.');
    }
  }

  Future<void> _openAirportDialog({AirportDetails? initial}) async {
    final value = await showDialog<_AirportFormValue>(
      context: context,
      builder: (context) => _AirportDialog(
        cities: _allCities,
        initial: initial,
      ),
    );

    if (value == null) {
      return;
    }

    try {
      if (initial == null) {
        await _service.createAirport(
          token: widget.token,
          cityId: value.cityId,
          name: value.name,
          iataCode: value.iataCode,
          latitude: value.latitude,
          longitude: value.longitude,
        );
      } else {
        await _service.updateAirport(
          token: widget.token,
          id: initial.id,
          cityId: value.cityId,
          name: value.name,
          iataCode: value.iataCode,
          latitude: value.latitude,
          longitude: value.longitude,
        );
      }

      if (!mounted) {
        return;
      }

      await _reloadAfterMutation(refreshLookups: false);
      _showMessage(
        initial == null
            ? 'Aerodrom je uspjesno dodan.'
            : 'Aerodrom je uspjesno azuriran.',
      );
    } on ApiException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Sacuvavanje aerodroma nije uspjelo.');
    }
  }

  Future<void> _editAirport(AirportItem item) async {
    try {
      final details =
          await _service.getAirport(token: widget.token, id: item.id);
      if (!mounted) {
        return;
      }
      await _openAirportDialog(initial: details);
    } on ApiException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Detalji aerodroma nisu dostupni.');
    }
  }

  Future<void> _openAirlineDialog({AirlineDetails? initial}) async {
    final value = await showDialog<_AirlineFormValue>(
      context: context,
      builder: (context) => _AirlineDialog(initial: initial),
    );

    if (value == null) {
      return;
    }

    try {
      if (initial == null) {
        await _service.createAirline(
          token: widget.token,
          name: value.name,
          code: value.code,
          logoUrl: value.logoUrl,
          isActive: value.isActive,
        );
      } else {
        await _service.updateAirline(
          token: widget.token,
          id: initial.id,
          name: value.name,
          code: value.code,
          logoUrl: value.logoUrl,
          isActive: value.isActive,
        );
      }

      if (!mounted) {
        return;
      }

      await _reloadAfterMutation(refreshLookups: false);
      _showMessage(
        initial == null
            ? 'Aviokompanija je uspjesno dodana.'
            : 'Aviokompanija je uspjesno azurirana.',
      );
    } on ApiException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Sacuvavanje aviokompanije nije uspjelo.');
    }
  }

  Future<void> _editAirline(AirlineItem item) async {
    try {
      final details =
          await _service.getAirline(token: widget.token, id: item.id);
      if (!mounted) {
        return;
      }
      await _openAirlineDialog(initial: details);
    } on ApiException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Detalji aviokompanije nisu dostupni.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: SegmentedButton<ReferenceDataTab>(
            segments: const [
              ButtonSegment(
                value: ReferenceDataTab.countries,
                icon: Icon(Icons.flag_rounded),
                label: Text('Countries'),
              ),
              ButtonSegment(
                value: ReferenceDataTab.cities,
                icon: Icon(Icons.location_city_rounded),
                label: Text('Cities'),
              ),
              ButtonSegment(
                value: ReferenceDataTab.airports,
                icon: Icon(Icons.local_airport_rounded),
                label: Text('Airports'),
              ),
              ButtonSegment(
                value: ReferenceDataTab.airlines,
                icon: Icon(Icons.flight_rounded),
                label: Text('Airlines'),
              ),
            ],
            selected: <ReferenceDataTab>{_selectedTab},
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
      case ReferenceDataTab.countries:
        return Row(
          children: [
            Expanded(
              child: TextField(
                controller: _countrySearchController,
                onSubmitted: (_) => _loadCurrentTab(),
                decoration: const InputDecoration(
                  labelText: 'Pretraga drzava',
                  hintText: 'Naziv ili ISO kod',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: () => _openCountryDialog(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Nova drzava'),
            ),
            const SizedBox(width: 12),
            IconButton(
              tooltip: 'Osvjezi',
              onPressed: _loadCurrentTab,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        );
      case ReferenceDataTab.cities:
        return Row(
          children: [
            Expanded(
              child: TextField(
                controller: _citySearchController,
                onSubmitted: (_) => _loadCurrentTab(),
                decoration: const InputDecoration(
                  labelText: 'Pretraga gradova',
                  hintText: 'Naziv grada',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 220,
              child: DropdownButtonFormField<int?>(
                key: ValueKey<int?>(_cityCountryFilter),
                initialValue: _cityCountryFilter,
                decoration: const InputDecoration(labelText: 'Drzava'),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('Sve drzave'),
                  ),
                  ..._allCountries.map(
                    (country) => DropdownMenuItem<int?>(
                      value: country.id,
                      child: Text('${country.name} (${country.isoCode})'),
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _cityCountryFilter = value;
                  });
                  _loadCurrentTab();
                },
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: _allCountries.isEmpty ? null : () => _openCityDialog(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Novi grad'),
            ),
            const SizedBox(width: 12),
            IconButton(
              tooltip: 'Osvjezi',
              onPressed: _loadCurrentTab,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        );
      case ReferenceDataTab.airports:
        final filteredCities = _airportCountryFilter == null
            ? _allCities
            : _allCities
                .where((city) => city.countryId == _airportCountryFilter)
                .toList();

        return Row(
          children: [
            Expanded(
              child: TextField(
                controller: _airportSearchController,
                onSubmitted: (_) => _loadCurrentTab(),
                decoration: const InputDecoration(
                  labelText: 'Pretraga aerodroma',
                  hintText: 'Naziv ili IATA kod',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 220,
              child: DropdownButtonFormField<int?>(
                key: ValueKey<int?>(_airportCountryFilter),
                initialValue: _airportCountryFilter,
                decoration: const InputDecoration(labelText: 'Drzava'),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('Sve drzave'),
                  ),
                  ..._allCountries.map(
                    (country) => DropdownMenuItem<int?>(
                      value: country.id,
                      child: Text('${country.name} (${country.isoCode})'),
                    ),
                  ),
                ],
                onChanged: (value) {
                  final nextFilteredCities = value == null
                      ? _allCities
                      : _allCities
                          .where((city) => city.countryId == value)
                          .toList();
                  setState(() {
                    _airportCountryFilter = value;
                    if (_airportCityFilter != null &&
                        !nextFilteredCities
                            .any((city) => city.id == _airportCityFilter)) {
                      _airportCityFilter = null;
                    }
                  });
                  _loadCurrentTab();
                },
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 220,
              child: DropdownButtonFormField<int?>(
                key: ValueKey<String>(
                  'airport-city-${_airportCountryFilter ?? 'all'}-${_airportCityFilter ?? 'all'}',
                ),
                initialValue: _airportCityFilter,
                decoration: const InputDecoration(labelText: 'Grad'),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('Svi gradovi'),
                  ),
                  ...filteredCities.map(
                    (city) => DropdownMenuItem<int?>(
                      value: city.id,
                      child: Text('${city.name} / ${city.countryIsoCode}'),
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _airportCityFilter = value;
                  });
                  _loadCurrentTab();
                },
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: _allCities.isEmpty ? null : () => _openAirportDialog(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Novi aerodrom'),
            ),
            const SizedBox(width: 12),
            IconButton(
              tooltip: 'Osvjezi',
              onPressed: _loadCurrentTab,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        );
      case ReferenceDataTab.airlines:
        return Row(
          children: [
            Expanded(
              child: TextField(
                controller: _airlineSearchController,
                onSubmitted: (_) => _loadCurrentTab(),
                decoration: const InputDecoration(
                  labelText: 'Pretraga aviokompanija',
                  hintText: 'Naziv ili kod',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 180,
              child: DropdownButtonFormField<bool?>(
                key: ValueKey<bool?>(_airlineStatusFilter),
                initialValue: _airlineStatusFilter,
                decoration: const InputDecoration(labelText: 'Status'),
                items: const [
                  DropdownMenuItem<bool?>(
                    value: null,
                    child: Text('Sve'),
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
                    _airlineStatusFilter = value;
                  });
                  _loadCurrentTab();
                },
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: () => _openAirlineDialog(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Nova aviokompanija'),
            ),
            const SizedBox(width: 12),
            IconButton(
              tooltip: 'Osvjezi',
              onPressed: _loadCurrentTab,
              icon: const Icon(Icons.refresh_rounded),
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
      case ReferenceDataTab.countries:
        return _buildCountriesTable(context);
      case ReferenceDataTab.cities:
        return _buildCitiesTable(context);
      case ReferenceDataTab.airports:
        return _buildAirportsTable(context);
      case ReferenceDataTab.airlines:
        return _buildAirlinesTable(context);
    }
  }

  Widget _buildCountriesTable(BuildContext context) {
    if (_countries.isEmpty) {
      return const _EmptyTableState(
        title: 'Nema drzava za prikaz',
        message: 'Pokusajte drugu pretragu ili dodajte novu drzavu.',
      );
    }

    return _TableScrollWrapper(
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Naziv')),
          DataColumn(label: Text('ISO')),
          DataColumn(label: Text('Gradovi')),
          DataColumn(label: Text('Akcije')),
        ],
        rows: _countries.map((item) {
          return DataRow(
            cells: [
              DataCell(Text(item.name)),
              DataCell(Text(item.isoCode)),
              DataCell(Text(item.citiesCount.toString())),
              DataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Uredi',
                      onPressed: () => _editCountry(item),
                      icon: const Icon(Icons.edit_rounded),
                    ),
                    IconButton(
                      tooltip: 'Obrisi',
                      onPressed: () => _deleteEntity(
                        title: item.name,
                        onDelete: () async {
                          await _service.deleteCountry(
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

  Widget _buildCitiesTable(BuildContext context) {
    if (_cities.isEmpty) {
      return const _EmptyTableState(
        title: 'Nema gradova za prikaz',
        message: 'Pokusajte druge filtere ili dodajte novi grad.',
      );
    }

    return _TableScrollWrapper(
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Grad')),
          DataColumn(label: Text('Drzava')),
          DataColumn(label: Text('ISO')),
          DataColumn(label: Text('Aerodromi')),
          DataColumn(label: Text('Akcije')),
        ],
        rows: _cities.map((item) {
          return DataRow(
            cells: [
              DataCell(Text(item.name)),
              DataCell(Text(item.countryName)),
              DataCell(Text(item.countryIsoCode)),
              DataCell(Text(item.airportsCount.toString())),
              DataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Uredi',
                      onPressed: () => _editCity(item),
                      icon: const Icon(Icons.edit_rounded),
                    ),
                    IconButton(
                      tooltip: 'Obrisi',
                      onPressed: () => _deleteEntity(
                        title: item.name,
                        onDelete: () async {
                          await _service.deleteCity(
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

  Widget _buildAirportsTable(BuildContext context) {
    if (_airports.isEmpty) {
      return const _EmptyTableState(
        title: 'Nema aerodroma za prikaz',
        message: 'Pokusajte druge filtere ili dodajte novi aerodrom.',
      );
    }

    return _TableScrollWrapper(
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Aerodrom')),
          DataColumn(label: Text('IATA')),
          DataColumn(label: Text('Grad')),
          DataColumn(label: Text('Drzava')),
          DataColumn(label: Text('Koordinate')),
          DataColumn(label: Text('Destinacije')),
          DataColumn(label: Text('Akcije')),
        ],
        rows: _airports.map((item) {
          return DataRow(
            cells: [
              DataCell(Text(item.name)),
              DataCell(Text(item.iataCode)),
              DataCell(Text(item.cityName)),
              DataCell(Text(item.countryName)),
              DataCell(
                Text(
                  '${_formatNullableDouble(item.latitude)}, ${_formatNullableDouble(item.longitude)}',
                ),
              ),
              DataCell(Text(item.relatedDestinationsCount.toString())),
              DataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Uredi',
                      onPressed: () => _editAirport(item),
                      icon: const Icon(Icons.edit_rounded),
                    ),
                    IconButton(
                      tooltip: 'Obrisi',
                      onPressed: () => _deleteEntity(
                        title: item.name,
                        onDelete: () async {
                          await _service.deleteAirport(
                            token: widget.token,
                            id: item.id,
                          );
                          await _reloadAfterMutation(refreshLookups: false);
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

  Widget _buildAirlinesTable(BuildContext context) {
    if (_airlines.isEmpty) {
      return const _EmptyTableState(
        title: 'Nema aviokompanija za prikaz',
        message: 'Pokusajte druge filtere ili dodajte novu aviokompaniju.',
      );
    }

    return _TableScrollWrapper(
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Naziv')),
          DataColumn(label: Text('Kod')),
          DataColumn(label: Text('Status')),
          DataColumn(label: Text('Letovi')),
          DataColumn(label: Text('Logo URL')),
          DataColumn(label: Text('Akcije')),
        ],
        rows: _airlines.map((item) {
          return DataRow(
            cells: [
              DataCell(Text(item.name)),
              DataCell(Text(item.code)),
              DataCell(Text(item.isActive ? 'Aktivna' : 'Neaktivna')),
              DataCell(Text(item.flightsCount.toString())),
              DataCell(
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 220),
                  child: Text(
                    item.logoUrl?.trim().isNotEmpty == true ? item.logoUrl! : '-',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              DataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Uredi',
                      onPressed: () => _editAirline(item),
                      icon: const Icon(Icons.edit_rounded),
                    ),
                    IconButton(
                      tooltip: 'Obrisi',
                      onPressed: () => _deleteEntity(
                        title: item.name,
                        onDelete: () async {
                          await _service.deleteAirline(
                            token: widget.token,
                            id: item.id,
                          );
                          await _reloadAfterMutation(refreshLookups: false);
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

  String _formatNullableDouble(double? value) {
    if (value == null) {
      return '-';
    }
    return value.toStringAsFixed(4);
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

class _CountryDialog extends StatefulWidget {
  const _CountryDialog({this.initial});

  final CountryDetails? initial;

  @override
  State<_CountryDialog> createState() => _CountryDialogState();
}

class _CountryDialogState extends State<_CountryDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _isoCodeController;

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.initial?.name ?? '');
    _isoCodeController =
        TextEditingController(text: widget.initial?.isoCode ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _isoCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null ? 'Nova drzava' : 'Uredi drzavu'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Naziv'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Naziv je obavezan.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _isoCodeController,
                textCapitalization: TextCapitalization.characters,
                maxLength: 2,
                decoration: const InputDecoration(labelText: 'ISO kod'),
                validator: (value) {
                  if (value == null || value.trim().length != 2) {
                    return 'ISO kod mora imati tacno 2 karaktera.';
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
            if (_formKey.currentState?.validate() != true) {
              return;
            }

            Navigator.of(context).pop(
              _CountryFormValue(
                name: _nameController.text,
                isoCode: _isoCodeController.text,
              ),
            );
          },
          child: const Text('Sacuvaj'),
        ),
      ],
    );
  }
}

class _CityDialog extends StatefulWidget {
  const _CityDialog({
    required this.countries,
    this.initial,
  });

  final List<CountryItem> countries;
  final CityDetails? initial;

  @override
  State<_CityDialog> createState() => _CityDialogState();
}

class _CityDialogState extends State<_CityDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late int? _countryId;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initial?.name ?? '');
    _countryId = widget.initial?.countryId ??
        (widget.countries.isNotEmpty ? widget.countries.first.id : null);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null ? 'Novi grad' : 'Uredi grad'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                initialValue: _countryId,
                decoration: const InputDecoration(labelText: 'Drzava'),
                items: widget.countries
                    .map(
                      (country) => DropdownMenuItem<int>(
                        value: country.id,
                        child: Text('${country.name} (${country.isoCode})'),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _countryId = value;
                  });
                },
                validator: (value) {
                  if (value == null) {
                    return 'Drzava je obavezna.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Naziv grada'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Naziv grada je obavezan.';
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
            if (_formKey.currentState?.validate() != true || _countryId == null) {
              return;
            }

            Navigator.of(context).pop(
              _CityFormValue(
                countryId: _countryId!,
                name: _nameController.text,
              ),
            );
          },
          child: const Text('Sacuvaj'),
        ),
      ],
    );
  }
}

class _AirportDialog extends StatefulWidget {
  const _AirportDialog({
    required this.cities,
    this.initial,
  });

  final List<CityItem> cities;
  final AirportDetails? initial;

  @override
  State<_AirportDialog> createState() => _AirportDialogState();
}

class _AirportDialogState extends State<_AirportDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _iataController;
  late final TextEditingController _latitudeController;
  late final TextEditingController _longitudeController;
  late int? _cityId;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initial?.name ?? '');
    _iataController =
        TextEditingController(text: widget.initial?.iataCode ?? '');
    _latitudeController = TextEditingController(
      text: widget.initial?.latitude?.toString() ?? '',
    );
    _longitudeController = TextEditingController(
      text: widget.initial?.longitude?.toString() ?? '',
    );
    _cityId = widget.initial?.cityId ??
        (widget.cities.isNotEmpty ? widget.cities.first.id : null);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _iataController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null ? 'Novi aerodrom' : 'Uredi aerodrom'),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                initialValue: _cityId,
                decoration: const InputDecoration(labelText: 'Grad'),
                items: widget.cities
                    .map(
                      (city) => DropdownMenuItem<int>(
                        value: city.id,
                        child: Text('${city.name} / ${city.countryIsoCode}'),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _cityId = value;
                  });
                },
                validator: (value) {
                  if (value == null) {
                    return 'Grad je obavezan.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Naziv aerodroma'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Naziv aerodroma je obavezan.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _iataController,
                maxLength: 3,
                decoration: const InputDecoration(labelText: 'IATA kod'),
                validator: (value) {
                  if (value == null || value.trim().length != 3) {
                    return 'IATA kod mora imati tacno 3 karaktera.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _latitudeController,
                      decoration: const InputDecoration(labelText: 'Latitude'),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return null;
                        }
                        if (double.tryParse(value.trim()) == null) {
                          return 'Broj';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _longitudeController,
                      decoration: const InputDecoration(labelText: 'Longitude'),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return null;
                        }
                        if (double.tryParse(value.trim()) == null) {
                          return 'Broj';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
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
            if (_formKey.currentState?.validate() != true || _cityId == null) {
              return;
            }

            Navigator.of(context).pop(
              _AirportFormValue(
                cityId: _cityId!,
                name: _nameController.text,
                iataCode: _iataController.text,
                latitude: _parseOptionalDouble(_latitudeController.text),
                longitude: _parseOptionalDouble(_longitudeController.text),
              ),
            );
          },
          child: const Text('Sacuvaj'),
        ),
      ],
    );
  }

  double? _parseOptionalDouble(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return double.tryParse(trimmed);
  }
}

class _AirlineDialog extends StatefulWidget {
  const _AirlineDialog({this.initial});

  final AirlineDetails? initial;

  @override
  State<_AirlineDialog> createState() => _AirlineDialogState();
}

class _AirlineDialogState extends State<_AirlineDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _codeController;
  late final TextEditingController _logoUrlController;
  late bool _isActive;

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.initial?.name ?? '');
    _codeController =
        TextEditingController(text: widget.initial?.code ?? '');
    _logoUrlController =
        TextEditingController(text: widget.initial?.logoUrl ?? '');
    _isActive = widget.initial?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _logoUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.initial == null ? 'Nova aviokompanija' : 'Uredi aviokompaniju',
      ),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Naziv'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Naziv je obavezan.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _codeController,
                decoration: const InputDecoration(labelText: 'Kod'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Kod je obavezan.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _logoUrlController,
                decoration: const InputDecoration(labelText: 'Logo URL'),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                value: _isActive,
                onChanged: (value) {
                  setState(() {
                    _isActive = value;
                  });
                },
                title: const Text('Aktivna aviokompanija'),
                contentPadding: EdgeInsets.zero,
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
            if (_formKey.currentState?.validate() != true) {
              return;
            }

            Navigator.of(context).pop(
              _AirlineFormValue(
                name: _nameController.text,
                code: _codeController.text,
                logoUrl: _logoUrlController.text,
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

class _CountryFormValue {
  _CountryFormValue({
    required this.name,
    required this.isoCode,
  });

  final String name;
  final String isoCode;
}

class _CityFormValue {
  _CityFormValue({
    required this.countryId,
    required this.name,
  });

  final int countryId;
  final String name;
}

class _AirportFormValue {
  _AirportFormValue({
    required this.cityId,
    required this.name,
    required this.iataCode,
    this.latitude,
    this.longitude,
  });

  final int cityId;
  final String name;
  final String iataCode;
  final double? latitude;
  final double? longitude;
}

class _AirlineFormValue {
  _AirlineFormValue({
    required this.name,
    required this.code,
    required this.logoUrl,
    required this.isActive,
  });

  final String name;
  final String code;
  final String logoUrl;
  final bool isActive;
}
