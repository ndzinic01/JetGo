import 'package:flutter/material.dart';

import '../../core/network/api_exception.dart';
import 'create_support_message_screen.dart';
import 'mobile_data_service.dart';
import 'mobile_display.dart';
import 'mobile_models.dart';
import 'support_message_details_screen.dart';

class SupportMessagesScreen extends StatefulWidget {
  const SupportMessagesScreen({required this.token, super.key});

  final String token;

  @override
  State<SupportMessagesScreen> createState() => _SupportMessagesScreenState();
}

class _SupportMessagesScreenState extends State<SupportMessagesScreen> {
  final MobileDataService _dataService = MobileDataService();

  bool _isLoading = true;
  String? _errorMessage;
  List<MobileSupportMessageSummary> _messages = const [];

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
      final response = await _dataService.fetchSupportMessages(
        token: widget.token,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _messages = response.items;
      });
    } on ApiException catch (error) {
      _errorMessage = error.message;
    } catch (_) {
      _errorMessage = 'Podrska trenutno nije dostupna. Pokusajte ponovo.';
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _openComposer() async {
    final created = await Navigator.of(context).push<MobileSupportMessageDetails>(
      MaterialPageRoute<MobileSupportMessageDetails>(
        builder: (_) => CreateSupportMessageScreen(token: widget.token),
      ),
    );

    if (!mounted || created == null) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Upit je uspjesno poslan podrsci.')),
    );

    await _load();

    if (!mounted) {
      return;
    }

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => SupportMessageDetailsScreen(
          token: widget.token,
          supportMessageId: created.id,
          initialDetails: created,
        ),
      ),
    );
  }

  Future<void> _openDetails(MobileSupportMessageSummary item) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => SupportMessageDetailsScreen(
          token: widget.token,
          supportMessageId: item.id,
        ),
      ),
    );
    if (mounted) {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Podrska'),
        actions: [
          IconButton(
            tooltip: 'Osvjezi',
            onPressed: _isLoading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openComposer,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Novi upit'),
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
          _SupportListEmptyState(
            icon: Icons.support_agent_rounded,
            title: 'Podrska nije dostupna',
            message: _errorMessage!,
          ),
        ],
      );
    }

    if (_messages.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: const [
          _SupportListEmptyState(
            icon: Icons.mark_email_unread_outlined,
            title: 'Nemate poslanih upita',
            message: 'Kada posaljete poruku podrsci, ovdje cete vidjeti tok komunikacije.',
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final item = _messages[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            onTap: () => _openDetails(item),
            title: Text(item.subject),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.messagePreview,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Poslano: ${MobileDisplay.formatDateTime(item.createdAtUtc)}',
                  ),
                  if (item.repliedAtUtc != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Odgovoreno: ${MobileDisplay.formatDateTime(item.repliedAtUtc!)}',
                    ),
                  ],
                ],
              ),
            ),
            trailing: _ReplyBadge(isReplied: item.isReplied),
          ),
        );
      },
    );
  }
}

class _ReplyBadge extends StatelessWidget {
  const _ReplyBadge({required this.isReplied});

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
        isReplied ? 'Odgovor' : 'Ceka',
        style: Theme.of(context).textTheme.labelMedium,
      ),
    );
  }
}

class _SupportListEmptyState extends StatelessWidget {
  const _SupportListEmptyState({
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
