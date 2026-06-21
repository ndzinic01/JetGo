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
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
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
                const SizedBox(height: 12),
                Text(
                  'Poslano: ${MobileDisplay.formatDateTime(details.createdAtUtc)}',
                ),
                if (details.repliedAtUtc != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Odgovoreno: ${MobileDisplay.formatDateTime(details.repliedAtUtc!)}',
                  ),
                ],
                const SizedBox(height: 16),
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
                Text(details.customer.fullName),
                const SizedBox(height: 4),
                Text('@${details.customer.username}'),
                const SizedBox(height: 4),
                Text(details.customer.email),
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
                Text(
                  details.adminReply?.trim().isNotEmpty == true
                      ? details.adminReply!
                      : 'Podrska jos nije odgovorila na ovaj upit.',
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
