import '../../core/network/api_client.dart';
import 'overview_models.dart';

class OverviewService {
  OverviewService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<AdminDashboardSummary> fetchSummary({
    required String token,
  }) async {
    final response = await _apiClient.getJson(
      '/api/AdminDashboard/summary',
      token: token,
    );

    return AdminDashboardSummary.fromJson(response);
  }
}
