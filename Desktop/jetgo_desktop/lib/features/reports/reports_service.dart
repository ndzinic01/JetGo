import 'dart:io';

import '../../core/network/api_client.dart';
import '../payments/payments_models.dart' as payments;
import '../reservations/reservations_models.dart' as reservations;
import 'reports_models.dart';

class ReportsService {
  ReportsService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<ReservationsReportPreview> loadReservationsPreview({
    required String token,
    ReservationReportStatus? status,
    DateTime? createdFromLocal,
    DateTime? createdToLocal,
  }) async {
    var page = 1;
    var totalReservations = 0;
    var paidReservations = 0;
    var totalSeats = 0;
    final amounts = <String, double>{};
    final sampleItems = <ReservationReportPreviewItem>[];

    while (true) {
      final response = await _apiClient.getJson(
        '/api/Reservations',
        token: token,
        queryParameters: <String, String>{
          'page': page.toString(),
          'pageSize': '100',
          ..._buildQueryParameters(
            statusValue: status?.value,
            createdFromLocal: createdFromLocal,
            createdToLocal: createdToLocal,
          ),
        },
      );

      final payload = _mapPagedPayload(
        response,
        reservations.ReservationItem.fromJson,
      );

      for (final item in payload.items) {
        totalReservations++;
        if (item.isPaid) {
          paidReservations++;
        }
        totalSeats += item.seatsCount;
        _addAmount(amounts, item.currency, item.totalAmount);

        if (sampleItems.length < 5) {
          sampleItems.add(
            ReservationReportPreviewItem(
              reservationCode: item.reservationCode,
              customerName: item.customerName,
              routeCode: item.routeCode,
              statusLabel: item.status.label,
              amount: item.totalAmount,
              currency: item.currency,
              createdAtUtc: item.createdAtUtc,
            ),
          );
        }
      }

      if (!payload.hasNextPage || page >= payload.totalPages) {
        break;
      }

      page++;
    }

    return ReservationsReportPreview(
      totalReservations: totalReservations,
      paidReservations: paidReservations,
      unpaidReservations: totalReservations - paidReservations,
      totalSeats: totalSeats,
      amounts: _mapAmounts(amounts),
      sampleItems: sampleItems,
      generatedAtLocal: DateTime.now(),
    );
  }

  Future<PaymentsReportPreview> loadPaymentsPreview({
    required String token,
    PaymentReportStatus? status,
    DateTime? createdFromLocal,
    DateTime? createdToLocal,
  }) async {
    var page = 1;
    var totalPayments = 0;
    var paidPayments = 0;
    var refundedPayments = 0;
    var pendingPayments = 0;
    var failedPayments = 0;
    final amounts = <String, double>{};
    final sampleItems = <PaymentReportPreviewItem>[];

    while (true) {
      final response = await _apiClient.getJson(
        '/api/Payments',
        token: token,
        queryParameters: <String, String>{
          'page': page.toString(),
          'pageSize': '100',
          ..._buildQueryParameters(
            statusValue: status?.value,
            createdFromLocal: createdFromLocal,
            createdToLocal: createdToLocal,
          ),
        },
      );

      final payload = _mapPagedPayload(response, payments.PaymentItem.fromJson);

      for (final item in payload.items) {
        totalPayments++;
        switch (item.status) {
          case payments.PaymentStatusValue.pending:
            pendingPayments++;
            break;
          case payments.PaymentStatusValue.paid:
            paidPayments++;
            break;
          case payments.PaymentStatusValue.failed:
            failedPayments++;
            break;
          case payments.PaymentStatusValue.refunded:
            refundedPayments++;
            break;
        }

        _addAmount(amounts, item.currency, item.amount);

        if (sampleItems.length < 5) {
          sampleItems.add(
            PaymentReportPreviewItem(
              reservationCode: item.reservationCode,
              customerName: item.customerName,
              routeCode: item.routeCode,
              statusLabel: item.status.label,
              amount: item.amount,
              currency: item.currency,
              createdAtUtc: item.createdAtUtc,
            ),
          );
        }
      }

      if (!payload.hasNextPage || page >= payload.totalPages) {
        break;
      }

      page++;
    }

    return PaymentsReportPreview(
      totalPayments: totalPayments,
      paidPayments: paidPayments,
      refundedPayments: refundedPayments,
      pendingPayments: pendingPayments,
      failedPayments: failedPayments,
      amounts: _mapAmounts(amounts),
      sampleItems: sampleItems,
      generatedAtLocal: DateTime.now(),
    );
  }

