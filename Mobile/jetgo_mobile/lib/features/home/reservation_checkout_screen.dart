import 'package:flutter/material.dart';

import '../../core/network/api_exception.dart';
import 'mobile_data_service.dart';
import 'mobile_display.dart';
import 'mobile_models.dart';
import 'mobile_status_values.dart';
import 'reservation_details_screen.dart';

class ReservationCheckoutScreen extends StatefulWidget {
  const ReservationCheckoutScreen({
    required this.token,
    required this.details,
    required this.selectedSeats,
    required this.additionalBaggageCount,
    super.key,
  });

  final String token;
  final MobileFlightDetails details;
  final List<String> selectedSeats;
  final int additionalBaggageCount;

  @override
  State<ReservationCheckoutScreen> createState() =>
      _ReservationCheckoutScreenState();
}

class _ReservationCheckoutScreenState extends State<ReservationCheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final MobileDataService _dataService = MobileDataService();
  late final List<_PassengerFormData> _passengerForms;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final seats = widget.selectedSeats.toList()..sort();
    _passengerForms = seats
        .map((seat) => _PassengerFormData(seatNumber: seat))
        .toList();
  }

  @override
  void dispose() {
    for (final passenger in _passengerForms) {
      passenger.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final reservation = await _dataService.createReservation(
        token: widget.token,
        flightId: widget.details.id,
        seatNumbers: _passengerForms.map((item) => item.seatNumber).toList(),
        additionalBaggageCount: widget.additionalBaggageCount,
        passengers: _passengerForms
            .map(
              (item) => MobileReservationPassengerInput(
                seatNumber: item.seatNumber,
                firstName: item.firstNameController.text.trim(),
                lastName: item.lastNameController.text.trim(),
                gender: item.gender ?? PassengerGender.other,
                passportNumber: item.passportController.text.trim(),
              ),
            )
            .toList(),
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rezervacija je uspjesno kreirana.')),
      );

      final shouldRefresh = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => ReservationDetailsScreen(
            token: widget.token,
            reservationId: reservation.id,
            markDirtyOnPop: true,
          ),
        ),
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(shouldRefresh ?? true);
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rezervaciju trenutno nije moguce kreirati.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  double _seatsTotal() => widget.details.basePrice * _passengerForms.length;

  double _baggageTotal() =>
      widget.details.additionalBaggageUnitPrice * widget.additionalBaggageCount;

  double _reservationTotal() => _seatsTotal() + _baggageTotal();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dovrsite rezervaciju')),
      body: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _buildSummaryCard(context),
            const SizedBox(height: 12),
            ..._passengerForms.asMap().entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _PassengerFormCard(
                  passengerNumber: entry.key + 1,
                  data: entry.value,
                ),
              ),
            ),
            _buildPaymentInfoCard(context),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: FilledButton.icon(
          onPressed: _isSubmitting ? null : _submit,
          icon: _isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check_circle_rounded),
          label: Text(_isSubmitting ? 'Kreiranje...' : 'Dovrsi rezervaciju'),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context) {
    final details = widget.details;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${details.departureAirport.cityName} -> ${details.arrivalAirport.cityName}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const Icon(Icons.verified_rounded, color: Color(0xFF42B66D)),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Broj leta: ${MobileDisplay.flightNumberLabel(details.flightNumber)}',
            ),
            Text(
              'Sjedista: ${_passengerForms.map((item) => item.seatNumber).join(', ')}',
            ),
            Text(
              'Prtljag: ${MobileDisplay.baggageOfferLabel(widget.additionalBaggageCount)}',
            ),
            const Divider(height: 24),
            Text(
              'Sjedista: ${MobileDisplay.formatMoney(_seatsTotal(), details.currency)}',
            ),
            Text(
              'Dodatni prtljag: ${MobileDisplay.formatMoney(_baggageTotal(), details.currency)}',
            ),
            const SizedBox(height: 8),
            Text(
              'Ukupna cijena: ${MobileDisplay.formatMoney(_reservationTotal(), details.currency)}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentInfoCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Placanje', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.payments_outlined),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Nakon kreiranja rezervacije otvorit ce se detalji rezervacije gdje pokrecete PayPal sandbox placanje.',
                    style: Theme.of(context).textTheme.bodyMedium,
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

class _PassengerFormCard extends StatelessWidget {
  const _PassengerFormCard({required this.passengerNumber, required this.data});

  final int passengerNumber;
  final _PassengerFormData data;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Putnik $passengerNumber - sjediste ${data.seatNumber}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: data.firstNameController,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Ime',
                hintText: 'Ana',
              ),
              validator: (value) => _validateName(value, 'Ime'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: data.lastNameController,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Prezime',
                hintText: 'Anic',
              ),
              validator: (value) => _validateName(value, 'Prezime'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: data.gender,
              decoration: const InputDecoration(labelText: 'Spol'),
              items: const [
                DropdownMenuItem<int>(
                  value: PassengerGender.female,
                  child: Text('Zensko'),
                ),
                DropdownMenuItem<int>(
                  value: PassengerGender.male,
                  child: Text('Musko'),
                ),
                DropdownMenuItem<int>(
                  value: PassengerGender.other,
                  child: Text('Drugo'),
                ),
              ],
              onChanged: (value) => data.gender = value,
              validator: (value) => value == null ? 'Spol je obavezan.' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: data.passportController,
              textInputAction: TextInputAction.done,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Broj pasosa',
                hintText: 'B1234567',
              ),
              validator: _validatePassportNumber,
            ),
          ],
        ),
      ),
    );
  }

  static String? _validateName(String? value, String label) {
    final normalized = value?.trim() ?? '';

    if (normalized.isEmpty) {
      return '$label je obavezno polje.';
    }

    if (normalized.length < 2 || normalized.length > 50) {
      return '$label mora imati 2-50 karaktera.';
    }

    if (normalized.runes.any(_isInvalidNameRune)) {
      return '$label smije sadrzavati samo slova, razmake, crticu i apostrof.';
    }

    return null;
  }

  static bool _isInvalidNameRune(int rune) {
    final isAsciiLetter =
        (rune >= 65 && rune <= 90) || (rune >= 97 && rune <= 122);
    final isLatinLetter = rune >= 0x00C0 && rune <= 0x024F;
    final isAllowedSeparator = rune == 32 || rune == 39 || rune == 45;

    return !isAsciiLetter && !isLatinLetter && !isAllowedSeparator;
  }

  static String? _validatePassportNumber(String? value) {
    final normalized = value?.trim() ?? '';

    if (normalized.isEmpty) {
      return 'Broj pasosa je obavezno polje.';
    }

    if (!RegExp(r'^[A-Za-z0-9]{6,20}$').hasMatch(normalized)) {
      return 'Broj pasosa mora imati 6-20 slova ili brojeva.';
    }

    return null;
  }
}

class _PassengerFormData {
  _PassengerFormData({required this.seatNumber});

  final String seatNumber;
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController passportController = TextEditingController();
  int? gender;

  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    passportController.dispose();
  }
}
