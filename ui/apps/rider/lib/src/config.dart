class AppConfig {
  const AppConfig._();

  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );
  static const mapboxPublicToken = String.fromEnvironment('MAPBOX_PUBLIC_TOKEN');
}