  Future<SavedReportFile> downloadReservationsReport({
    required String token,
    ReservationReportStatus? status,
    DateTime? createdFromLocal,
    DateTime? createdToLocal,
  }) async {
    final response = await _apiClient.downloadFile(
      '/api/Reports/reservations.pdf',
      token: token,
      fallbackFileName: 'jetgo-reservations-report.pdf',
      queryParameters: _buildQueryParameters(
        statusValue: status?.value,
        createdFromLocal: createdFromLocal,
        createdToLocal: createdToLocal,
      ),
    );

    return _saveReport(response);
  }

  Future<SavedReportFile> downloadPaymentsReport({
    required String token,
    PaymentReportStatus? status,
    DateTime? createdFromLocal,
    DateTime? createdToLocal,
  }) async {
    final response = await _apiClient.downloadFile(
      '/api/Reports/payments.pdf',
      token: token,
      fallbackFileName: 'jetgo-payments-report.pdf',
      queryParameters: _buildQueryParameters(
        statusValue: status?.value,
        createdFromLocal: createdFromLocal,
        createdToLocal: createdToLocal,
      ),
    );

    return _saveReport(response);
  }

  Future<void> openContainingFolder(String filePath) async {
    if (filePath.trim().isEmpty) {
      return;
    }

    if (Platform.isWindows) {
      final normalizedPath = filePath.replaceAll('/', r'\');
      await Process.start('explorer.exe', ['/select,$normalizedPath']);
      return;
    }

    final file = File(filePath);
    final directoryPath = file.parent.path;
    await Process.start('xdg-open', [directoryPath]);
  }

  Map<String, String> _buildQueryParameters({
    required int? statusValue,
    required DateTime? createdFromLocal,
    required DateTime? createdToLocal,
  }) {
    return <String, String>{
      if (statusValue != null) 'status': statusValue.toString(),
      if (createdFromLocal != null)
        'createdFromUtc': _toUtcStartOfDay(createdFromLocal).toIso8601String(),
      if (createdToLocal != null)
        'createdToUtc': _toUtcEndOfDay(createdToLocal).toIso8601String(),
    };
  }

  Future<SavedReportFile> _saveReport(DownloadedFileResponse response) async {
    final reportsDirectory = await _resolveReportsDirectory();
    final filePath =
        '${reportsDirectory.path}${Platform.pathSeparator}${response.fileName}';
    final file = File(filePath);

    await file.writeAsBytes(response.bytes, flush: true);

    return SavedReportFile(
      fileName: response.fileName,
      filePath: filePath,
      contentType: response.contentType,
      savedAtLocal: DateTime.now(),
    );
  }

  Future<Directory> _resolveReportsDirectory() async {
    final userProfile = Platform.environment['USERPROFILE']?.trim();
    final downloadsRoot =
        (userProfile == null || userProfile.isEmpty)
            ? Directory.systemTemp.path
            : '$userProfile${Platform.pathSeparator}Downloads';

    final directory = Directory(
      '$downloadsRoot${Platform.pathSeparator}JetGoReports',
    );

    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    return directory;
  }

  DateTime _toUtcStartOfDay(DateTime value) {
    return DateTime(
      value.year,
      value.month,
      value.day,
    ).toUtc();
  }

  DateTime _toUtcEndOfDay(DateTime value) {
    return DateTime(
      value.year,
      value.month,
      value.day,
      23,
      59,
      59,
      999,
    ).toUtc();
  }

  void _addAmount(Map<String, double> amounts, String currency, double amount) {
    final normalizedCurrency = currency.trim().isEmpty ? 'N/A' : currency;
    amounts.update(
      normalizedCurrency,
      (current) => current + amount,
      ifAbsent: () => amount,
    );
  }

  List<ReportAmountSummary> _mapAmounts(Map<String, double> amounts) {
    final entries = amounts.entries.toList()
      ..sort((left, right) => left.key.compareTo(right.key));

    return entries
        .map(
          (entry) => ReportAmountSummary(
            currency: entry.key,
            amount: entry.value,
          ),
        )
        .toList();
  }

  _PagedPayload<T> _mapPagedPayload<T>(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final rawItems = json['items'] as List<dynamic>? ?? const [];

    return _PagedPayload<T>(
      items: rawItems
          .map((item) => fromJson(item as Map<String, dynamic>))
          .toList(),
      totalPages: json['totalPages'] as int? ?? 1,
      hasNextPage: json['hasNextPage'] as bool? ?? false,
    );
  }
}

class _PagedPayload<T> {
  _PagedPayload({
    required this.items,
    required this.totalPages,
    required this.hasNextPage,
  });

  final List<T> items;
  final int totalPages;
  final bool hasNextPage;
}
