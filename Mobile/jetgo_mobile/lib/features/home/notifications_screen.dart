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
  final MobileDataService _dataService = MobileDataService();

  bool _isLoading = true;
  bool _isSubmitting = false;
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

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Centar notifikacija',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Ovdje pratite potvrde rezervacija, promjene statusa i payment obavijesti.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _SummaryBlock(
                      icon: Icons.mark_email_unread_rounded,
                      label: 'Neprocitane',
                      value: summary.unreadCount.toString(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SummaryBlock(
                      icon: Icons.notifications_active_rounded,
                      label: 'Ukupno',
                      value: summary.totalCount.toString(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _LatestNotificationRow(
                value: summary.latestCreatedAtUtc == null
                    ? '-'
                    : MobileDisplay.formatDateTime(summary.latestCreatedAtUtc!),
              ),
              if (summary.unreadCount > 0) ...[
                const SizedBox(height: 14),
                FilledButton.tonalIcon(
                  onPressed: _isSubmitting ? null : _markAllAsRead,
                  icon: const Icon(Icons.done_all_rounded),
                  label: const Text('Oznaci sve kao procitano'),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_notifications.isEmpty)
          const _NotificationsEmptyState(
            icon: Icons.notifications_none_rounded,
            title: 'Nemate notifikacija',
            message: 'Kad backend zabiljezi nove dogadjaje, pojavit ce se ovdje.',
          )
        else
          ..._notifications.map(_buildNotificationCard),
      ],
    );
  }

  Widget _buildNotificationCard(MobileNotification notification) {
    final theme = Theme.of(context);
    final isUnread = notification.isUnread;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isUnread ? 1 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isUnread
              ? theme.colorScheme.primary.withValues(alpha: 0.28)
              : theme.colorScheme.outlineVariant,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: isUnread
                        ? theme.colorScheme.secondaryContainer
                        : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isUnread
                        ? Icons.notifications_active_rounded
                        : Icons.notifications_none_rounded,
                    color: theme.colorScheme.primary,
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
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: isUnread
                              ? theme.colorScheme.secondaryContainer
                              : theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          MobileDisplay.notificationStatusLabel(
                            notification.status,
                          ),
                          style: theme.textTheme.labelMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              notification.body,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 14),
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
                    icon: const Icon(Icons.done_rounded),
                    label: const Text('Procitano'),
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
}

class _LatestNotificationRow extends StatelessWidget {
  const _LatestNotificationRow({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            Icons.history_rounded,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Zadnja aktivnost: $value',
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryBlock extends StatelessWidget {
  const _SummaryBlock({
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(height: 10),
        Text(label, style: theme.textTheme.labelMedium),
        const SizedBox(height: 6),
        Text(value, style: theme.textTheme.titleMedium),
      ],
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
