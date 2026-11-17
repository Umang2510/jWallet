import '../../../core/crypto/device_keys.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/authenticated_client.dart';
import '../../../core/storage/secure_store.dart';

class AuthResult {
  const AuthResult({
    required this.pinSet,
    this.biometricEnrolled = false,
    this.offerBiometricSetup = false,
  });
  final bool pinSet;

  /// Enrolled on the server AND the key still exists on this device.
  final bool biometricEnrolled;

  /// Fresh login on a device that can do biometrics but has not enrolled.
  final bool offerBiometricSetup;
}

class AuthRepository {
  AuthRepository(this._api, this._store, this._authenticated, this._keys);
  final ApiClient _api;
  final SecureStore _store;
  final AuthenticatedClient _authenticated;
  final DeviceKeys _keys;
  Stream<ApiException> get expired => _authenticated.expired;

  Future<AuthResult> login({required String email, required String password}) async {
    final body = await _api.request('POST', '/api/v1/auth/login', body: {
      'email': email.trim().toLowerCase(), 'password': password,
      'deviceId': await _store.deviceId(),
      'devicePublicKey': await _keys.devicePublicKey(),
    });
    await _authenticated.saveLogin(body);
    final result = await _result(
      body['security'] as Map<String, dynamic>,
      (body['user'] as Map<String, dynamic>)['id'] as String,
    );
    // Offered after a password login only, never when restoring a session.
    final offer = result.pinSet &&
        !result.biometricEnrolled &&
        await _biometricAvailable();
    return AuthResult(
      pinSet: result.pinSet,
      biometricEnrolled: result.biometricEnrolled,
      offerBiometricSetup: offer,
    );
  }

  Future<bool> _biometricAvailable() async {
    try {
      return await _keys.biometricAvailable();
    } on DeviceSecurityException {
      return false;
    }
  }

  Future<AuthResult> _result(Map<String, dynamic> security, String userId) async {
    var enrolled = security['biometricEnrolled'] == true;
    if (enrolled) {
      try { enrolled = await _keys.hasBiometricKey(userId); }
      on DeviceSecurityException { enrolled = false; }
    }
    return AuthResult(pinSet: security['pinSet'] == true, biometricEnrolled: enrolled);
  }

  Future<AuthResult?> restoreSession() async {
    if (await _authenticated.session() == null) return null;
    try {
      final profile = await _authenticated.request('GET', '/api/v1/users/profile');
      return await _result(profile['security'] as Map<String, dynamic>, profile['id'] as String);
    } on ApiException catch (error) {
      if (error.statusCode == 401 || error.code == 'ACCOUNT_INACTIVE') return null;
      rethrow;
    }
  }

  Future<void> clearSession() => _authenticated.clear();

  Future<void> logout() async {
    try {
      if (await _authenticated.session() != null) {
        await _authenticated.request('POST', '/api/v1/auth/logout', body: {});
      }
    } finally {
      await _authenticated.clear();
    }
  }
}
