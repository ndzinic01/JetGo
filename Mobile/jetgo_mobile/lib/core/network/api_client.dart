import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../config/app_config.dart';
import 'api_exception.dart';

class ApiClient {
  static const Duration _requestTimeout = Duration(seconds: 20);

  ApiClient()
      : _httpClient = HttpClient()
          ..connectionTimeout = _requestTimeout;

  final HttpClient _httpClient;

  Uri get _baseUri {
    final configuredBaseUrl = AppConfig.apiBaseUrl.trim();

    if (configuredBaseUrl.isEmpty) {
      throw ApiException(
        statusCode: 500,
        message:
            'API adresa nije podesena. Pokrenite aplikaciju sa --dart-define=API_BASE_URL=<adresa-api-ja>.',
      );
    }

    return Uri.parse(
      configuredBaseUrl.endsWith('/')
          ? configuredBaseUrl
          : '$configuredBaseUrl/',
    );
  }

  Future<Map<String, dynamic>> getJson(
    String path, {
    String? token,
    Map<String, String>? queryParameters,
  }) async {
    final data = await _send(
      'GET',
      path,
      token: token,
      queryParameters: queryParameters,
    );

    if (data is Map<String, dynamic>) {
      return data;
    }

    throw ApiException(
      statusCode: 500,
      message: 'Odgovor servera nije u ocekivanom JSON formatu.',
    );
  }

  Future<Map<String, dynamic>> postJson(
    String path, {
    String? token,
    Map<String, dynamic>? body,
  }) async {
    final data = await _send(
      'POST',
      path,
      token: token,
      body: body,
    );

    if (data is Map<String, dynamic>) {
      return data;
    }

    return <String, dynamic>{};
  }

  Future<Map<String, dynamic>> putJson(
    String path, {
    String? token,
    Map<String, dynamic>? body,
  }) async {
    final data = await _send(
      'PUT',
      path,
      token: token,
      body: body,
    );

    if (data is Map<String, dynamic>) {
      return data;
    }

    return <String, dynamic>{};
  }

  Future<Object?> _send(
    String method,
    String path, {
    String? token,
    Map<String, dynamic>? body,
    Map<String, String>? queryParameters,
  }) async {
    try {
      final requestUri = _buildUri(path, queryParameters);
      final request = await _httpClient
          .openUrl(method, requestUri)
          .timeout(_requestTimeout);

      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');

      if (token != null && token.isNotEmpty) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      }

      if (body != null) {
        request.write(jsonEncode(body));
      }

      final response = await request.close().timeout(_requestTimeout);
      final responseBody = await response
          .transform(utf8.decoder)
          .join()
          .timeout(_requestTimeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw _buildApiException(response.statusCode, responseBody);
      }

      if (responseBody.trim().isEmpty) {
        return <String, dynamic>{};
      }

      return jsonDecode(responseBody);
    } on TimeoutException {
      throw ApiException(
        statusCode: 408,
        message:
            'Veza sa serverom je istekla. Provjerite da li je API pokrenut i da li koristite ispravnu adresu aplikacije.',
      );
    } on SocketException {
      throw ApiException(
        statusCode: 503,
        message:
            'Nije moguce povezati se sa serverom. Provjerite Docker/API i API adresu aplikacije.',
      );
    } on HttpException catch (error) {
      throw ApiException(
        statusCode: 503,
        message: 'Mrezna greska: ${error.message}',
      );
    }
  }

  Uri _buildUri(String path, Map<String, String>? queryParameters) {
    final normalizedPath = path.startsWith('/') ? path.substring(1) : path;
    final resolvedUri = _baseUri.resolve(normalizedPath);

    if (queryParameters == null || queryParameters.isEmpty) {
      return resolvedUri;
    }

    final sanitized = <String, String>{};
    for (final entry in queryParameters.entries) {
      if (entry.value.trim().isNotEmpty) {
        sanitized[entry.key] = entry.value;
      }
    }

    return resolvedUri.replace(
      queryParameters: sanitized.isEmpty ? null : sanitized,
    );
  }

  ApiException _buildApiException(int statusCode, String responseBody) {
    try {
      final decoded = jsonDecode(responseBody);

      if (decoded is Map<String, dynamic>) {
        final baseMessage = (decoded['message'] as String?) ??
            'Server je vratio gresku bez poruke.';
        final errors = decoded['errors'] as Map<String, dynamic>?;

        return ApiException(
          statusCode: statusCode,
          message: _composeUserMessage(baseMessage, errors),
          errors: errors,
        );
      }
    } catch (_) {
      // Ignore invalid JSON and fallback to raw body.
    }

    return ApiException(
      statusCode: statusCode,
      message: responseBody.isEmpty
          ? _emptyBodyMessage(statusCode)
          : responseBody,
    );
  }

  String _emptyBodyMessage(int statusCode) {
    switch (statusCode) {
      case 401:
        return 'Sesija je istekla ili vise nije vazeca. Prijavite se ponovo.';
      case 403:
        return 'Nemate ovlastenje za ovu akciju.';
      default:
        return 'Server je vratio gresku bez sadrzaja.';
    }
  }

  String _composeUserMessage(
    String baseMessage,
    Map<String, dynamic>? errors,
  ) {
    final details = _extractErrorDetails(errors);
    if (details.isEmpty) {
      return baseMessage;
    }

    final firstDetail = details.join(' ');
    if (baseMessage.contains(firstDetail)) {
      return baseMessage;
    }

    return '$baseMessage $firstDetail';
  }

  List<String> _extractErrorDetails(Map<String, dynamic>? errors) {
    if (errors == null || errors.isEmpty) {
      return const [];
    }

    final details = <String>[];
    for (final value in errors.values) {
      if (value is List) {
        for (final item in value) {
          final text = item?.toString().trim() ?? '';
          if (text.isNotEmpty && !details.contains(text)) {
            details.add(text);
          }
        }
      } else {
        final text = value?.toString().trim() ?? '';
        if (text.isNotEmpty && !details.contains(text)) {
          details.add(text);
        }
      }
    }

    return details.take(2).toList();
  }
}
