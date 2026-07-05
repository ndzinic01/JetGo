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
  static const _heroImageUrl =
      'https://images.unsplash.com/photo-1436491865332-7a61a109cc05?auto=format&fit=crop&w=1400&q=80';

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
    final notificationSummary = _notificationSummary;

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
        child: RefreshIndicator(
          onRefresh: _loadCurrentTab,
          child: _buildBody(context),
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _buildFlightsHero(context),
        const SizedBox(height: 16),
        _buildSearchPanel(context),
        const SizedBox(height: 20),
        _buildRecommendationsSection(context),
        const SizedBox(height: 20),
        _SectionHeader(
          title: 'Dostupni letovi',
          subtitle: userFriendlySearchLabel(),
        ),
        const SizedBox(height: 10),
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

  String userFriendlySearchLabel() {
    final query = _flightSearchController.text.trim();
    if (query.isEmpty) {
      return 'Pregled svih aktivnih i dostupnih opcija za putovanje.';
    }

    return 'Rezultati za pojam: "$query".';
  }

  Widget _buildFlightsHero(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 230,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              _heroImageUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: theme.colorScheme.primary.withValues(alpha: 0.14),
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
                    Colors.black.withValues(alpha: 0.34),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Spacer(),
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.82),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.menu_rounded),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    'Find your flight',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontSize: 32,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Brza pretraga letova, rezervacija i preporuka na jednom mjestu.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
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

  Widget _buildSearchPanel(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pretraga letova',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _flightSearchController,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _loadCurrentTab(),
              decoration: InputDecoration(
                labelText: 'Grad, aerodrom ili oznaka rute',
                hintText: 'npr. Sarajevo, VIE ili BNX-VIE',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: IconButton(
                  tooltip: 'Pokreni pretragu',
                  onPressed: _loadCurrentTab,
                  icon: const Icon(Icons.arrow_forward_rounded),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Prijavljeni ste kao ${_profile?.fullName ?? widget.authController.session?.user.fullName ?? 'korisnik'}',
                  ),
                ),
                FilledButton(
                  onPressed: _loadCurrentTab,
                  child: const Text('Pretrazi'),
                ),
              ],
            ),
          ],
        ),
      ),
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
                'Preporuceno za vas',
                style: Theme.of(context).textTheme.titleLarge,
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
      return const _EmptyState(
        icon: Icons.travel_explore_rounded,
        title: 'Preporuke jos nisu spremne',
        message: 'Nakon nekoliko pretraga i rezervacija ovdje ce se pojaviti personalizovani prijedlozi.',
      );
    }

    final topRecommendations = _recommendedFlights.take(6).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(
          title: 'Preporuceno za vas',
          subtitle: 'Najzanimljivije opcije na osnovu pretraga i historije rezervacija.',
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: topRecommendations.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.78,
          ),
          itemBuilder: (context, index) {
            return _buildRecommendedFlightCard(topRecommendations[index]);
          },
        ),
      ],
    );
  }

  Widget _buildRecommendedFlightCard(MobileRecommendedFlight flight) {
    final imageUrl = _destinationImageFor(
      cityName: flight.arrivalAirport.cityName,
      airportCode: flight.arrivalAirport.iataCode,
      routeCode: flight.routeCode,
    );

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
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1.08,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Theme.of(context)
                            .colorScheme
                            .secondaryContainer,
                        alignment: Alignment.center,
                        child: const Icon(Icons.flight_rounded, size: 34),
                      );
                    },
                  ),
                  Positioned(
                    left: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        MobileDisplay.formatMoney(
                          flight.basePrice,
                          flight.currency,
                        ),
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${flight.departureAirport.cityName} -> ${flight.arrivalAirport.cityName}',
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${flight.routeCode}  |  ${flight.flightNumber}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    MobileDisplay.formatDateTime(flight.departureAtUtc),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
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
                  if (reservation.additionalBaggageCount > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Dodatni prtljag: ${MobileDisplay.baggageOfferLabel(reservation.additionalBaggageCount)}',
                    ),
                  ],
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
                _InfoRow(label: 'Uloge', value: profile.roles.join(', ')),
                _InfoRow(
                  label: 'Neprocitane notifikacije',
                  value: (_notificationSummary?.unreadCount ?? 0).toString(),
                ),
                _InfoRow(label: 'ID korisnika', value: profile.userId),
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
    final imageUrl = _destinationImageFor(
      cityName: flight.arrivalAirport.cityName,
      airportCode: flight.arrivalAirport.iataCode,
      routeCode: flight.routeCode,
    );

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => _openFlightDetails(flight),
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 112,
              width: double.infinity,
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    alignment: Alignment.center,
                    child: const Icon(Icons.flight_rounded, size: 34),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${flight.departureAirport.cityName} -> ${flight.arrivalAirport.cityName}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      _StatusChip(
                        label: MobileDisplay.flightStatusLabel(flight.status),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${flight.flightNumber}  |  ${flight.airline.name}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Polazak: ${MobileDisplay.formatDateTime(flight.departureAtUtc)}',
                  ),
                  Text(
                    'Dolazak: ${MobileDisplay.formatDateTime(flight.arrivalAtUtc)}',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${MobileDisplay.formatMoney(flight.basePrice, flight.currency)}  |  Slobodna sjedista ${flight.availableSeats}/${flight.totalSeats}',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _destinationImageFor({
    required String cityName,
    required String airportCode,
    required String routeCode,
  }) {
    final key = '${cityName.toLowerCase()} ${airportCode.toLowerCase()} ${routeCode.toLowerCase()}';

    if (key.contains('paris') || key.contains('cdg')) {
      return 'https://images.unsplash.com/photo-1502602898657-3e91760cbb34?auto=format&fit=crop&w=900&q=80';
    }
    if (key.contains('rome') || key.contains('fco')) {
      return 'https://images.unsplash.com/photo-1525874684015-58379d421a52?auto=format&fit=crop&w=900&q=80';
    }
    if (key.contains('istanbul') || key.contains('ist')) {
      return 'https://images.unsplash.com/photo-1541432901042-2d8bd64b4a9b?auto=format&fit=crop&w=900&q=80';
    }
    if (key.contains('berlin') || key.contains('ber')) {
      return 'https://images.unsplash.com/photo-1560969184-10fe8719e047?auto=format&fit=crop&w=900&q=80';
    }
    if (key.contains('vienna') || key.contains('vie') || key.contains('bec')) {
      return 'https://images.unsplash.com/photo-1516550893923-42d28e5677af?auto=format&fit=crop&w=900&q=80';
    }
    if (key.contains('zurich') || key.contains('zrh')) {
      return 'https://images.unsplash.com/photo-1502602898657-3e91760cbb34?auto=format&fit=crop&w=900&q=80';
    }
    if (key.contains('zagreb') || key.contains('zag')) {
      return 'https://images.unsplash.com/photo-1590080875515-8a3a8dc5735e?auto=format&fit=crop&w=900&q=80';
    }
    if (key.contains('frankfurt') || key.contains('fra')) {
      return 'https://images.unsplash.com/photo-1473448912268-2022ce9509d8?auto=format&fit=crop&w=900&q=80';
    }
    if (key.contains('belgrade') || key.contains('beograd') || key.contains('beg')) {
      return 'https://images.unsplash.com/photo-1578922746465-3a80a228f223?auto=format&fit=crop&w=900&q=80';
    }

    return _heroImageUrl;
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
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
