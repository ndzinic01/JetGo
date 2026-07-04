import 'package:flutter/material.dart';

import '../../core/network/api_exception.dart';
import 'overview_models.dart';
import 'overview_service.dart';

class OverviewSection extends StatefulWidget {
  const OverviewSection({
    required this.token,
    required this.currentUserFullName,
    required this.currentUserRoles,
    super.key,
  });

  final String token;
  final String currentUserFullName;
  final List<String> currentUserRoles;

  @override
  State<OverviewSection> createState() => _OverviewSectionState();
}

class _OverviewSectionState extends State<OverviewSection> {
  final OverviewService _service = OverviewService();

  bool _isLoading = true;
  String? _errorMessage;
  AdminDashboardSummary? _summary;

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  Future<void> _loadSummary({bool showLoader = true}) async {
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
      final summary = await _service.fetchSummary(token: widget.token);

      if (!mounted) {
        return;
      }

      setState(() {
        _summary = summary;
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage =
            'Overview podaci trenutno nisu dostupni. Pokusajte ponovo.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 40),
              const SizedBox(height: 12),
              Text(
                'Overview nije dostupan',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _loadSummary,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Pokusaj ponovo'),
              ),
            ],
          ),
        ),
      );
    }

    final summary = _summary;
    if (summary == null) {
      return const Center(child: Text('Nema overview podataka za prikaz.'));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final activityCards = [
          _ActivityCard(
            title: 'Zadnje rezervacije',
            subtitle: 'Najnovije kreirane rezervacije u sistemu.',
            child: _RecentReservationsList(items: summary.recentReservations),
          ),
          _ActivityCard(
            title: 'Zadnja placanja',
            subtitle: 'Najnoviji payment zapisi i trenutni statusi.',
            child: _RecentPaymentsList(items: summary.recentPayments),
          ),
          _ActivityCard(
            title: 'Support queue',
            subtitle: 'Najnoviji korisnicki upiti i odgovor admina.',
            child: _RecentSupportList(items: summary.recentSupportMessages),
          ),
        ];

        return ListView(
          children: [
            _WelcomeBand(
              fullName: widget.currentUserFullName,
              roles: widget.currentUserRoles,
              generatedAtUtc: summary.generatedAtUtc,
              onRefresh: () => _loadSummary(showLoader: false),
            ),
            const SizedBox(height: 16),
            _SnapshotCard(summary: summary),
            const SizedBox(height: 16),
            _RevenueCard(amounts: summary.paidAmountsByCurrency),
            const SizedBox(height: 16),
            if (constraints.maxWidth >= 1320)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: activityCards[0]),
                  const SizedBox(width: 16),
                  Expanded(child: activityCards[1]),
                  const SizedBox(width: 16),
                  Expanded(child: activityCards[2]),
                ],
              )
            else ...[
              activityCards[0],
              const SizedBox(height: 16),
              activityCards[1],
              const SizedBox(height: 16),
              activityCards[2],
            ],
          ],
        );
      },
    );
  }
}

class _WelcomeBand extends StatelessWidget {
  const _WelcomeBand({
    required this.fullName,
    required this.roles,
    required this.generatedAtUtc,
    required this.onRefresh,
  });

