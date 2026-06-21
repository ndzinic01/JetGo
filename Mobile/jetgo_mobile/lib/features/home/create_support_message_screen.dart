import 'package:flutter/material.dart';

import '../../core/network/api_exception.dart';
import 'mobile_data_service.dart';

class CreateSupportMessageScreen extends StatefulWidget {
  const CreateSupportMessageScreen({required this.token, super.key});

  final String token;

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
