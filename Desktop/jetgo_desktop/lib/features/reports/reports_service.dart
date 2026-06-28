import 'dart:io';

import '../../core/network/api_client.dart';
import 'reports_models.dart';

class ReportsService {
  ReportsService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

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
}
