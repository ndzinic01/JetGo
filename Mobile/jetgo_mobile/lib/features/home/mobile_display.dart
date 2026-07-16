class MobileDisplay {
  static String flightNumberLabel(String value) {
    final normalized = value.trim();

    if (normalized.isEmpty || normalized.toLowerCase() == 'string') {
      return 'Broj leta nije unesen';
    }

    return normalized.toUpperCase();
  }

  static String roleLabel(String value) {
    switch (value.trim().toLowerCase()) {
      case 'user':
        return 'Korisnik';
      case 'admin':
        return 'Administrator';
      default:
        return value;
    }
  }

  static String flightStatusLabel(int status) {
    switch (status) {
      case 1:
        return 'Zakazan';
      case 2:
        return 'Kasni';
      case 3:
        return 'Otkazan';
      case 4:
        return 'Zavrsen';
      default:
        return 'Nepoznato';
    }
  }

  static String reservationStatusLabel(int status) {
    switch (status) {
      case 1:
        return 'Na cekanju';
      case 2:
        return 'Potvrdjena';
      case 3:
        return 'Otkazana';
      case 4:
        return 'Zavrsena';
      default:
        return 'Nepoznato';
    }
  }

  static String notificationStatusLabel(int status) {
    switch (status) {
      case 1:
        return 'Neprocitana';
      case 2:
        return 'Procitana';
      default:
        return 'Nepoznato';
    }
  }

  static String paymentStatusLabel(int? status) {
    switch (status) {
      case 1:
        return 'Na cekanju';
      case 2:
        return 'Placeno';
      case 3:
        return 'Neuspjelo';
      case 4:
        return 'Refundirano';
      default:
        return 'Nepoznato';
    }
  }

  static String formatDateTime(DateTime value) {
    final local = value.toLocal();
    return '${_two(local.day)}.${_two(local.month)}.${local.year} ${_two(local.hour)}:${_two(local.minute)}';
  }

  static String formatMoney(double value, String currency) {
    return '${value.toStringAsFixed(2)} $currency';
  }

  static String baggageOfferLabel(
    int count, {
    double? unitPrice,
    String currency = 'BAM',
    bool includePrice = false,
  }) {
    if (count <= 0) {
      return 'Bez dodatnog prtljaga';
    }

    final noun = switch (count) {
      1 => 'dodatni kofer',
      2 || 3 || 4 => 'dodatna kofera',
      _ => 'dodatnih kofera',
    };

    final label = '$count $noun do 23 kg';

    if (!includePrice || unitPrice == null) {
      return label;
    }

    final total = unitPrice * count;
    return '$label (+${formatMoney(total, currency)})';
  }

  static String initials(String value) {
    final parts = value
        .split(' ')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) {
      return 'JG';
    }

    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }

    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }

  static String _two(int value) => value.toString().padLeft(2, '0');
}
