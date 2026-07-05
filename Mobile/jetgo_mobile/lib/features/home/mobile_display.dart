class MobileDisplay {
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
