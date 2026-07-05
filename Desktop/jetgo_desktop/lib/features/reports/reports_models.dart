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

class ReportAmountSummary {
  ReportAmountSummary({
    required this.currency,
    required this.amount,
  });

  final String currency;
  final double amount;
}

class ReservationReportPreviewItem {
  ReservationReportPreviewItem({
    required this.reservationCode,
    required this.customerName,
    required this.routeCode,
    required this.statusLabel,
    required this.amount,
    required this.currency,
    required this.createdAtUtc,
  });

  final String reservationCode;
  final String customerName;
  final String routeCode;
  final String statusLabel;
  final double amount;
  final String currency;
  final DateTime createdAtUtc;
}

class ReservationsReportPreview {
  ReservationsReportPreview({
    required this.totalReservations,
    required this.paidReservations,
    required this.unpaidReservations,
    required this.totalSeats,
    required this.amounts,
    required this.sampleItems,
    required this.generatedAtLocal,
  });

  final int totalReservations;
  final int paidReservations;
  final int unpaidReservations;
  final int totalSeats;
  final List<ReportAmountSummary> amounts;
  final List<ReservationReportPreviewItem> sampleItems;
  final DateTime generatedAtLocal;
}

class PaymentReportPreviewItem {
  PaymentReportPreviewItem({
    required this.reservationCode,
    required this.customerName,
    required this.routeCode,
    required this.statusLabel,
    required this.amount,
    required this.currency,
    required this.createdAtUtc,
  });

  final String reservationCode;
  final String customerName;
  final String routeCode;
  final String statusLabel;
  final double amount;
  final String currency;
  final DateTime createdAtUtc;
}

class PaymentsReportPreview {
  PaymentsReportPreview({
    required this.totalPayments,
    required this.paidPayments,
    required this.refundedPayments,
    required this.pendingPayments,
    required this.failedPayments,
    required this.amounts,
    required this.sampleItems,
    required this.generatedAtLocal,
  });

  final int totalPayments;
  final int paidPayments;
  final int refundedPayments;
  final int pendingPayments;
  final int failedPayments;
  final List<ReportAmountSummary> amounts;
  final List<PaymentReportPreviewItem> sampleItems;
  final DateTime generatedAtLocal;
}

enum ReservationReportStatus {
  pending(1, 'Na cekanju'),
  confirmed(2, 'Potvrdjeno'),
  cancelled(3, 'Otkazano'),
  completed(4, 'Zavrseno');

  const ReservationReportStatus(this.value, this.label);

  final int value;
  final String label;
}

enum PaymentReportStatus {
  pending(1, 'Na cekanju'),
  paid(2, 'Placeno'),
  failed(3, 'Neuspjelo'),
  refunded(4, 'Refundirano');

  const PaymentReportStatus(this.value, this.label);

  final int value;
  final String label;
}
