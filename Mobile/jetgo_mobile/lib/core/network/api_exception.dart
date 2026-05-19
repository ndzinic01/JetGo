class ApiException implements Exception {
  ApiException({
    required this.statusCode,
    required this.message,
    this.errors,
  });

  final int statusCode;
  final String message;
  final Map<String, dynamic>? errors;

  @override
  String toString() => 'ApiException($statusCode): $message';
}
