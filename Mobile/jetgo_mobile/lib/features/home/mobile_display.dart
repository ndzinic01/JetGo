class MobileDisplay {
  static String flightStatusLabel(int status) {
    switch (status) {
      case 1:
        return 'Scheduled';
      case 2:
        return 'Delayed';
      case 3:
        return 'Cancelled';
      case 4:
        return 'Completed';
      default:
        return 'Unknown';
    }
  }

  static String reservationStatusLabel(int status) {
    switch (status) {
      case 1:
        return 'Pending';
      case 2:
        return 'Confirmed';
      case 3:
        return 'Cancelled';
      case 4:
        return 'Completed';
      default:
        return 'Unknown';
    }
  }

  static String notificationStatusLabel(int status) {
    switch (status) {
      case 1:
        return 'Unread';
      case 2:
        return 'Read';
      default:
        return 'Unknown';
    }
  }

  static String paymentStatusLabel(int? status) {
    switch (status) {
      case 1:
        return 'Pending';
      case 2:
        return 'Paid';
      case 3:
        return 'Failed';
      case 4:
        return 'Refunded';
      default:
        return 'Unknown';
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
