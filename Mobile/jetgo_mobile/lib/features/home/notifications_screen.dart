import 'package:flutter/material.dart';

import '../../core/network/api_exception.dart';
import 'mobile_data_service.dart';
import 'mobile_display.dart';
import 'mobile_models.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({required this.token, super.key});

  final String token;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  static const _heroImageUrl =
      'https://images.unsplash.com/photo-1436491865332-7a61a109cc05?auto=format&fit=crop&w=1400&q=80';

  final MobileDataService _dataService = MobileDataService();

  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _showUnreadOnly = false;
  String _typeFilter = 'Sve';
  String? _errorMessage;
  MobileNotificationSummary? _summary;
  List<MobileNotification> _notifications = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final summary = await _dataService.fetchNotificationSummary(
        token: widget.token,
      );
      final notifications = await _dataService.fetchNotifications(
        token: widget.token,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _summary = summary;
        _notifications = notifications.items;
      });
    } on ApiException catch (error) {
      _errorMessage = error.message;
    } catch (_) {
      _errorMessage = 'Notifikacije trenutno nisu dostupne. Pokusajte ponovo.';
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _markAsRead(MobileNotification notification) async {
    if (!notification.isUnread || _isSubmitting) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await _dataService.markNotificationAsRead(
        token: widget.token,
        notificationId: notification.id,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notifikacija je oznacena kao procitana.')),
      );
      await _load();
    } on ApiException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Oznacavanje nije uspjelo. Pokusajte ponovo.');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _markAllAsRead() async {
    final summary = _summary;
    if (summary == null || summary.unreadCount == 0 || _isSubmitting) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await _dataService.markAllNotificationsAsRead(token: widget.token);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sve notifikacije su oznacene kao procitane.')),
      );
      await _load();
    } on ApiException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Akcija trenutno nije dostupna. Pokusajte ponovo.');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifikacije'),
        actions: [
          IconButton(
            tooltip: 'Osvjezi',
            onPressed: _isLoading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: 'Oznaci sve kao procitano',
            onPressed: summary == null || summary.unreadCount == 0 || _isSubmitting
                ? null
                : _markAllAsRead,
            icon: const Icon(Icons.done_all_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(context),
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
          _NotificationsEmptyState(
            icon: Icons.notifications_off_rounded,
            title: 'Notifikacije nisu dostupne',
            message: _errorMessage!,
          ),
        ],
      );
    }

    final summary = _summary;
    if (summary == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: const [
          _NotificationsEmptyState(
            icon: Icons.notifications_none_rounded,
            title: 'Nema podataka',
            message: 'Pokusajte ponovo nakon osvjezavanja.',
          ),
        ],
      );
    }

    final visibleNotifications = _notifications.where((notification) {
      if (_showUnreadOnly && !notification.isUnread) {
        return false;
      }

      switch (_typeFilter) {
        case 'Neprocitane':
          return notification.isUnread;
        case 'Procitane':
          return !notification.isUnread;
        default:
          return true;
      }
    }).toList();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _NotificationsHero(summary: summary),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _typeFilter,
                        decoration: const InputDecoration(
                          labelText: 'Vrsta prikaza',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'Sve',
                            child: Text('Sve'),
                          ),
                          DropdownMenuItem(
                            value: 'Neprocitane',
                            child: Text('Neprocitane'),
                          ),
                          DropdownMenuItem(
                            value: 'Procitane',
                            child: Text('Procitane'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }

                          setState(() {
                            _typeFilter = value;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Checkbox(
                      value: _showUnreadOnly,
                      onChanged: (value) {
                        setState(() {
                          _showUnreadOnly = value ?? false;
                        });
                      },
                    ),
                    const Expanded(
                      child: Text('Samo neprocitane'),
                    ),
                    if (summary.unreadCount > 0)
                      TextButton.icon(
                        onPressed: _isSubmitting ? null : _markAllAsRead,
                        icon: const Icon(Icons.done_all_rounded),
                        label: const Text('Procitaj sve'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (visibleNotifications.isEmpty)
          const _NotificationsEmptyState(
            icon: Icons.notifications_none_rounded,
            title: 'Nemate notifikacija',
            message: 'Kad backend zabiljezi nove dogadjaje, pojavit ce se ovdje.',
          )
        else
          ...visibleNotifications.map(_buildNotificationCard),
      ],
    );
  }

  Widget _buildNotificationCard(MobileNotification notification) {
    final theme = Theme.of(context);
    final isUnread = notification.isUnread;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(
          color: isUnread
              ? theme.colorScheme.primary.withValues(alpha: 0.34)
              : theme.colorScheme.outlineVariant,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _iconBackground(theme, notification),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Icon(
                    _notificationIcon(notification),
                    color: _iconColor(notification),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notification.title,
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        MobileDisplay.notificationStatusLabel(
                          notification.status,
                        ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isUnread)
                  Container(
                    width: 12,
                    height: 12,
                    margin: const EdgeInsets.only(top: 6),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              notification.body,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.schedule_rounded,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    MobileDisplay.formatDateTime(notification.createdAtUtc),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                if (isUnread)
                  TextButton.icon(
                    onPressed:
                        _isSubmitting ? null : () => _markAsRead(notification),
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: const Text('Procitaj'),
                  )
                else
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 18,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _notificationIcon(MobileNotification notification) {
    final text = '${notification.title} ${notification.body}'.toLowerCase();
    if (text.contains('otkazan')) {
      return Icons.close_rounded;
    }
    if (text.contains('odgod')) {
      return Icons.warning_amber_rounded;
    }
    if (text.contains('vrijeme')) {
      return Icons.access_time_filled_rounded;
    }
    if (text.contains('podrsk') || text.contains('poruka')) {
      return Icons.chat_bubble_outline_rounded;
    }
    return Icons.notifications_active_rounded;
  }

  Color _iconColor(MobileNotification notification) {
    final text = '${notification.title} ${notification.body}'.toLowerCase();
    if (text.contains('otkazan')) {
      return const Color(0xFFE84C3D);
    }
    if (text.contains('odgod')) {
      return const Color(0xFFF1C40F);
    }
    if (text.contains('vrijeme')) {
      return const Color(0xFF4A90E2);
    }
    return const Color(0xFF4A90E2);
  }

  Color _iconBackground(ThemeData theme, MobileNotification notification) {
    return _iconColor(notification).withValues(alpha: 0.14);
  }
}

class _NotificationsHero extends StatelessWidget {
  const _NotificationsHero({required this.summary});

  final MobileNotificationSummary summary;

  @override
  Widget build(BuildContext context) {
    final latest = summary.latestCreatedAtUtc == null
        ? '-'
        : MobileDisplay.formatDateTime(summary.latestCreatedAtUtc!);

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 230,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              _NotificationsScreenState._heroImageUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.14),
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
                    Colors.black.withValues(alpha: 0.36),
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
                    'Notifikacije',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ukupno: ${summary.totalCount}  |  Neprocitane: ${summary.unreadCount}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Zadnja aktivnost: $latest',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.92),
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
}

class _NotificationsEmptyState extends StatelessWidget {
  const _NotificationsEmptyState({
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
