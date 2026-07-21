import 'package:flutter/material.dart';

import '../../core/network/api_exception.dart';
import 'mobile_data_service.dart';

class CreateSupportMessageScreen extends StatefulWidget {
  const CreateSupportMessageScreen({
    required this.token,
    this.initialSubject,
    this.initialMessage,
    super.key,
  });

  final String token;
  final String? initialSubject;
  final String? initialMessage;

  @override
  State<CreateSupportMessageScreen> createState() =>
      _CreateSupportMessageScreenState();
}

class _CreateSupportMessageScreenState extends State<CreateSupportMessageScreen> {
  final MobileDataService _dataService = MobileDataService();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _subjectController.text = widget.initialSubject ?? '';
    _messageController.text = widget.initialMessage ?? '';
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate() || _isSubmitting) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final details = await _dataService.createSupportMessage(
        token: widget.token,
        subject: _subjectController.text,
        message: _messageController.text,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(details);
    } on ApiException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Slanje upita trenutno nije dostupno. Pokusajte ponovo.');
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
    return Scaffold(
      appBar: AppBar(title: const Text('Novi upit podrsci')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
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
                      'Kontaktirajte podrsku',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Napisite problem ili pitanje sto konkretnije kako bi administracija mogla brze odgovoriti.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 14),
                    const Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _ComposerTipChip(
                          icon: Icons.confirmation_num_outlined,
                          label: 'Spomenite sifru rezervacije',
                        ),
                        _ComposerTipChip(
                          icon: Icons.payments_outlined,
                          label: 'Navedite payment problem ako postoji',
                        ),
                        _ComposerTipChip(
                          icon: Icons.schedule_rounded,
                          label: 'Dodajte bitan datum ili vrijeme',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _subjectController,
                        maxLength: 200,
                        decoration: const InputDecoration(
                          labelText: 'Naslov',
                          hintText: 'Npr. Problem sa rezervacijom',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Naslov je obavezan.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _messageController,
                        maxLength: 4000,
                        minLines: 6,
                        maxLines: 10,
                        decoration: const InputDecoration(
                          labelText: 'Poruka',
                          hintText: 'Opisite problem ili pitanje sto preciznije.',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Poruka je obavezna.';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _isSubmitting ? null : _submit,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded),
                label: const Text('Posalji upit'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ComposerTipChip extends StatelessWidget {
  const _ComposerTipChip({
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
          Text(
            label,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
