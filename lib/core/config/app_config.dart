/// App settings injected at build time with `--dart-define-from-file`.
///
///   flutter run --dart-define-from-file=env/local.json
///   flutter build apk --release --dart-define-from-file=env/prod.json
///
/// Only PUBLIC values live here (base URL, the server's public encryption
/// key). Never put secrets in the app.
class AppConfig {
  const AppConfig({
    required this.apiBaseUrl,
    required this.encKeyId,
    required this.encPublicKey,
  });

  /// Debug and release both use the hosted backend by default.
  /// Explicit --dart-define values can override these public settings.
  factory AppConfig.fromEnvironment() => const AppConfig(
    apiBaseUrl: String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'https://jwallet-backend.onrender.com',
    ),
    encKeyId: String.fromEnvironment('ENC_KEY_ID', defaultValue: 'prod-1'),
    encPublicKey: String.fromEnvironment(
      'ENC_PUBLIC_KEY',
      defaultValue: 'BAzscdxu/qcQ9O3a6x5txZYmXyVo6GJPO96AV7bGQ96kr45oHkw6eYBIT2cCBTyfgfliNHRBEUVBufhhHgNhxTc=',
    ),
  );

  /// API origin, without a trailing slash or /api/v1 suffix.
  final String apiBaseUrl;

  /// Id of the server encryption key (must match the backend's SERVER_ENC_KEY_ID).
  final String encKeyId;

  /// Server's P-256 public key, base64 uncompressed point (65 bytes).
  final String encPublicKey;
}
