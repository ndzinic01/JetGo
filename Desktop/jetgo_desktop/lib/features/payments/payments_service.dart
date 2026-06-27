import '../../core/network/api_client.dart';
import '../reference_data/reference_data_models.dart';
import 'payments_models.dart';

class PaymentsService {
  PaymentsService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<PagedResult<PaymentItem>> fetchPayments({
    required String token,
    String? searchText,
    PaymentStatusValue? status,
    int pageSize = 100,
  }) async {
    final response = await _apiClient.getJson(
      '/api/Payments',
      token: token,
      queryParameters: <String, String>{
        'page': '1',
        'pageSize': pageSize.toString(),
        if (searchText != null && searchText.trim().isNotEmpty)
          'searchText': searchText.trim(),
        if (status != null) 'status': status.value.toString(),
      },
    );

    return _mapPagedResult(response, PaymentItem.fromJson);
  }

  Future<PaymentDetails> getPayment({
    required String token,
    required int id,
  }) async {
    final response = await _apiClient.getJson(
      '/api/Payments/$id',
      token: token,
    );

    return PaymentDetails.fromJson(response);
  }

  Future<PaymentDetails> refundPayment({
    required String token,
    required int id,
    required String reason,
  }) async {
    final response = await _apiClient.postJson(
      '/api/Payments/$id/refund',
      token: token,
      body: <String, dynamic>{
        'reason': reason.trim(),
      },
    );

    return PaymentDetails.fromJson(response);
  }

  Future<PayPalDebugSnapshot> getPayPalDebugSnapshot({
    required String token,
    required int id,
    String? callbackToken,
  }) async {
    final response = await _apiClient.getJson(
      '/api/Payments/$id/debug-paypal',
      token: token,
      queryParameters: <String, String>{
        if (callbackToken != null && callbackToken.trim().isNotEmpty)
          'callbackToken': callbackToken.trim(),
      },
    );

    return PayPalDebugSnapshot.fromJson(response);
  }

  PagedResult<T> _mapPagedResult<T>(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final rawItems = (json['items'] as List<dynamic>? ?? const []);

    return PagedResult<T>(
      items: rawItems
          .map((item) => fromJson(item as Map<String, dynamic>))
          .toList(),
      page: json['page'] as int? ?? 1,
      pageSize: json['pageSize'] as int? ?? rawItems.length,
      totalCount: json['totalCount'] as int? ?? rawItems.length,
      totalPages: json['totalPages'] as int? ?? 1,
      hasPreviousPage: json['hasPreviousPage'] as bool? ?? false,
      hasNextPage: json['hasNextPage'] as bool? ?? false,
    );
  }
}
