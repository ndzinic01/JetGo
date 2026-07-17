import 'package:flutter/material.dart';

import '../../core/network/api_exception.dart';
import 'mobile_data_service.dart';
import 'mobile_display.dart';
import 'mobile_models.dart';

class SupportMessageDetailsScreen extends StatefulWidget {
  const SupportMessageDetailsScreen({
    required this.token,
    required this.supportMessageId,
    this.initialDetails,
    super.key,
  });

  final String token;
  final int supportMessageId;
  final MobileSupportMessageDetails? initialDetails;

  @override
  State<SupportMessageDetailsScreen> createState() =>
      _SupportMessageDetailsScreenState();
}

class _SupportMessageDetailsScreenState extends State<SupportMessageDetailsScreen> {
  final MobileDataService _dataService = MobileDataService();

  bool _isLoading = true;
  String? _errorMessage;
  MobileSupportMessageDetails? _details;

  @override
  void initState() {
    super.initState();
    _details = widget.initialDetails;
    _isLoading = widget.initialDetails == null;
    _load();
  }

  Future<void> _load() async {
    if (_details == null) {
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
      final details = await _dataService.fetchSupportMessageDetails(
        token: widget.token,
        supportMessageId: widget.supportMessageId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _details = details;
      });
    } on ApiException catch (error) {
      _errorMessage = error.message;
    } catch (_) {
      _errorMessage = 'Detalji upita trenutno nisu dostupni.';
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
    final details = _details;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalji upita'),
        actions: [
          IconButton(
            tooltip: 'Osvjezi',
            onPressed: _isLoading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(context, details),
      ),
    );
  }

  Widget _buildBody(BuildContext context, MobileSupportMessageDetails? details) {
    if (_isLoading && details == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null && details == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          _SupportEmptyState(
            icon: Icons.support_agent_rounded,
            title: 'Detalji nisu dostupni',
            message: _errorMessage!,
          ),
        ],
      );
    }

    if (details == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: const [
          _SupportEmptyState(
            icon: Icons.support_agent_rounded,
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
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      details.subject,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  _ReplyChip(isReplied: details.isReplied),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Pregled kompletnog toka komunikacije sa podrskom za ovaj upit.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _SupportMetaChip(
                    icon: Icons.schedule_send_rounded,
                    label:
                        'Poslano ${MobileDisplay.formatDateTime(details.createdAtUtc)}',
                  ),
                  if (details.repliedAtUtc != null)
                    _SupportMetaChip(
                      icon: Icons.mark_email_read_rounded,
                      label:
                          'Odgovor ${MobileDisplay.formatDateTime(details.repliedAtUtc!)}',
                    ),
                ],
              ),
            ],
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
                  'Vasa poruka',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Text(
                  details.message,
                  style: Theme.of(context).textTheme.bodyLarge,
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
                  'Posiljalac',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                _DetailInfoRow(label: 'Ime i prezime', value: details.customer.fullName),
                _DetailInfoRow(label: 'Korisnicko ime', value: '@${details.customer.username}'),
                _DetailInfoRow(label: 'Email', value: details.customer.email),
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
                  'Odgovor podrske',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    details.adminReply?.trim().isNotEmpty == true
                        ? details.adminReply!
                        : 'Podrska jos nije odgovorila na ovaj upit.',
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ReplyChip extends StatelessWidget {
  const _ReplyChip({required this.isReplied});

  final bool isReplied;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isReplied
            ? Theme.of(context).colorScheme.secondaryContainer
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isReplied ? 'Odgovoreno' : 'Na cekanju',
        style: Theme.of(context).textTheme.labelMedium,
      ),
    );
  }
}

class _SupportMetaChip extends StatelessWidget {
  const _SupportMetaChip({
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _DetailInfoRow extends StatelessWidget {
  const _DetailInfoRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _SupportEmptyState extends StatelessWidget {
  const _SupportEmptyState({
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
