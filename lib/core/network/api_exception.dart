class ApiException implements Exception {
  const ApiException(
    this.message, {
    this.statusCode,
    this.code,
    this.notProcessed = false,
  });

  /// Shown to the user as-is. For server errors this is `meta.message`.
  final String message;
  final int? statusCode;
  final String? code;

  /// True only when the server certainly did not act on the request
  /// (connection failed, rate limited, or a gateway error before the app ran).
  /// A single-use refresh token is safe to keep after such a failure.
  final bool notProcessed;
}
