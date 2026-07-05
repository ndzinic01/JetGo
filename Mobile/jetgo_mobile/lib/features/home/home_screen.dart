import 'package:flutter/material.dart';

import '../../core/network/api_exception.dart';
import '../auth/auth_controller.dart';
import 'change_password_screen.dart';
import 'edit_profile_screen.dart';
import 'flight_details_screen.dart';
import 'mobile_data_service.dart';
import 'mobile_display.dart';
import 'mobile_models.dart';
import 'notifications_screen.dart';
import 'reservation_details_screen.dart';
import 'support_messages_screen.dart';

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
  List<MobileRecommendedFlight> _recommendedFlights = const [];
  List<MobileReservation> _reservations = const [];
  List<NewsArticleSummary> _news = const [];
  MobileProfile? _profile;
  MobileNotificationSummary? _notificationSummary;
  String? _recommendationsErrorMessage;

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
          try {
            final recommendations = await _dataService.fetchRecommendedFlights(
              token: _token,
            );
            _recommendedFlights = recommendations.items;
            _recommendationsErrorMessage = null;
          } catch (_) {
            _recommendedFlights = const [];
            _recommendationsErrorMessage =
                'Preporuke trenutno nisu dostupne.';
          }
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

      await _loadNotificationSummary(silent: true);
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

  Future<void> _loadNotificationSummary({bool silent = false}) async {
    try {
      final summary = await _dataService.fetchNotificationSummary(token: _token);
      if (!mounted) {
        return;
      }

      setState(() {
        _notificationSummary = summary;
      });
    } catch (_) {
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notifikacije trenutno nisu dostupne.'),
          ),
        );
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

  Future<void> _openFlightDetails(MobileFlight flight) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => FlightDetailsScreen(
          token: _token,
          flightId: flight.id,
        ),
      ),
    );

    if (changed == true && mounted) {
      await _loadCurrentTab();
    }
  }

  Future<void> _openReservationDetails(MobileReservation reservation) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ReservationDetailsScreen(
          token: _token,
          reservationId: reservation.id,
        ),
      ),
    );

    if (changed == true && mounted) {
      await _loadCurrentTab();
    }
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => NotificationsScreen(token: _token),
      ),
    );

    if (mounted) {
      await _loadNotificationSummary(silent: true);
    }
  }

  Future<void> _openSupportMessages() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => SupportMessagesScreen(token: _token),
      ),
    );

    if (mounted) {
      await _loadNotificationSummary(silent: true);
    }
  }

  Future<void> _openEditProfile() async {
    final profile = _profile;
    if (profile == null) {
      return;
    }

    final updated = await Navigator.of(context).push<MobileProfile>(
      MaterialPageRoute<MobileProfile>(
        builder: (_) => EditProfileScreen(
          token: _token,
          profile: profile,
        ),
      ),
    );

    if (!mounted || updated == null) {
      return;
    }

    setState(() {
      _profile = updated;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profil je uspjesno azuriran.')),
    );
  }

  Future<void> _openChangePassword() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ChangePasswordScreen(token: _token),
      ),
    );

    if (!mounted || changed != true) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Lozinka je uspjesno promijenjena.')),
    );
  }

  Future<void> _openNewsPreview(NewsArticleSummary article) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        final theme = Theme.of(context);
        final imageUrl = article.imageUrl?.trim();

        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (imageUrl != null && imageUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) {
                            return child;
                          }

                          return Container(
                            color: theme.colorScheme.surfaceContainerHighest,
                            alignment: Alignment.center,
                            child: const CircularProgressIndicator(),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return const _NewsImagePlaceholder(
                            icon: Icons.image_not_supported_rounded,
                            message: 'Preview slike nije dostupan.',
                          );
                        },
                      ),
                    ),
                  )
                else
                  const _NewsImagePlaceholder(
                    icon: Icons.article_rounded,
                    message: 'Ova objava nema dodijeljenu sliku.',
                  ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'Objavljeno',
                        style: theme.textTheme.labelMedium,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        MobileDisplay.formatDateTime(article.publishedAtUtc),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  article.title,
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Text(
                  'Administracija je objavila ovu novost za putnike i korisnike aplikacije.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.authController.session?.user;
    final theme = Theme.of(context);
    final notificationSummary = _notificationSummary;
    final displayName = _profile?.fullName ?? user?.fullName ?? 'Dobrodosli';

    return Scaffold(
      appBar: AppBar(
        title: const Text('JetGo Mobile'),
        actions: [
          IconButton(
            tooltip: 'Notifikacije',
            onPressed: _openNotifications,
            icon: _NotificationBadgeIcon(
              unreadCount: notificationSummary?.unreadCount ?? 0,
            ),
          ),
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
                    : 'Prijavljeni ste kao $displayName',
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
        _buildRecommendationsSection(context),
        if (_recommendedFlights.isNotEmpty || _recommendationsErrorMessage != null)
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

  Widget _buildRecommendationsSection(BuildContext context) {
    if (_recommendationsErrorMessage != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Preporuceni letovi',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                _recommendationsErrorMessage!,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      );
    }

    if (_recommendedFlights.isEmpty) {
      return const SizedBox.shrink();
    }

    final topRecommendations = _recommendedFlights.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Preporuceni letovi',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 6),
        Text(
          'Na osnovu pretraga i historije rezervacija izdvajamo letove koji bi vam mogli biti najzanimljiviji.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        ...topRecommendations.map(_buildRecommendedFlightCard),
      ],
    );
  }

  Widget _buildRecommendedFlightCard(MobileRecommendedFlight flight) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => _openFlightDetails(
        MobileFlight(
          id: flight.id,
          flightNumber: flight.flightNumber,
          routeCode: flight.routeCode,
          airline: flight.airline,
          departureAirport: flight.departureAirport,
          arrivalAirport: flight.arrivalAirport,
          departureAtUtc: flight.departureAtUtc,
          arrivalAtUtc: flight.arrivalAtUtc,
          durationMinutes: flight.durationMinutes,
          basePrice: flight.basePrice,
          currency: flight.currency,
          availableSeats: flight.availableSeats,
          totalSeats: flight.totalSeats,
          status: flight.status,
        ),
      ),
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
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
                          '${flight.flightNumber} - ${flight.routeCode}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${flight.departureAirport.cityName} (${flight.departureAirport.iataCode}) -> ${flight.arrivalAirport.cityName} (${flight.arrivalAirport.iataCode})',
                        ),
                      ],
                    ),
                  ),
                  _StatusChip(
                    label: 'Score ${flight.recommendationScore}',
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                flight.recommendationReason,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: flight.appliedSignals
                    .map(
                      (signal) => Chip(
                        label: Text(signal),
                        visualDensity: VisualDensity.compact,
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 10),
              Text(
                'Polazak: ${MobileDisplay.formatDateTime(flight.departureAtUtc)}',
              ),
              const SizedBox(height: 4),
              Text(
                '${MobileDisplay.formatMoney(flight.basePrice, flight.currency)} - Slobodna sjedista ${flight.availableSeats}/${flight.totalSeats}',
              ),
            ],
          ),
        ),
      ),
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
        return InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _openReservationDetails(reservation),
          child: Card(
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
                        label: MobileDisplay.reservationStatusLabel(
                          reservation.status,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${reservation.flightNumber} - ${reservation.routeCode}',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${reservation.departureAirportCode} -> ${reservation.arrivalAirportCode}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Polazak: ${MobileDisplay.formatDateTime(reservation.departureAtUtc)}',
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Ukupno: ${MobileDisplay.formatMoney(reservation.totalAmount, reservation.currency)} - Sjedista: ${reservation.seatsCount}',
                  ),
                  const SizedBox(height: 4),
                  Text(
                    reservation.isPaid
                        ? 'Placanje evidentirano'
                        : 'Placanje jos nije evidentirano',
                  ),
                ],
              ),
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

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'JetGo novosti',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Ovdje pratite nove linije, savjete za putovanje i vazne obavijesti iz administracije.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ..._news.map(_buildNewsCard),
      ],
    );
  }

  Widget _buildNewsCard(NewsArticleSummary article) {
    final imageUrl = article.imageUrl?.trim();
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _openNewsPreview(article),
      child: Card(
        margin: const EdgeInsets.only(bottom: 14),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasImage)
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) {
                      return child;
                    }

                    return Container(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      alignment: Alignment.center,
                      child: const CircularProgressIndicator(),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return const _NewsImagePlaceholder(
                      icon: Icons.image_not_supported_rounded,
                      message: 'Slika nije dostupna.',
                    );
                  },
                ),
              )
            else
              const _NewsImagePlaceholder(
                icon: Icons.article_rounded,
                message: 'Objava bez naslovne slike',
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color:
                              Theme.of(context).colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Novost',
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          MobileDisplay.formatDateTime(article.publishedAtUtc),
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    article.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Dodirnite karticu za pregled objave.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant,
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
                      child: Text(MobileDisplay.initials(profile.fullName)),
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
                _InfoRow(
                  label: 'Neprocitane notifikacije',
                  value: (_notificationSummary?.unreadCount ?? 0).toString(),
                ),
                _InfoRow(label: 'Korisnik ID', value: profile.userId),
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
                  'Brze akcije',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _openEditProfile,
                      icon: const Icon(Icons.edit_rounded),
                      label: const Text('Uredi profil'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _openChangePassword,
                      icon: const Icon(Icons.lock_reset_rounded),
                      label: const Text('Promijeni lozinku'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _openSupportMessages,
                      icon: const Icon(Icons.support_agent_rounded),
                      label: const Text('Podrska'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _openNotifications,
                      icon: const Icon(Icons.notifications_rounded),
                      label: const Text('Notifikacije'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFlightCard(MobileFlight flight) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => _openFlightDetails(flight),
      child: Card(
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
                      '${flight.flightNumber} - ${flight.routeCode}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  _StatusChip(
                    label: MobileDisplay.flightStatusLabel(flight.status),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${flight.departureAirport.cityName} (${flight.departureAirport.iataCode}) -> ${flight.arrivalAirport.cityName} (${flight.arrivalAirport.iataCode})',
              ),
              const SizedBox(height: 4),
              Text('${flight.airline.name} - ${flight.airline.code}'),
              const SizedBox(height: 8),
              Text(
                'Polazak: ${MobileDisplay.formatDateTime(flight.departureAtUtc)}',
              ),
              Text(
                'Dolazak: ${MobileDisplay.formatDateTime(flight.arrivalAtUtc)}',
              ),
              const SizedBox(height: 8),
              Text(
                '${MobileDisplay.formatMoney(flight.basePrice, flight.currency)} - Slobodna sjedista ${flight.availableSeats}/${flight.totalSeats}',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationBadgeIcon extends StatelessWidget {
  const _NotificationBadgeIcon({required this.unreadCount});

  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Icon(Icons.notifications_none_rounded),
        if (unreadCount > 0)
          Positioned(
            right: -6,
            top: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.error,
                borderRadius: BorderRadius.circular(999),
              ),
              constraints: const BoxConstraints(minWidth: 18),
              child: Text(
                unreadCount > 99 ? '99+' : unreadCount.toString(),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onError,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _NewsImagePlaceholder extends StatelessWidget {
  const _NewsImagePlaceholder({
    required this.icon,
    required this.message,
  });

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 34, color: theme.colorScheme.primary),
          const SizedBox(height: 10),
          Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
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
