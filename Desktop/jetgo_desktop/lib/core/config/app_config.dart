class AppConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
  );

  static String get apiBaseUrlLabel {
    return apiBaseUrl.trim().isEmpty
        ? 'API_BASE_URL nije podesena'
        : apiBaseUrl;
  }
}
