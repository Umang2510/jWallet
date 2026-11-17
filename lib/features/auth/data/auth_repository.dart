import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/storage/secure_store.dart';

class AuthResult {
  const AuthResult({required this.pinSet});
  final bool pinSet;
}

class AuthRepository {
  AuthRepository(this._api, this._store);
  final ApiClient _api;
  final SecureStore _store;

  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    final body = await _api.request(
      'POST',
      '/api/v1/auth/login',
      body: {
        'email': email.trim().toLowerCase(),
        'password': password,
        'deviceId': await _store.deviceId(),
      },
    );
    final token = body['accessToken'] as String;
    final refresh = body['refreshToken'] as String;
    final pinSet = (body['security'] as Map<String, dynamic>)['pinSet'] as bool;
    await _store.saveSession({'accessToken': token, 'refreshToken': refresh});
    return AuthResult(pinSet: pinSet);
  }

  Future<AuthResult?> restoreSession() async {
    final saved = await _store.readSession();
    if (saved == null) return null;
    try {
      final profile = await _api.request(
        'GET',
        '/api/v1/users/profile',
        accessToken: saved['accessToken'] as String,
      );
      return AuthResult(
        pinSet: (profile['security'] as Map<String, dynamic>)['pinSet'] as bool,
      );
    } on ApiException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        await _store.clearSession();
        return null;
      }
      rethrow;
    }
  }

  Future<void> logout() async {
    final saved = await _store.readSession();
    try {
      if (saved != null) {
        await _api.request(
          'POST',
          '/api/v1/auth/logout',
          body: {},
          accessToken: saved['accessToken'] as String,
        );
      }
    } finally {
      await _store.clearSession();
    }
  }
}
