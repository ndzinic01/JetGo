import 'dart:async';

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
  final TextEditingController _departureSearchController =
      TextEditingController();
  final TextEditingController _arrivalSearchController =
      TextEditingController();

  int _currentIndex = 0;
  bool _isLoading = true;
  String? _errorMessage;

  List<MobileFlight> _allFlights = const [];
  List<MobileFlight> _flights = const [];
  List<MobileRecommendedFlight> _recommendedFlights = const [];
  List<MobileReservation> _reservations = const [];
  List<NewsArticleSummary> _news = const [];
  MobileProfile? _profile;
  MobileNotificationSummary? _notificationSummary;
  String? _recommendationsErrorMessage;
  DateTime? _departureFromDate;
  DateTime? _departureToDate;
  String? _selectedAirlineCode;

  String get _token => widget.authController.session?.accessToken ?? '';

  String get _currentSectionTitle {
    switch (_currentIndex) {
      case 0:
        return 'Letovi';
      case 1:
        return 'Rezervacije';
      case 2:
        return 'Novosti';
      case 3:
        return 'Moj profil';
      default:
        return 'JetGo Mobile';
    }
  }

  @override
  void initState() {
    super.initState();
    _loadCurrentTab();
  }

  @override
  void dispose() {
    _departureSearchController.dispose();
    _arrivalSearchController.dispose();
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
          );
          _allFlights = flights.items;
          _flights = _filterFlights(_allFlights);
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

  Future<void> _handleMenuAction(_HomeMenuAction action) async {
    switch (action) {
      case _HomeMenuAction.letovi:
        _changeTab(0);
        break;
      case _HomeMenuAction.rezervacije:
        _changeTab(1);
        break;
      case _HomeMenuAction.novosti:
        _changeTab(2);
        break;
      case _HomeMenuAction.profil:
        _changeTab(3);
        break;
      case _HomeMenuAction.podrska:
        await _openSupportMessages();
        break;
      case _HomeMenuAction.odjava:
        widget.authController.logout();
        break;
    }
  }

  Future<void> _trackRecommendationSearchSignal() async {
    final searchText = _buildRecommendationSearchText();
    if (searchText == null || _token.isEmpty) {
      return;
    }

    try {
      await _dataService.fetchFlights(
        token: _token,
        searchText: searchText,
      );

      final recommendations = await _dataService.fetchRecommendedFlights(
        token: _token,
        pageSize: 6,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _recommendedFlights = recommendations.items;
        _recommendationsErrorMessage = null;
      });
    } catch (_) {
      // Ignorisemo problem pri pracenju preporuka da ne prekidamo korisnika.
    }
  }

  String? _buildRecommendationSearchText() {
    final parts = <String>[
      _departureSearchController.text.trim(),
      _arrivalSearchController.text.trim(),
      _selectedAirlineCode?.trim() ?? '',
    ].where((value) => value.isNotEmpty).toList();

    if (parts.isEmpty) {
      return null;
    }

    return parts.join(' ');
  }

  List<MobileFlight> get _airlineSortedFlights {
    final flights = _allFlights.toList()
      ..sort((left, right) => left.airline.name.compareTo(right.airline.name));
    return flights;
  }

  List<AirlineSummary> get _availableAirlines {
    final unique = <String, AirlineSummary>{};
    for (final flight in _airlineSortedFlights) {
      unique.putIfAbsent(flight.airline.code, () => flight.airline);
    }

    return unique.values.toList();
  }

  List<MobileFlight> _filterFlights(List<MobileFlight> flights) {
    final departureQuery = _departureSearchController.text.trim().toLowerCase();
    final arrivalQuery = _arrivalSearchController.text.trim().toLowerCase();

    return flights.where((flight) {
      final matchesDeparture =
          departureQuery.isEmpty ||
          _matchFlightLocation(
            query: departureQuery,
            cityName: flight.departureAirport.cityName,
            airportCode: flight.departureAirport.iataCode,
            airportName: flight.departureAirport.name,
          );
      final matchesArrival =
          arrivalQuery.isEmpty ||
          _matchFlightLocation(
            query: arrivalQuery,
            cityName: flight.arrivalAirport.cityName,
            airportCode: flight.arrivalAirport.iataCode,
            airportName: flight.arrivalAirport.name,
          );
      final matchesAirline =
          _selectedAirlineCode == null ||
          flight.airline.code == _selectedAirlineCode;
      final departureDate = flight.departureAtUtc.toLocal();
      final matchesFromDate =
          _departureFromDate == null || !_isBeforeDate(departureDate, _departureFromDate!);
      final matchesToDate =
          _departureToDate == null || !_isAfterDate(departureDate, _departureToDate!);

      return matchesDeparture &&
          matchesArrival &&
          matchesAirline &&
          matchesFromDate &&
          matchesToDate;
    }).toList();
  }

  bool _matchFlightLocation({
    required String query,
    required String cityName,
    required String airportCode,
    required String airportName,
  }) {
    final haystack =
        '${cityName.toLowerCase()} ${airportCode.toLowerCase()} ${airportName.toLowerCase()}';
    return haystack.contains(query);
  }

  bool _isBeforeDate(DateTime candidate, DateTime filterDate) {
    final candidateOnly = DateTime(
      candidate.year,
      candidate.month,
      candidate.day,
    );
    final filterOnly = DateTime(
      filterDate.year,
      filterDate.month,
      filterDate.day,
    );
    return candidateOnly.isBefore(filterOnly);
  }

  bool _isAfterDate(DateTime candidate, DateTime filterDate) {
    final candidateOnly = DateTime(
      candidate.year,
      candidate.month,
      candidate.day,
    );
    final filterOnly = DateTime(
      filterDate.year,
      filterDate.month,
      filterDate.day,
    );
    return candidateOnly.isAfter(filterOnly);
  }

  void _applyFlightFilters() {
    FocusScope.of(context).unfocus();
    setState(() {
      _flights = _filterFlights(_allFlights);
    });
    unawaited(_trackRecommendationSearchSignal());
  }

  void _clearFlightFilters() {
    _departureSearchController.clear();
    _arrivalSearchController.clear();
    setState(() {
      _departureFromDate = null;
      _departureToDate = null;
      _selectedAirlineCode = null;
      _flights = _filterFlights(_allFlights);
    });
  }

  Future<void> _pickFlightDate({required bool isFromDate}) async {
    final initialDate = isFromDate
        ? (_departureFromDate ?? DateTime.now())
        : (_departureToDate ?? _departureFromDate ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );

    if (picked == null) {
      return;
    }

    setState(() {
      if (isFromDate) {
        _departureFromDate = picked;
        if (_departureToDate != null && _departureToDate!.isBefore(picked)) {
          _departureToDate = picked;
        }
      } else {
        _departureToDate = picked;
      }
      _flights = _filterFlights(_allFlights);
    });
  }

  Future<void> _openFlightDetails(MobileFlight flight) async {
    try {
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
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Detalji leta se trenutno ne mogu otvoriti.'),
        ),
      );
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('JetGo Mobile'),
            Text(
              _currentSectionTitle,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Notifikacije',
            onPressed: _openNotifications,
            icon: _NotificationBadgeIcon(
              unreadCount: notificationSummary?.unreadCount ?? 0,
            ),
          ),
          PopupMenuButton<_HomeMenuAction>(
            tooltip: 'Meni',
            onSelected: _handleMenuAction,
            icon: const Icon(Icons.menu_rounded),
            itemBuilder: (context) => [
              PopupMenuItem<_HomeMenuAction>(
                value: _HomeMenuAction.letovi,
                child: _HomeMenuItem(
                  icon: Icons.flight_takeoff_rounded,
                  label: 'Letovi',
                  selected: _currentIndex == 0,
                ),
              ),
              PopupMenuItem<_HomeMenuAction>(
                value: _HomeMenuAction.rezervacije,
                child: _HomeMenuItem(
                  icon: Icons.confirmation_num_outlined,
                  label: 'Rezervacije',
                  selected: _currentIndex == 1,
                ),
              ),
              PopupMenuItem<_HomeMenuAction>(
                value: _HomeMenuAction.novosti,
                child: _HomeMenuItem(
                  icon: Icons.article_outlined,
                  label: 'Novosti',
                  selected: _currentIndex == 2,
                ),
              ),
              PopupMenuItem<_HomeMenuAction>(
                value: _HomeMenuAction.profil,
                child: _HomeMenuItem(
                  icon: Icons.person_outline_rounded,
                  label: 'Moj profil',
                  selected: _currentIndex == 3,
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<_HomeMenuAction>(
                value: _HomeMenuAction.podrska,
                child: _HomeMenuItem(
                  icon: Icons.support_agent_rounded,
                  label: 'Podrska',
                ),
              ),
              const PopupMenuItem<_HomeMenuAction>(
                value: _HomeMenuAction.odjava,
                child: _HomeMenuItem(
                  icon: Icons.logout_rounded,
                  label: 'Odjava',
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadCurrentTab,
          child: _buildBody(context),
        ),
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
    final hasDeparture = _departureSearchController.text.trim().isNotEmpty;
    final hasArrival = _arrivalSearchController.text.trim().isNotEmpty;
    final hasDate = _departureFromDate != null || _departureToDate != null;
    final hasAirline = _selectedAirlineCode != null;

    if (!hasDeparture && !hasArrival && !hasDate && !hasAirline) {
      return 'Pregled svih dostupnih letova za odabrani period.';
    }

    return 'Prikaz letova prema odabranim filterima i kriterijima putovanja.';
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
                  const Spacer(),
                  Text(
                    'Pronadjite svoj let',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontSize: 32,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Pretraga destinacija, preporuke i rezervacije na jednom mjestu.',
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
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Planirajte putovanje',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _LabeledField(
                    label: 'Polaziste',
                    child: TextField(
                      controller: _departureSearchController,
                      textInputAction: TextInputAction.next,
                      onSubmitted: (_) => _applyFlightFilters(),
                      decoration: const InputDecoration(
                        hintText: 'Grad ili aerodrom',
                        suffixIcon: Icon(Icons.location_on_outlined),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _LabeledField(
                    label: 'Odrediste',
                    child: TextField(
                      controller: _arrivalSearchController,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _applyFlightFilters(),
                      decoration: const InputDecoration(
                        hintText: 'Grad ili aerodrom',
                        suffixIcon: Icon(Icons.place_outlined),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _DateFieldButton(
                    label: 'Od',
                    value: _departureFromDate == null
                        ? 'MM.DD.YYYY'
                        : _formatShortDate(_departureFromDate!),
                    onPressed: () => _pickFlightDate(isFromDate: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DateFieldButton(
                    label: 'Do',
                    value: _departureToDate == null
                        ? 'MM.DD.YYYY'
                        : _formatShortDate(_departureToDate!),
                    onPressed: () => _pickFlightDate(isFromDate: false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _LabeledField(
              label: 'Aviokompanija',
              child: DropdownButtonFormField<String>(
                initialValue: _selectedAirlineCode,
                decoration: const InputDecoration(
                  hintText: 'Sve aviokompanije',
                ),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('Sve aviokompanije'),
                  ),
                  ..._availableAirlines.map(
                    (airline) => DropdownMenuItem<String>(
                      value: airline.code,
                      child: Text('${airline.name} (${airline.code})'),
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedAirlineCode = value;
                    _flights = _filterFlights(_allFlights);
                  });
                },
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Prijavljeni ste kao ${_profile?.fullName ?? widget.authController.session?.user.fullName ?? 'korisnik'}',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: _clearFlightFilters,
                  child: const Text('Ocisti'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _applyFlightFilters,
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
        title: 'Trenutno nema prijedloga',
        message:
            'Preporuke se pune nakon pretraga kroz pretragu letova. Ako ste vec rezervisali slicne ili sve trenutno dostupne letove, ovdje privremeno nece biti prijedloga.',
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
            mainAxisExtent: 292,
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

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1.22,
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
                  const Positioned(
                    left: 8,
                    top: 8,
                    child: _FlightOverlayBadge(
                      label: 'Preporuka',
                      icon: Icons.auto_awesome_rounded,
                    ),
                  ),
                  Positioned(
                    right: 8,
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
                  Positioned(
                    left: 10,
                    right: 10,
                    bottom: 10,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${flight.departureAirport.cityName} - ${flight.arrivalAirport.cityName}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${flight.departureAirport.iataCode} -> ${flight.arrivalAirport.iataCode}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
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
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${flight.routeCode}  |  ${MobileDisplay.flightNumberLabel(flight.flightNumber)}',
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  _FlightTimeSummary(
                    departureTime: _formatTimeLabel(flight.departureAtUtc),
                    arrivalTime: _formatTimeLabel(flight.arrivalAtUtc),
                    middleLabel: '${flight.durationMinutes} min',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formatShortDate(flight.departureAtUtc),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    flight.recommendationReason,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
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

    final paidCount = _reservations.where((item) => item.isPaid).length;
    final upcomingCount = _reservations
        .where((item) => item.departureAtUtc.isAfter(DateTime.now()))
        .length;

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
                'Moje rezervacije',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Pregled svih aktivnih i ranijih putovanja, sa placanjem i dodatnim prtljagom na jednom mjestu.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _FlightFactChip(
                    icon: Icons.confirmation_num_outlined,
                    label: '${_reservations.length} rezervacija',
                  ),
                  _FlightFactChip(
                    icon: Icons.verified_rounded,
                    label: '$paidCount placeno',
                  ),
                  _FlightFactChip(
                    icon: Icons.flight_takeoff_rounded,
                    label: '$upcomingCount predstojecih',
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ..._reservations.map(
          (reservation) => _buildReservationCard(context, reservation),
        ),
      ],
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

    final featuredArticle = _news.first;
    final remainingArticles = _news.skip(1).toList();

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
        _buildFeaturedNewsCard(featuredArticle),
        if (remainingArticles.isNotEmpty) ...[
          const SizedBox(height: 18),
          const _SectionHeader(
            title: 'Ostale objave',
            subtitle:
                'Najnovije informacije iz administracije i svijeta putovanja.',
          ),
          const SizedBox(height: 10),
          ...remainingArticles.map(_buildNewsCard),
        ],
      ],
    );
  }

  Widget _buildReservationCard(
    BuildContext context,
    MobileReservation reservation,
  ) {
    final theme = Theme.of(context);

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => _openReservationDetails(reservation),
      child: Card(
        margin: const EdgeInsets.only(bottom: 14),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.75),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          reservation.reservationCode,
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${MobileDisplay.flightNumberLabel(reservation.flightNumber)}  |  ${reservation.routeCode}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _StatusChip(
                    label: MobileDisplay.reservationStatusLabel(
                      reservation.status,
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
                  _FlightTimeSummary(
                    departureTime: _formatTimeLabel(reservation.departureAtUtc),
                    arrivalTime: reservation.arrivalAtUtc != null
                        ? _formatTimeLabel(reservation.arrivalAtUtc!)
                        : '--:--',
                    middleLabel: '${reservation.departureAirportCode} -> ${reservation.arrivalAirportCode}',
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Polazak ${MobileDisplay.formatDateTime(reservation.departureAtUtc)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _FlightFactChip(
                        icon: Icons.sell_outlined,
                        label: MobileDisplay.formatMoney(
                          reservation.totalAmount,
                          reservation.currency,
                        ),
                      ),
                      _FlightFactChip(
                        icon: Icons.event_seat_rounded,
                        label: '${reservation.seatsCount} sjed.',
                      ),
                      _FlightFactChip(
                        icon: reservation.isPaid
                            ? Icons.verified_rounded
                            : Icons.schedule_rounded,
                        label: reservation.isPaid
                            ? 'Placanje evidentirano'
                            : 'Ceka placanje',
                      ),
                    ],
                  ),
                  if (reservation.additionalBaggageCount > 0) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Dodatni prtljag: ${MobileDisplay.baggageOfferLabel(reservation.additionalBaggageCount)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturedNewsCard(NewsArticleSummary article) {
    final imageUrl = article.imageUrl?.trim();
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _openNewsPreview(article),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (hasImage)
                    Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) {
                          return child;
                        }

                        return Container(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
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
                    )
                  else
                    const _NewsImagePlaceholder(
                      icon: Icons.article_rounded,
                      message: 'Objava bez naslovne slike',
                    ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.10),
                          Colors.black.withValues(alpha: 0.62),
                        ],
                      ),
                    ),
                  ),
                  const Positioned(
                    left: 12,
                    top: 12,
                    child: _FlightOverlayBadge(
                      label: 'Istaknuto',
                      icon: Icons.campaign_rounded,
                    ),
                  ),
                  Positioned(
                    left: 14,
                    right: 14,
                    bottom: 14,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          article.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          MobileDisplay.formatDateTime(article.publishedAtUtc),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
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
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Text(
                'Dodirnite istaknutu objavu za pregled detalja i naslovne fotografije.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant,
                    ),
              ),
            ),
          ],
        ),
      ),
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
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 116,
              height: 116,
              child: hasImage
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) {
                          return child;
                        }

                        return Container(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
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
                    )
                  : const _NewsImagePlaceholder(
                      icon: Icons.article_rounded,
                      message: 'Objava bez naslovne slike',
                    ),
            ),
            Expanded(
              child: Padding(
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
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            MobileDisplay.formatDateTime(article.publishedAtUtc),
                            textAlign: TextAlign.end,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
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
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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
                'Moj profil',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Upravljajte licnim podacima, lozinkom, notifikacijama i kontaktom sa podrskom iz jednog mjesta.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _FlightFactChip(
                    icon: Icons.person_outline_rounded,
                    label: profile.roles.map(MobileDisplay.roleLabel).join(', '),
                  ),
                  _FlightFactChip(
                    icon: Icons.notifications_outlined,
                    label:
                        '${_notificationSummary?.unreadCount ?? 0} neprocitanih',
                  ),
                  const _FlightFactChip(
                    icon: Icons.support_agent_rounded,
                    label: 'Podrska dostupna',
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        MobileDisplay.initials(profile.fullName),
                        style: Theme.of(context).textTheme.titleLarge,
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
                          Text(
                            '@${profile.username}',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            profile.email,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: profile.roles
                      .map(
                        (role) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .secondaryContainer,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            MobileDisplay.roleLabel(role),
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ProfileInfoTile(
                        icon: Icons.alternate_email_rounded,
                        label: 'Email',
                        value: profile.email,
                      ),
                      const SizedBox(height: 10),
                      _ProfileInfoTile(
                        icon: Icons.phone_rounded,
                        label: 'Telefon',
                        value: profile.phoneNumber ?? 'Nije uneseno',
                      ),
                      const SizedBox(height: 10),
                      _ProfileInfoTile(
                        icon: Icons.notifications_none_rounded,
                        label: 'Neprocitane notifikacije',
                        value:
                            '${_notificationSummary?.unreadCount ?? 0}',
                      ),
                    ],
                  ),
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
                  'Moj nalog i akcije',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                _InfoRow(label: 'Korisnicko ime', value: '@${profile.username}'),
                _InfoRow(
                  label: 'Uloga',
                  value: profile.roles.map(MobileDisplay.roleLabel).join(', '),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _ProfileActionButton(
                      label: 'Uredi profil',
                      icon: Icons.edit_rounded,
                      onPressed: _openEditProfile,
                    ),
                    _ProfileActionButton(
                      label: 'Promijeni lozinku',
                      icon: Icons.lock_reset_rounded,
                      onPressed: _openChangePassword,
                    ),
                    _ProfileActionButton(
                      label: 'Podrska',
                      icon: Icons.support_agent_rounded,
                      onPressed: _openSupportMessages,
                    ),
                    _ProfileActionButton(
                      label: 'Notifikacije',
                      icon: Icons.notifications_rounded,
                      onPressed: _openNotifications,
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

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openFlightDetails(flight),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
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
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.12),
                          Colors.black.withValues(alpha: 0.55),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 10,
                    top: 10,
                    child: _FlightOverlayBadge(
                      label: MobileDisplay.flightStatusLabel(flight.status),
                      icon: Icons.schedule_rounded,
                    ),
                  ),
                  Positioned(
                    right: 10,
                    top: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.92),
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
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 12,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${flight.departureAirport.cityName} - ${flight.arrivalAirport.cityName}',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${flight.departureAirport.iataCode} -> ${flight.arrivalAirport.iataCode}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
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
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FlightTimeSummary(
                    departureTime: _formatTimeLabel(flight.departureAtUtc),
                    arrivalTime: _formatTimeLabel(flight.arrivalAtUtc),
                    middleLabel: '${flight.durationMinutes} min',
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${flight.routeCode}  |  ${MobileDisplay.flightNumberLabel(flight.flightNumber)}  |  ${flight.airline.name}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Polazak ${_formatShortDate(flight.departureAtUtc)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _FlightFactChip(
                        icon: Icons.airlines_rounded,
                        label: flight.airline.code,
                      ),
                      _FlightFactChip(
                        icon: Icons.event_seat_rounded,
                        label:
                            '${flight.availableSeats}/${flight.totalSeats} slobodno',
                      ),
                      _FlightFactChip(
                        icon: Icons.confirmation_num_outlined,
                        label: MobileDisplay.flightNumberLabel(
                          flight.flightNumber,
                        ),
                      ),
                    ],
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
    if (key.contains('zurich') || key.contains('cirih') || key.contains('zrh')) {
      return 'https://images.unsplash.com/photo-1505764706515-aa95265c5abc?auto=format&fit=crop&w=900&q=80';
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

    return _heroImageUrl;
  }

  String _formatShortDate(DateTime value) {
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    return '$day.$month.${local.year}';
  }

  String _formatTimeLabel(DateTime value) {
    final local = value.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

enum _HomeMenuAction {
  letovi,
  rezervacije,
  novosti,
  profil,
  podrska,
  odjava,
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.child,
  });

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _HomeMenuItem extends StatelessWidget {
  const _HomeMenuItem({
    required this.icon,
    required this.label,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(
          selected ? Icons.check_circle_rounded : icon,
          size: 18,
          color: selected ? theme.colorScheme.primary : null,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? theme.colorScheme.primary : null,
                ),
          ),
        ),
      ],
    );
  }
}

class _ProfileActionButton extends StatelessWidget {
  const _ProfileActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: 156,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          alignment: Alignment.centerLeft,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          side: BorderSide(
            color: theme.colorScheme.outlineVariant,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(
                icon,
                size: 18,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileInfoTile extends StatelessWidget {
  const _ProfileInfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: theme.colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: 18,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: theme.textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FlightOverlayBadge extends StatelessWidget {
  const _FlightOverlayBadge({
    required this.label,
    required this.icon,
  });

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _FlightFactChip extends StatelessWidget {
  const _FlightFactChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _FlightTimeSummary extends StatelessWidget {
  const _FlightTimeSummary({
    required this.departureTime,
    required this.arrivalTime,
    required this.middleLabel,
  });

  final String departureTime;
  final String arrivalTime;
  final String middleLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: _FlightTimePoint(
            label: 'Polazak',
            value: departureTime,
            alignment: CrossAxisAlignment.start,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(
            children: [
              Icon(
                Icons.flight_takeoff_rounded,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 4),
              Text(
                middleLabel,
                style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _FlightTimePoint(
            label: 'Dolazak',
            value: arrivalTime,
            alignment: CrossAxisAlignment.end,
          ),
        ),
      ],
    );
  }
}

class _FlightTimePoint extends StatelessWidget {
  const _FlightTimePoint({
    required this.label,
    required this.value,
    required this.alignment,
  });

  final String label;
  final String value;
  final CrossAxisAlignment alignment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: alignment,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.titleMedium,
        ),
      ],
    );
  }
}

class _DateFieldButton extends StatelessWidget {
  const _DateFieldButton({
    required this.label,
    required this.value,
    required this.onPressed,
  });

  final String label;
  final String value;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return _LabeledField(
      label: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onPressed,
        child: InputDecorator(
          decoration: const InputDecoration(
            suffixIcon: Icon(Icons.calendar_month_outlined),
          ),
          child: Text(value),
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