  final String fullName;
  final List<String> roles;
  final DateTime generatedAtUtc;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dobrodosli nazad, $fullName',
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ovdje imate brzi operativni pregled korisnika, letova, rezervacija, support-a i payment toka.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: roles
                        .map(
                          (role) => Chip(
                            avatar: const Icon(Icons.verified_user_rounded, size: 16),
                            label: Text(role),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FilledButton.tonalIcon(
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Osvjezi'),
                ),
                const SizedBox(height: 12),
                Text(
                  'Snapshot: ${_Formatters.dateTime(generatedAtUtc)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SnapshotCard extends StatelessWidget {
  const _SnapshotCard({required this.summary});

  final AdminDashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      _MetricData(
        icon: Icons.group_rounded,
        title: 'Korisnici',
        value: summary.totalUsersCount.toString(),
        lineOne: 'Aktivni: ${summary.activeUsersCount}',
        lineTwo: 'Neaktivni: ${summary.inactiveUsersCount}',
      ),
      _MetricData(
        icon: Icons.flight_takeoff_rounded,
        title: 'Letovi',
        value: summary.upcomingFlightsCount.toString(),
        lineOne: 'Upcoming / active',
        lineTwo: 'Delayed: ${summary.delayedFlightsCount}',
      ),
      _MetricData(
        icon: Icons.confirmation_num_rounded,
        title: 'Rezervacije',
        value: summary.totalReservationsCount.toString(),
        lineOne: 'Pending: ${summary.pendingReservationsCount}',
        lineTwo:
            'Obradjeno: ${summary.totalReservationsCount - summary.pendingReservationsCount}',
      ),
      _MetricData(
        icon: Icons.support_agent_rounded,
        title: 'Support',
        value: summary.openSupportMessagesCount.toString(),
        lineOne: 'Otvorene poruke',
        lineTwo: 'Odgovorene: ${summary.answeredSupportMessagesCount}',
      ),
      _MetricData(
        icon: Icons.payments_rounded,
        title: 'Placanja',
        value: summary.paidPaymentsCount.toString(),
        lineOne: 'Paid placanja',
        lineTwo:
            'Pending: ${summary.pendingPaymentsCount}  Refunded: ${summary.refundedPaymentsCount}',
      ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Operational snapshot',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Najbitniji brojevi iz sistema na jednom mjestu, bez otvaranja svakog modula posebno.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 14,
              runSpacing: 14,
              children: metrics
                  .map(
                    (metric) => SizedBox(
                      width: 240,
                      child: _MetricTile(metric: metric),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _RevenueCard extends StatelessWidget {
  const _RevenueCard({required this.amounts});

  final List<AdminDashboardAmount> amounts;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Collected paid amounts',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Zbir uspjesno naplacenih paymenta grupisan po valuti. Dobro dođe i za demo i za seminarski dio.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),
            if (amounts.isEmpty)
              const Text('Jos nema paid placanja za prikaz iznosa.')
            else
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: amounts
                    .map(
                      (amount) => Chip(
                        avatar: const Icon(Icons.account_balance_wallet_rounded, size: 16),
                        label: Text(
                          '${amount.amount.toStringAsFixed(2)} ${amount.currency}',
                        ),
                      ),
                    )
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _MetricData {
  const _MetricData({
    required this.icon,
    required this.title,
    required this.value,
    required this.lineOne,
    required this.lineTwo,
  });

  final IconData icon;
  final String title;
  final String value;
  final String lineOne;
  final String lineTwo;
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.metric});

  final _MetricData metric;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(metric.icon, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  metric.title,
                  style: theme.textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            metric.value,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(metric.lineOne),
          const SizedBox(height: 2),
          Text(
            metric.lineTwo,
            style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

class _RecentReservationsList extends StatelessWidget {
  const _RecentReservationsList({required this.items});

  final List<AdminDashboardRecentReservation> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _EmptyActivityMessage(
        message: 'Jos nema rezervacija u sistemu.',
      );
    }

    return Column(
      children: items
          .map(
            (item) => _ActivityRow(
              title: item.reservationCode,
              subtitle:
                  '${_Formatters.safeText(item.customerName)} • ${item.flightNumber} • ${item.routeCode}',
              meta:
                  '${_Formatters.reservationStatus(item.status)} • ${item.totalAmount.toStringAsFixed(2)} ${item.currency} • ${_Formatters.dateTime(item.createdAtUtc)}',
            ),
          )
          .toList(),
    );
  }
}

class _RecentPaymentsList extends StatelessWidget {
  const _RecentPaymentsList({required this.items});

  final List<AdminDashboardRecentPayment> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _EmptyActivityMessage(
        message: 'Jos nema payment zapisa u sistemu.',
      );
    }

    return Column(
      children: items
          .map(
            (item) => _ActivityRow(
              title: item.reservationCode,
              subtitle:
                  '${_Formatters.safeText(item.customerName)} • ${item.flightNumber} • ${item.routeCode}',
              meta:
                  '${_Formatters.paymentStatus(item.status)} • ${item.amount.toStringAsFixed(2)} ${item.currency} • ${_Formatters.dateTime(item.createdAtUtc)}',
            ),
          )
          .toList(),
    );
  }
}

class _RecentSupportList extends StatelessWidget {
  const _RecentSupportList({required this.items});

  final List<AdminDashboardRecentSupportMessage> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _EmptyActivityMessage(
        message: 'Jos nema support poruka u inboxu.',
      );
    }

    return Column(
      children: items
          .map(
            (item) => _ActivityRow(
              title: item.subject,
              subtitle:
                  '${_Formatters.safeText(item.customerName)} • ${_Formatters.safeText(item.customerEmail)}',
              meta:
                  '${item.isReplied ? 'Odgovoreno' : 'Ceka odgovor'} • ${_Formatters.dateTime(item.createdAtUtc)}',
            ),
          )
          .toList(),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({
    required this.title,
    required this.subtitle,
    required this.meta,
  });

  final String title;
  final String subtitle;
  final String meta;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            meta,
            style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

class _EmptyActivityMessage extends StatelessWidget {
  const _EmptyActivityMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(child: Text(message)),
    );
  }
}

class _Formatters {
  static String reservationStatus(int value) {
    switch (value) {
      case 2:
        return 'Confirmed';
      case 3:
        return 'Cancelled';
      case 4:
        return 'Completed';
      default:
        return 'Pending';
    }
  }

  static String paymentStatus(int value) {
    switch (value) {
      case 2:
        return 'Paid';
      case 3:
        return 'Failed';
      case 4:
        return 'Refunded';
      default:
        return 'Pending';
    }
  }

  static String safeText(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? '-' : trimmed;
  }

  static String dateTime(DateTime value) {
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day.$month.${local.year} $hour:$minute';
  }
}
