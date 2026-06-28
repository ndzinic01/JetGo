class SavedReportFile {
  SavedReportFile({
    required this.fileName,
    required this.filePath,
    required this.contentType,
    required this.savedAtLocal,
  });

  final String fileName;
  final String filePath;
  final String contentType;
  final DateTime savedAtLocal;
}

enum ReservationReportStatus {
  pending(1, 'Pending'),
  confirmed(2, 'Confirmed'),
  cancelled(3, 'Cancelled'),
  completed(4, 'Completed');

  const ReservationReportStatus(this.value, this.label);

  final int value;
  final String label;
}

enum PaymentReportStatus {
  pending(1, 'Pending'),
  paid(2, 'Paid'),
  failed(3, 'Failed'),
  refunded(4, 'Refunded');

  const PaymentReportStatus(this.value, this.label);

  final int value;
  final String label;
}
