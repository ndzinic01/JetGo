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
            'Podaci kontrolne table trenutno nisu dostupni. Pokusajte ponovo.';
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
                'Kontrolna tabla nije dostupna',
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
      return const Center(child: Text('Nema dashboard podataka za prikaz.'));
    }

    return ListView(
      children: [
        _DashboardHeader(
          fullName: widget.currentUserFullName,
          roles: widget.currentUserRoles,
          generatedAtUtc: summary.generatedAtUtc,
          onRefresh: () => _loadSummary(showLoader: false),
        ),
        const SizedBox(height: 16),
        _SnapshotCard(summary: summary),
        const SizedBox(height: 16),
        _AttentionCard(summary: summary),
        const SizedBox(height: 16),
        _RevenueCard(amounts: summary.paidAmountsByCurrency),
      ],
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({
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
    final rolesLabel = roles.isEmpty ? 'Admin' : roles.join(', ');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dobrodosli, $fullName',
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Uloga: $rolesLabel',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
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
                const SizedBox(height: 10),
                Text(
                  'Pregled: ${_Formatters.dateTime(generatedAtUtc)}',
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
        title: 'Aktivni korisnici',
        value: summary.activeUsersCount.toString(),
        detail: 'Ukupno: ${summary.totalUsersCount}',
      ),
      _MetricData(
        icon: Icons.flight_takeoff_rounded,
        title: 'Planirani letovi',
        value: summary.upcomingFlightsCount.toString(),
        detail: 'Kasnjenja: ${summary.delayedFlightsCount}',
      ),
      _MetricData(
        icon: Icons.confirmation_num_rounded,
        title: 'Cekaju potvrdu',
        value: summary.pendingReservationsCount.toString(),
        detail: 'Sve rezervacije: ${summary.totalReservationsCount}',
      ),
      _MetricData(
        icon: Icons.support_agent_rounded,
        title: 'Otvorena podrska',
        value: summary.openSupportMessagesCount.toString(),
        detail: 'Odgovoreno: ${summary.answeredSupportMessagesCount}',
      ),
      _MetricData(
        icon: Icons.payments_rounded,
        title: 'Placena placanja',
        value: summary.paidPaymentsCount.toString(),
        detail: 'Na cekanju: ${summary.pendingPaymentsCount}',
      ),
      _MetricData(
        icon: Icons.undo_rounded,
        title: 'Refundirana',
        value: summary.refundedPaymentsCount.toString(),
        detail: 'Za pregled refund toka',
      ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pregled sistema',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 14,
              runSpacing: 14,
              children: metrics
                  .map(
                    (metric) => SizedBox(
                      width: 220,
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

class _AttentionCard extends StatelessWidget {
  const _AttentionCard({required this.summary});

  final AdminDashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final items = <_FocusItem>[
      if (summary.pendingReservationsCount > 0)
        _FocusItem(
          icon: Icons.schedule_rounded,
          title: 'Rezervacije na cekanju',
          message:
              '${summary.pendingReservationsCount} rezervacija jos ceka admin potvrdu.',
        ),
      if (summary.delayedFlightsCount > 0)
        _FocusItem(
          icon: Icons.warning_amber_rounded,
          title: 'Kasnjenja letova',
          message:
              '${summary.delayedFlightsCount} aktivnih letova trenutno ima status kasnjenja.',
        ),
      if (summary.openSupportMessagesCount > 0)
        _FocusItem(
          icon: Icons.mark_email_unread_rounded,
          title: 'Podrska ceka odgovor',
          message:
              '${summary.openSupportMessagesCount} korisnickih upita jos nije zatvoreno.',
        ),
      if (summary.pendingPaymentsCount > 0)
        _FocusItem(
          icon: Icons.hourglass_top_rounded,
          title: 'Placanja u obradi',
          message:
              'Broj placanja koja su jos na cekanju: ${summary.pendingPaymentsCount}.',
        ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Operativni fokus',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            if (items.isEmpty)
              Text(
                'Trenutno nema otvorenih stavki koje traze hitnu paznju.',
                style: Theme.of(context).textTheme.bodyMedium,
              )
            else
              Column(
                children: items
                    .map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _FocusTile(item: item),
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
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Naplaceni iznosi',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            if (amounts.isEmpty)
              const Text('Jos nema evidentiranih paid uplata za prikaz.')
            else
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: amounts
                    .map(
                      (amount) => Chip(
                        avatar: const Icon(
                          Icons.account_balance_wallet_rounded,
                          size: 16,
                        ),
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

class _MetricData {
  const _MetricData({
    required this.icon,
    required this.title,
    required this.value,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String value;
  final String detail;
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
              Icon(metric.icon, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  metric.title,
                  style: theme.textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            metric.value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            metric.detail,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _FocusItem {
  const _FocusItem({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;
}

class _FocusTile extends StatelessWidget {
  const _FocusTile({required this.item});

  final _FocusItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(item.icon, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  item.message,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Formatters {
  static String dateTime(DateTime value) {
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day.$month.${local.year} $hour:$minute';
  }
}
