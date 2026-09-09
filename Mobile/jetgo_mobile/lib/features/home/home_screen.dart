import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/network/api_exception.dart';
import '../auth/auth_controller.dart';
import 'change_password_screen.dart';
import 'edit_profile_screen.dart';
import 'flight_details_screen.dart';
import 'mobile_data_service.dart';
import 'mobile_display.dart';
import 'mobile_models.dart';
import 'mobile_status_values.dart';
import 'notifications_screen.dart';
import 'reservation_details_screen.dart';
import 'support_messages_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    required this.authController,
    this.reservationRefreshSignal,
    super.key,
  });

  final AuthController authController;
  final ValueListenable<int>? reservationRefreshSignal;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _heroImageUrl =
      'https://images.unsplash.com/photo-1436491865332-7a61a109cc05?auto=format&fit=crop&w=1400&q=80';
  static const Duration _notificationPollingInterval = Duration(seconds: 20);
  static const int _flightPageSize = 20;
  static const int _reservationPageSize = 20;
  static const int _newsPageSize = 20;

  final MobileDataService _dataService = MobileDataService();
  final TextEditingController _departureSearchController =
      TextEditingController();
  final TextEditingController _arrivalSearchController =
      TextEditingController();

  Timer? _notificationPollingTimer;
  int _currentIndex = 0;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _isLoadingMoreReturnFlights = false;
  String? _errorMessage;

  PagedResult<MobileFlight>? _flightPage;
  PagedResult<MobileFlight>? _returnFlightPage;
  PagedResult<MobileReservation>? _reservationPage;
  PagedResult<NewsArticleSummary>? _newsPage;
  List<MobileFlight> _flights = const [];
  List<MobileFlight> _returnFlights = const [];
  List<AirlineSummary> _airlineOptions = const [];
  List<MobileRecommendedFlight> _recommendedFlights = const [];
  List<MobileReservation> _reservations = const [];
  List<NewsArticleSummary> _news = const [];
  MobileProfile? _profile;
  MobileNotificationSummary? _notificationSummary;
  String? _recommendationsErrorMessage;
  DateTime? _departureDate;
  DateTime? _returnDate;
  String? _selectedAirlineCode;
  _TripType _tripType = _TripType.oneWay;

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
    widget.reservationRefreshSignal?.addListener(
      _handleReservationRefreshSignal,
    );
    _loadCurrentTab();
    _startNotificationPolling();
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reservationRefreshSignal != widget.reservationRefreshSignal) {
      oldWidget.reservationRefreshSignal?.removeListener(
        _handleReservationRefreshSignal,
      );
      widget.reservationRefreshSignal?.addListener(
        _handleReservationRefreshSignal,
      );
    }
  }

  @override
  void dispose() {
    widget.reservationRefreshSignal?.removeListener(
      _handleReservationRefreshSignal,
    );
    _notificationPollingTimer?.cancel();
    _departureSearchController.dispose();
    _arrivalSearchController.dispose();
    super.dispose();
  }

  void _handleReservationRefreshSignal() {
    if (!mounted || _token.isEmpty) {
      return;
    }

    if (_currentIndex != 1) {
      setState(() {
        _currentIndex = 1;
      });
    }

    unawaited(_loadCurrentTab());
  }

  void _startNotificationPolling() {
    _notificationPollingTimer?.cancel();
    _notificationPollingTimer = Timer.periodic(_notificationPollingInterval, (
      _,
    ) {
      if (!mounted || _token.isEmpty) {
        return;
      }

      unawaited(_loadNotificationSummary(silent: true));
    });
  }

  Future<void> _loadCurrentTab() async {
    if (_token.isEmpty) {
      return;
    }

    setState(() {
      _isLoading = true;
      _isLoadingMore = false;
      _isLoadingMoreReturnFlights = false;
      _errorMessage = null;
    });

    try {
      switch (_currentIndex) {
        case 0:
          final flights = await _fetchFlightsPage(1);
          PagedResult<MobileFlight>? returnFlights;
          if (_shouldLoadReturnFlights) {
            returnFlights = await _fetchReturnFlightsPage(1);
          }

          _flightPage = flights;
          _flights = flights.items;
          _returnFlightPage = returnFlights;
          _returnFlights = returnFlights?.items ?? const [];
          _airlineOptions = _mergeAirlineOptions([
            ...flights.items,
            ..._returnFlights,
          ]);
          unawaited(_loadRecommendations());
          break;
        case 1:
          final reservations = await _dataService.fetchMyReservations(
            token: _token,
            page: 1,
            pageSize: _reservationPageSize,
          );
          _reservationPage = reservations;
          _reservations = reservations.items;
          break;
        case 2:
          final news = await _dataService.fetchNews(
            token: _token,
            page: 1,
            pageSize: _newsPageSize,
          );
          _newsPage = news;
          _news = news.items;
          break;
        case 3:
          _profile = await _dataService.fetchMyProfile(token: _token);
          break;
      }

      unawaited(_loadNotificationSummary(silent: true));
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

  Future<void> _loadRecommendations() async {
    try {
      final recommendations = await _dataService.fetchRecommendedFlights(
        token: _token,
      );

      if (!mounted || _currentIndex != 0) {
        return;
      }

      setState(() {
        _recommendedFlights = recommendations.items;
        _recommendationsErrorMessage = null;
      });
    } catch (_) {
      if (!mounted || _currentIndex != 0) {
        return;
      }

      setState(() {
        _recommendedFlights = const [];
        _recommendationsErrorMessage = 'Preporuke trenutno nisu dostupne.';
      });
    }
  }

  Future<void> _loadNotificationSummary({bool silent = false}) async {
    try {
      final summary = await _dataService.fetchNotificationSummary(
        token: _token,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _notificationSummary = summary;
      });
    } catch (_) {
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notifikacije trenutno nisu dostupne.')),
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

  Future<PagedResult<MobileFlight>> _fetchFlightsPage(int page) {
    return _fetchTripFlightsPage(page, isReturnSegment: false);
  }

  Future<PagedResult<MobileFlight>> _fetchReturnFlightsPage(int page) {
    return _fetchTripFlightsPage(page, isReturnSegment: true);
  }

  Future<PagedResult<MobileFlight>> _fetchTripFlightsPage(
    int page, {
    required bool isReturnSegment,
  }) {
    final tripDate = isReturnSegment ? _returnDate : _departureDate;

    return _dataService.fetchFlights(
      token: _token,
      page: page,
      pageSize: _flightPageSize,
      departureSearchText: isReturnSegment
          ? _arrivalSearchController.text
          : _departureSearchController.text,
      arrivalSearchText: isReturnSegment
          ? _departureSearchController.text
          : _arrivalSearchController.text,
      airlineCode: _selectedAirlineCode,
      departureFromUtc: _startOfDayUtc(tripDate),
      departureToUtc: _endOfDayUtc(tripDate),
    );
  }

  bool get _shouldLoadReturnFlights =>
      _tripType == _TripType.roundTrip && _returnDate != null;

  Future<void> _loadMoreFlights() async {
    final currentPage = _flightPage;
    if (currentPage == null || !currentPage.hasNextPage || _isLoadingMore) {
      return;
    }

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final nextPage = await _fetchFlightsPage(currentPage.page + 1);

      if (!mounted) {
        return;
      }

      setState(() {
        _flightPage = nextPage;
        _flights = [..._flights, ...nextPage.items];
        _airlineOptions = _mergeAirlineOptions(nextPage.items);
      });
    } on ApiException catch (error) {
      _showPagingError(error.message);
    } catch (_) {
      _showPagingError('Naredna stranica letova trenutno nije dostupna.');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _loadMoreReturnFlights() async {
    final currentPage = _returnFlightPage;
    if (currentPage == null ||
        !currentPage.hasNextPage ||
        _isLoadingMoreReturnFlights) {
      return;
    }

    setState(() {
      _isLoadingMoreReturnFlights = true;
    });

    try {
      final nextPage = await _fetchReturnFlightsPage(currentPage.page + 1);

      if (!mounted) {
        return;
      }

      setState(() {
        _returnFlightPage = nextPage;
        _returnFlights = [..._returnFlights, ...nextPage.items];
        _airlineOptions = _mergeAirlineOptions(nextPage.items);
      });
    } on ApiException catch (error) {
      _showPagingError(error.message);
    } catch (_) {
      _showPagingError(
        'Naredna stranica povratnih letova trenutno nije dostupna.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMoreReturnFlights = false;
        });
      }
    }
  }

  Future<void> _loadMoreReservations() async {
    final currentPage = _reservationPage;
    if (currentPage == null || !currentPage.hasNextPage || _isLoadingMore) {
      return;
    }

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final nextPage = await _dataService.fetchMyReservations(
        token: _token,
        page: currentPage.page + 1,
        pageSize: _reservationPageSize,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _reservationPage = nextPage;
        _reservations = [..._reservations, ...nextPage.items];
      });
    } on ApiException catch (error) {
      _showPagingError(error.message);
    } catch (_) {
      _showPagingError('Naredna stranica rezervacija trenutno nije dostupna.');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _loadMoreNews() async {
    final currentPage = _newsPage;
    if (currentPage == null || !currentPage.hasNextPage || _isLoadingMore) {
      return;
    }

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final nextPage = await _dataService.fetchNews(
        token: _token,
        page: currentPage.page + 1,
        pageSize: _newsPageSize,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _newsPage = nextPage;
        _news = [..._news, ...nextPage.items];
      });
    } on ApiException catch (error) {
      _showPagingError(error.message);
    } catch (_) {
      _showPagingError('Naredna stranica novosti trenutno nije dostupna.');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  void _showPagingError(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  List<AirlineSummary> _mergeAirlineOptions(Iterable<MobileFlight> flights) {
    final unique = <String, AirlineSummary>{
      for (final airline in _airlineOptions) airline.code: airline,
    };

    for (final flight in flights) {
      unique.putIfAbsent(flight.airline.code, () => flight.airline);
    }

    final options = unique.values.toList()
      ..sort((left, right) => left.name.compareTo(right.name));
    return options;
  }

  List<AirlineSummary> get _availableAirlines {
    final options = _airlineOptions.toList();
    final selectedCode = _selectedAirlineCode;

    if (selectedCode != null &&
        !options.any((airline) => airline.code == selectedCode)) {
      options.add(
        AirlineSummary(id: 0, name: selectedCode, code: selectedCode),
      );
    }

    options.sort((left, right) => left.name.compareTo(right.name));
    return options;
  }

  DateTime? _startOfDayUtc(DateTime? date) {
    if (date == null) {
      return null;
    }

    return DateTime(date.year, date.month, date.day).toUtc();
  }

  DateTime? _endOfDayUtc(DateTime? date) {
    if (date == null) {
      return null;
    }

    return DateTime(date.year, date.month, date.day, 23, 59, 59, 999).toUtc();
  }

  Future<void> _applyFlightFilters() async {
    FocusScope.of(context).unfocus();
    await _loadCurrentTab();
  }

  void _clearFlightFilters() {
    _departureSearchController.clear();
    _arrivalSearchController.clear();
    setState(() {
      _departureDate = null;
      _returnDate = null;
      _selectedAirlineCode = null;
      _tripType = _TripType.oneWay;
      _returnFlightPage = null;
      _returnFlights = const [];
    });
    unawaited(_loadCurrentTab());
  }

  Future<void> _pickFlightDate({required bool isReturnDate}) async {
    final today = DateTime.now();
    final firstDate = isReturnDate && _departureDate != null
        ? _departureDate!
        : today;
    var initialDate = isReturnDate
        ? (_returnDate ?? _departureDate ?? today)
        : (_departureDate ?? today);

    if (initialDate.isBefore(firstDate)) {
      initialDate = firstDate;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: today.add(const Duration(days: 730)),
    );

    if (picked == null) {
      return;
    }

    setState(() {
      if (isReturnDate) {
        _returnDate = picked;
      } else {
        _departureDate = picked;
        if (_returnDate != null && _returnDate!.isBefore(picked)) {
          _returnDate = picked;
        }
      }
    });
    unawaited(_loadCurrentTab());
  }

  Future<void> _openFlightDetails(MobileFlight flight) async {
    try {
      final changed = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) =>
              FlightDetailsScreen(token: _token, flightId: flight.id),
        ),
      );

      if (changed == true && mounted) {
        setState(() {
          _currentIndex = 1;
        });
        await _loadCurrentTab();

        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rezervacija je uspjesno kreirana.')),
        );
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
    final result = await Navigator.of(context).push<ReservationDetailsResult?>(
      MaterialPageRoute<ReservationDetailsResult?>(
        builder: (_) => ReservationDetailsScreen(
          token: _token,
          reservationId: reservation.id,
        ),
      ),
    );

    if (result != null && mounted) {
      if (result == ReservationDetailsResult.paymentConfirmed &&
          _currentIndex != 1) {
        setState(() {
          _currentIndex = 1;
        });
      }

      await _loadCurrentTab();

      if (!mounted) {
        return;
      }

      if (result == ReservationDetailsResult.paymentConfirmed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Placanje je uspjesno potvrdeno.')),
        );
      }
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
        builder: (_) => EditProfileScreen(token: _token, profile: profile),
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
      const SnackBar(
        content: Text('Lozinka je uspjesno promijenjena. Prijavite se ponovo.'),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (mounted) {
      widget.authController.logout();
    }
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
                Text(article.title, style: theme.textTheme.headlineSmall),
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
        _buildFlightResultsSection(
          title: _tripType == _TripType.roundTrip
              ? 'Odlazni letovi'
              : 'Dostupni letovi',
          subtitle: userFriendlySearchLabel(),
          flights: _flights,
          page: _flightPage,
          emptyMessage: 'Trenutno nema letova za zadane filtere.',
          onLoadMore: _loadMoreFlights,
          isLoadingMore: _isLoadingMore,
          segmentLabel: _tripType == _TripType.roundTrip ? 'Odlazak' : null,
        ),
        if (_tripType == _TripType.roundTrip) ...[
          const SizedBox(height: 20),
          _buildFlightResultsSection(
            title: 'Povratni letovi',
            subtitle: _returnDate == null
                ? 'Odaberite datum povratka.'
                : 'Povratni letovi za odabrani datum.',
            flights: _returnFlights,
            page: _returnFlightPage,
            emptyMessage: _returnDate == null
                ? 'Odaberite datum povratka za prikaz letova.'
                : 'Trenutno nema povratnih letova za zadane filtere.',
            onLoadMore: _loadMoreReturnFlights,
            isLoadingMore: _isLoadingMoreReturnFlights,
            segmentLabel: 'Povratak',
          ),
        ],
      ],
    );
  }

  Widget _buildFlightResultsSection({
    required String title,
    required String subtitle,
    required List<MobileFlight> flights,
    required PagedResult<MobileFlight>? page,
    required String emptyMessage,
    required Future<void> Function() onLoadMore,
    required bool isLoadingMore,
    String? segmentLabel,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: title, subtitle: subtitle),
        const SizedBox(height: 10),
        if (flights.isEmpty)
          _EmptyState(
            icon: Icons.flight_rounded,
            title: 'Nema rezultata',
            message: emptyMessage,
          )
        else ...[
          ...flights.map(
            (flight) => _buildFlightCard(flight, segmentLabel: segmentLabel),
          ),
          _buildLoadMoreButton(
            visible: page?.hasNextPage ?? false,
            onPressed: onLoadMore,
            isLoadingMore: isLoadingMore,
          ),
        ],
      ],
    );
  }

  Widget _buildLoadMoreButton({
    required bool visible,
    required Future<void> Function() onPressed,
    required bool isLoadingMore,
  }) {
    if (!visible) {
      return const SizedBox.shrink();
    }

    final icon = isLoadingMore
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Icon(Icons.expand_more_rounded);

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Center(
        child: OutlinedButton.icon(
          onPressed: isLoadingMore
              ? null
              : () {
                  unawaited(onPressed());
                },
          icon: icon,
          label: Text(isLoadingMore ? 'Ucitavanje...' : 'Ucitaj jos'),
        ),
      ),
    );
  }

  String userFriendlySearchLabel() {
    final hasDeparture = _departureSearchController.text.trim().isNotEmpty;
    final hasArrival = _arrivalSearchController.text.trim().isNotEmpty;
    final hasDate =
        _departureDate != null ||
        (_tripType == _TripType.roundTrip && _returnDate != null);
    final hasAirline = _selectedAirlineCode != null;

    if (!hasDeparture && !hasArrival && !hasDate && !hasAirline) {
      return 'Pregled dostupnih letova.';
    }

    if (_tripType == _TripType.roundTrip) {
      return _returnDate == null
          ? 'Odaberite datum povratka za prikaz povratnih letova.'
          : 'Odlazni i povratni letovi prikazani su odvojeno.';
    }

    return 'Prikaz jednosmjernih letova prema odabranim filterima.';
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
            Text('Planirajte putovanje', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            SegmentedButton<_TripType>(
              segments: const [
                ButtonSegment<_TripType>(
                  value: _TripType.oneWay,
                  icon: Icon(Icons.trending_flat_rounded),
                  label: Text('Jedan smjer'),
                ),
                ButtonSegment<_TripType>(
                  value: _TripType.roundTrip,
                  icon: Icon(Icons.compare_arrows_rounded),
                  label: Text('Povratno'),
                ),
              ],
              selected: {_tripType},
              showSelectedIcon: false,
              onSelectionChanged: (selection) {
                final selectedType = selection.first;
                setState(() {
                  _tripType = selectedType;
                  if (selectedType == _TripType.oneWay) {
                    _returnDate = null;
                    _returnFlightPage = null;
                    _returnFlights = const [];
                  }
                });
                unawaited(_loadCurrentTab());
              },
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
                    label: 'Datum odlaska',
                    value: _departureDate == null
                        ? 'MM.DD.YYYY'
                        : _formatShortDate(_departureDate!),
                    onPressed: () => _pickFlightDate(isReturnDate: false),
                  ),
                ),
                if (_tripType == _TripType.roundTrip) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DateFieldButton(
                      label: 'Datum povratka',
                      value: _returnDate == null
                          ? 'MM.DD.YYYY'
                          : _formatShortDate(_returnDate!),
                      onPressed: () => _pickFlightDate(isReturnDate: true),
                    ),
                  ),
                ],
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
                  });
                  unawaited(_loadCurrentTab());
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
          subtitle:
              'Najzanimljivije opcije na osnovu pretraga i historije rezervacija.',
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
            mainAxisExtent: 296,
          ),
          itemBuilder: (context, index) {
            return _buildRecommendedFlightCard(topRecommendations[index]);
          },
        ),
      ],
    );
  }

  Widget _buildRecommendedFlightCard(MobileRecommendedFlight flight) {
    final imageUrl = _imageUrlOrFallback(flight.destinationImageUrl);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openFlightDetails(
          MobileFlight(
            id: flight.id,
            flightNumber: flight.flightNumber,
            routeCode: flight.routeCode,
            destinationImageUrl: flight.destinationImageUrl,
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
            canReserve: true,
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
                        color: Theme.of(context).colorScheme.secondaryContainer,
                        alignment: Alignment.center,
                        child: const Icon(Icons.flight_rounded, size: 34),
                      );
                    },
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
              padding: const EdgeInsets.fromLTRB(10, 9, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${flight.routeCode}  |  ${MobileDisplay.flightNumberLabel(flight.flightNumber)}',
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 7),
                  _FlightTimeSummary(
                    departureTime: _formatTimeLabel(flight.departureAtUtc),
                    arrivalTime: _formatTimeLabel(flight.arrivalAtUtc),
                    middleLabel: '${flight.durationMinutes} min',
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _formatShortDate(flight.departureAtUtc),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => _showRecommendationReason(flight),
                        icon: const Icon(Icons.info_outline_rounded, size: 15),
                        label: const Text('Zasto?'),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          minimumSize: const Size(0, 32),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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

  Future<void> _showRecommendationReason(MobileRecommendedFlight flight) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        final theme = Theme.of(context);
        final signals = flight.appliedSignals
            .map(_formatRecommendationSignal)
            .where((signal) => signal.isNotEmpty)
            .toList();

        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Zasto je ovaj let preporucen?',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  '${flight.departureAirport.cityName} - ${flight.arrivalAirport.cityName}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.7,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    flight.recommendationReason.isEmpty
                        ? 'Ovaj let je preporucen na osnovu dostupnosti i prethodne aktivnosti u aplikaciji.'
                        : flight.recommendationReason,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(height: 16),
                _InfoRow(
                  label: 'Rezultat preporuke',
                  value: flight.recommendationScore.toString(),
                ),
                _InfoRow(
                  label: 'Let',
                  value:
                      '${MobileDisplay.flightNumberLabel(flight.flightNumber)} | ${flight.routeCode}',
                ),
                _InfoRow(
                  label: 'Polazak',
                  value:
                      '${_formatShortDate(flight.departureAtUtc)} u ${_formatTimeLabel(flight.departureAtUtc)}',
                ),
                if (signals.isNotEmpty) ...[
                  Text('Korisni signali', style: theme.textTheme.labelMedium),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: signals
                        .map(
                          (signal) => Chip(
                            avatar: const Icon(
                              Icons.auto_awesome_rounded,
                              size: 16,
                            ),
                            label: Text(signal),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 16),
                ],
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _openFlightDetails(
                        MobileFlight(
                          id: flight.id,
                          flightNumber: flight.flightNumber,
                          routeCode: flight.routeCode,
                          destinationImageUrl: flight.destinationImageUrl,
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
                          canReserve: true,
                        ),
                      );
                    },
                    icon: const Icon(Icons.flight_takeoff_rounded),
                    label: const Text('Otvori detalje leta'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatRecommendationSignal(String signal) {
    switch (signal) {
      case 'ExactRouteSearch':
        return 'Pretrage iste rute';
      case 'KeywordSearch':
        return 'Pretrage slicnih pojmova';
      case 'ReservationHistory':
        return 'Historija rezervacija';
      case 'Popularity':
        return 'Popularnost leta';
      case 'FallbackUpcomingAvailability':
        return 'Naredna dostupna opcija';
      default:
        return signal.trim();
    }
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
            message:
                'Kada napravite rezervaciju, ovdje cete vidjeti historiju i statuse.',
          ),
        ],
      );
    }

    final paidCount = _reservations.where((item) => item.isPaid).length;
    final upcomingCount = _reservations
        .where(
          (item) =>
              item.departureAtUtc.isAfter(DateTime.now()) &&
              (item.status == MobileReservationStatus.pending ||
                  item.status == MobileReservationStatus.confirmed),
        )
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
        _buildLoadMoreButton(
          visible: _reservationPage?.hasNextPage ?? false,
          onPressed: _loadMoreReservations,
          isLoadingMore: _isLoadingMore,
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
            message:
                'Kada administracija objavi obavijesti, pojavit ce se ovdje.',
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
        _buildLoadMoreButton(
          visible: _newsPage?.hasNextPage ?? false,
          onPressed: _loadMoreNews,
          isLoadingMore: _isLoadingMore,
        ),
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
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.75,
                ),
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
                    middleLabel:
                        '${reservation.departureAirportCode} -> ${reservation.arrivalAirportCode}',
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
                        icon: _reservationPaymentChipIcon(reservation),
                        label: _reservationPaymentChipLabel(reservation),
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
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
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
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
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
                            color: Theme.of(
                              context,
                            ).colorScheme.secondaryContainer,
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
                            MobileDisplay.formatDateTime(
                              article.publishedAtUtc,
                            ),
                            textAlign: TextAlign.end,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
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
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
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
              Text('Moj profil', style: Theme.of(context).textTheme.titleLarge),
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
                    label: profile.roles
                        .map(MobileDisplay.roleLabel)
                        .join(', '),
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
                    _ProfileAvatar(
                      imageUrl: profile.imageUrl,
                      initials: MobileDisplay.initials(profile.fullName),
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
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            profile.email,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
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
                            color: Theme.of(
                              context,
                            ).colorScheme.secondaryContainer,
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
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
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
                        value: '${_notificationSummary?.unreadCount ?? 0}',
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
                _InfoRow(
                  label: 'Korisnicko ime',
                  value: '@${profile.username}',
                ),
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

  Widget _buildFlightCard(MobileFlight flight, {String? segmentLabel}) {
    final imageUrl = _imageUrlOrFallback(flight.destinationImageUrl);

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
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (segmentLabel != null)
                        _FlightFactChip(
                          icon: segmentLabel == 'Povratak'
                              ? Icons.flight_land_rounded
                              : Icons.flight_takeoff_rounded,
                          label: segmentLabel,
                        ),
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

  IconData _reservationPaymentChipIcon(MobileReservation reservation) {
    final status = reservation.paymentStatus;

    if (reservation.isPaid || status == MobilePaymentStatus.paid) {
      return Icons.verified_rounded;
    }

    if (status == MobilePaymentStatus.refunded) {
      return Icons.currency_exchange_rounded;
    }

    if (status == MobilePaymentStatus.failed ||
        reservation.status == MobileReservationStatus.cancelled) {
      return Icons.block_rounded;
    }

    return Icons.schedule_rounded;
  }

  String _reservationPaymentChipLabel(MobileReservation reservation) {
    final status = reservation.paymentStatus;

    if (reservation.isPaid || status == MobilePaymentStatus.paid) {
      return 'Placanje evidentirano';
    }

    if (status == MobilePaymentStatus.refunded) {
      return 'Refundirano';
    }

    if (status == MobilePaymentStatus.failed) {
      return 'Placanje neuspjelo';
    }

    if (reservation.status == MobileReservationStatus.cancelled) {
      return 'Placanje nije aktivno';
    }

    return 'Ceka placanje';
  }

  String _imageUrlOrFallback(String? imageUrl) {
    final value = imageUrl?.trim();
    return value == null || value.isEmpty ? _heroImageUrl : value;
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

enum _HomeMenuAction { letovi, rezervacije, novosti, profil, podrska, odjava }

enum _TripType { oneWay, roundTrip }

class _LabeledField extends StatelessWidget {
  const _LabeledField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
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

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.imageUrl, required this.initials});

  final String? imageUrl;
  final String initials;

  bool get _hasSupportedImageUrl {
    final value = imageUrl?.trim();
    if (value == null || value.isEmpty) {
      return false;
    }

    final uri = Uri.tryParse(value);
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final imageValue = imageUrl?.trim() ?? '';

    return ClipOval(
      child: SizedBox(
        width: 72,
        height: 72,
        child: _hasSupportedImageUrl
            ? Image.network(
                imageValue,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _buildInitials(theme),
              )
            : _buildInitials(theme),
      ),
    );
  }

  Widget _buildInitials(ThemeData theme) {
    return Container(
      color: theme.colorScheme.secondaryContainer,
      alignment: Alignment.center,
      child: Text(initials, style: theme.textTheme.titleLarge),
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
          side: BorderSide(color: theme.colorScheme.outlineVariant),
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
              child: Icon(icon, size: 18, color: theme.colorScheme.primary),
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
            child: Icon(icon, size: 18, color: theme.colorScheme.primary),
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
                Text(value, style: theme.textTheme.bodyLarge),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FlightOverlayBadge extends StatelessWidget {
  const _FlightOverlayBadge({required this.label, required this.icon});

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
  const _FlightFactChip({required this.icon, required this.label});

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
          Icon(icon, size: 15, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(label, style: theme.textTheme.bodySmall),
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
        Text(value, style: theme.textTheme.titleMedium),
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
  const _NewsImagePlaceholder({required this.icon, required this.message});

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
      child: Text(label, style: Theme.of(context).textTheme.labelMedium),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

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
        Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
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
          Text(label, style: Theme.of(context).textTheme.labelMedium),
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
