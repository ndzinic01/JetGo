import 'dart:convert';
import 'dart:io';

import '../config/app_config.dart';
import 'api_exception.dart';

class DownloadedFileResponse {
  DownloadedFileResponse({
    required this.fileName,
    required this.contentType,
    required this.bytes,
  });

  final String fileName;
  final String contentType;
  final List<int> bytes;
}

class ApiClient {
  ApiClient()
      : _httpClient = HttpClient()
          ..connectionTimeout = const Duration(seconds: 20);

  final HttpClient _httpClient;

  Uri get _baseUri => Uri.parse(
        AppConfig.apiBaseUrl.endsWith('/')
            ? AppConfig.apiBaseUrl
            : '${AppConfig.apiBaseUrl}/',
      );

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

  Future<Map<String, dynamic>> delete(
    String path, {
    String? token,
  }) async {
    final data = await _send(
      'DELETE',
      path,
      token: token,
    );

    if (data is Map<String, dynamic>) {
      return data;
    }

    return <String, dynamic>{};
  }

  Future<DownloadedFileResponse> downloadFile(
    String path, {
    String? token,
    Map<String, String>? queryParameters,
    String fallbackFileName = 'download.bin',
  }) async {
    final requestUri = _buildUri(path, queryParameters);
    final request = await _httpClient.openUrl('GET', requestUri);

    request.headers.set(HttpHeaders.acceptHeader, '*/*');

    if (token != null && token.isNotEmpty) {
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    }

    final response = await request.close();
    final bytes = <int>[];

    await for (final chunk in response) {
      bytes.addAll(chunk);
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final responseBody = utf8.decode(bytes, allowMalformed: true);
      throw _buildApiException(response.statusCode, responseBody);
    }

    final contentDisposition = response.headers.value('content-disposition');
    final fileName =
        _extractFileName(contentDisposition) ?? fallbackFileName;
    final contentType =
        response.headers.contentType?.mimeType ?? 'application/octet-stream';

    return DownloadedFileResponse(
      fileName: fileName,
      contentType: contentType,
      bytes: bytes,
    );
  }

  Future<dynamic> _send(
    String method,
    String path, {
    String? token,
    Map<String, dynamic>? body,
    Map<String, String>? queryParameters,
  }) async {
    final requestUri = _buildUri(path, queryParameters);
    final request = await _httpClient.openUrl(method, requestUri);

    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');

    if (token != null && token.isNotEmpty) {
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    }

    if (body != null) {
      request.write(jsonEncode(body));
    }

    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _buildApiException(response.statusCode, responseBody);
    }

    if (responseBody.trim().isEmpty) {
      return <String, dynamic>{};
    }

    return jsonDecode(responseBody);
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
        return ApiException(
          statusCode: statusCode,
          message: (decoded['message'] as String?) ??
              'Server je vratio gresku bez poruke.',
          errors: decoded['errors'] as Map<String, dynamic>?,
        );
      }
    } catch (_) {
      // Ignore invalid JSON and fallback to raw body.
    }

    return ApiException(
      statusCode: statusCode,
      message: responseBody.isEmpty
          ? 'Server je vratio gresku bez sadrzaja.'
          : responseBody,
    );
  }

  String? _extractFileName(String? contentDisposition) {
    if (contentDisposition == null || contentDisposition.trim().isEmpty) {
      return null;
    }

    final utf8Match = RegExp(
      r"filename\*=UTF-8''([^;]+)",
      caseSensitive: false,
    ).firstMatch(contentDisposition);

    if (utf8Match != null) {
      return Uri.decodeComponent(utf8Match.group(1)!);
    }

    final plainMatch = RegExp(
      r'filename="?([^";]+)"?',
      caseSensitive: false,
    ).firstMatch(contentDisposition);

    return plainMatch?.group(1);
  }
}
