import 'package:flutter/material.dart';

import '../../core/network/api_exception.dart';
import '../auth/auth_controller.dart';
import 'mobile_data_service.dart';
import 'mobile_models.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({required this.authController, super.key});

  final AuthController authController;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MobileDataService _dataService = MobileDataService();
  final TextEditingController _flightSearchController = TextEditingController();

  int _currentIndex = 0;
  bool _isLoading = true;
  String? _errorMessage;

  List<MobileFlight> _flights = const [];
  List<MobileReservation> _reservations = const [];
  List<NewsArticleSummary> _news = const [];
  MobileProfile? _profile;

  String get _token => widget.authController.session?.accessToken ?? '';

  @override
  void initState() {
    super.initState();
    _loadCurrentTab();
  }

  @override
  void dispose() {
    _flightSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentTab() async {
    if (_token.isEmpty) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      switch (_currentIndex) {
        case 0:
          final flights = await _dataService.fetchFlights(
            token: _token,
            searchText: _flightSearchController.text,
          );
          _flights = flights.items;
          break;
        case 1:
          final reservations =
              await _dataService.fetchMyReservations(token: _token);
          _reservations = reservations.items;
          break;
        case 2:
          final news = await _dataService.fetchNews(token: _token);
          _news = news.items;
          break;
        case 3:
          _profile = await _dataService.fetchMyProfile(token: _token);
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

  void _changeTab(int index) {
    if (_currentIndex == index) {
      _loadCurrentTab();
      return;
    }

    setState(() {
      _currentIndex = index;
    });
    _loadCurrentTab();
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.authController.session?.user;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('JetGo Mobile'),
        actions: [
          IconButton(
            tooltip: 'Osvjezi',
            onPressed: _isLoading ? null : _loadCurrentTab,
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: 'Odjava',
            onPressed: widget.authController.logout,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              color: theme.colorScheme.surfaceContainerHighest,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text(
                user == null
                    ? 'Dobrodosli'
                    : 'Prijavljeni ste kao ${user.fullName}',
                style: theme.textTheme.bodyMedium,
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadCurrentTab,
                child: _buildBody(context),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _changeTab,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.flight_takeoff_rounded),
            label: 'Letovi',
          ),
          NavigationDestination(
            icon: Icon(Icons.confirmation_num_outlined),
            label: 'Rezervacije',
          ),
          NavigationDestination(
            icon: Icon(Icons.article_outlined),
            label: 'Novosti',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            label: 'Profil',
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          _EmptyState(
            icon: Icons.cloud_off_rounded,
            title: 'Podaci nisu dostupni',
            message: _errorMessage!,
          ),
        ],
      );
    }

    switch (_currentIndex) {
      case 0:
        return _buildFlightsTab(context);
      case 1:
        return _buildReservationsTab(context);
      case 2:
        return _buildNewsTab(context);
      case 3:
        return _buildProfileTab(context);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildFlightsTab(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _flightSearchController,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _loadCurrentTab(),
          decoration: InputDecoration(
            labelText: 'Pretraga letova',
            hintText: 'Unesite grad, aerodrom ili oznaku rute',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: IconButton(
              tooltip: 'Pokreni pretragu',
              onPressed: _loadCurrentTab,
              icon: const Icon(Icons.arrow_forward_rounded),
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (_flights.isEmpty)
          const _EmptyState(
            icon: Icons.flight_rounded,
            title: 'Nema rezultata',
            message: 'Trenutno nema letova za prikaz po zadanim filterima.',
          )
        else
          ..._flights.map(_buildFlightCard),
      ],
    );
  }

  Widget _buildReservationsTab(BuildContext context) {
    if (_reservations.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: const [
          _EmptyState(
            icon: Icons.luggage_rounded,
            title: 'Jos nemate rezervacija',
            message: 'Kada napravite rezervaciju, ovdje cete vidjeti historiju i statuse.',
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: _reservations.length,
      itemBuilder: (context, index) {
        final reservation = _reservations[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        reservation.reservationCode,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    _StatusChip(
                      label: _reservationStatusLabel(reservation.status),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${reservation.flightNumber} • ${reservation.routeCode}',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  '${reservation.departureAirportCode} -> ${reservation.arrivalAirportCode}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Polazak: ${_formatDateTime(reservation.departureAtUtc)}',
                ),
                const SizedBox(height: 4),
                Text(
                  'Ukupno: ${_formatMoney(reservation.totalAmount, reservation.currency)} • Sjedišta: ${reservation.seatsCount}',
                ),
                const SizedBox(height: 4),
                Text(
                  reservation.isPaid ? 'Placanje evidentirano' : 'Placanje jos nije evidentirano',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNewsTab(BuildContext context) {
    if (_news.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: const [
          _EmptyState(
            icon: Icons.newspaper_rounded,
            title: 'Nema objavljenih novosti',
            message: 'Kada administracija objavi obavijesti, pojavit ce se ovdje.',
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: _news.length,
      itemBuilder: (context, index) {
        final article = _news[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  article.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Objavljeno: ${_formatDateTime(article.publishedAtUtc)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (article.imageUrl != null && article.imageUrl!.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    article.imageUrl!,
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileTab(BuildContext context) {
    final profile = _profile;
    if (profile == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: const [
          _EmptyState(
            icon: Icons.person_off_rounded,
            title: 'Profil nije ucitan',
            message: 'Pokusajte ponovo nakon osvjezavanja.',
          ),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      child: Text(
                        _initials(profile.fullName),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile.fullName,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 4),
                          Text('@${profile.username}'),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _InfoRow(label: 'Email', value: profile.email),
                _InfoRow(label: 'Telefon', value: profile.phoneNumber ?? '-'),
                _InfoRow(label: 'Role', value: profile.roles.join(', ')),
                _InfoRow(label: 'Korisnik ID', value: profile.userId),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFlightCard(MobileFlight flight) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${flight.flightNumber} • ${flight.routeCode}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                _StatusChip(label: _flightStatusLabel(flight.status)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${flight.departureAirport.cityName} (${flight.departureAirport.iataCode}) -> ${flight.arrivalAirport.cityName} (${flight.arrivalAirport.iataCode})',
            ),
            const SizedBox(height: 4),
            Text('${flight.airline.name} • ${flight.airline.code}'),
            const SizedBox(height: 8),
            Text('Polazak: ${_formatDateTime(flight.departureAtUtc)}'),
            Text('Dolazak: ${_formatDateTime(flight.arrivalAtUtc)}'),
            const SizedBox(height: 8),
            Text(
              '${_formatMoney(flight.basePrice, flight.currency)} • Slobodna sjedišta ${flight.availableSeats}/${flight.totalSeats}',
            ),
          ],
        ),
      ),
    );
  }

  String _flightStatusLabel(int status) {
    switch (status) {
      case 1:
        return 'Scheduled';
      case 2:
        return 'Delayed';
      case 3:
        return 'Cancelled';
      case 4:
        return 'Completed';
      default:
        return 'Unknown';
    }
  }

  String _reservationStatusLabel(int status) {
    switch (status) {
      case 1:
        return 'Pending';
      case 2:
        return 'Confirmed';
      case 3:
        return 'Cancelled';
      case 4:
        return 'Completed';
      default:
        return 'Unknown';
    }
  }

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    return '${_two(local.day)}.${_two(local.month)}.${local.year} ${_two(local.hour)}:${_two(local.minute)}';
  }

  String _formatMoney(double value, String currency) {
    return '${value.toStringAsFixed(2)} $currency';
  }

  String _two(int value) => value.toString().padLeft(2, '0');

  String _initials(String value) {
    final parts = value
        .split(' ')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) {
      return 'JG';
    }

    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }

    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
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
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
