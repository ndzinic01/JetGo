class ApiException implements Exception {
  ApiException({required this.statusCode, required this.message, this.errors});

  final int statusCode;
  final String message;
  final Map<String, dynamic>? errors;

  String? fieldError(String fieldName) {
    final errorMap = errors;
    if (errorMap == null || errorMap.isEmpty) {
      return null;
    }

    final normalizedFieldName = _normalizeFieldName(fieldName);

    for (final entry in errorMap.entries) {
      if (_normalizeFieldName(entry.key) != normalizedFieldName) {
        continue;
      }

      final message = _extractFirstMessage(entry.value);
      if (message != null) {
        return message;
      }
    }

    return null;
  }

  @override
  String toString() => 'ApiException($statusCode): $message';

  static String _normalizeFieldName(String value) {
    final lastSegment = value.split('.').last;
    final withoutIndexer = lastSegment.replaceAll(RegExp(r'\[[^\]]*\]'), '');
    return withoutIndexer.toLowerCase();
  }

  static String? _extractFirstMessage(Object? value) {
    if (value is List) {
      for (final item in value) {
        final text = item?.toString().trim() ?? '';
        if (text.isNotEmpty) {
          return text;
        }
      }
      return null;
    }

    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }
}
