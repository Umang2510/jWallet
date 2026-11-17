import '../../../core/crypto/device_keys.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/authenticated_client.dart';

class SecurityRepository {
  SecurityRepository(this._client, this._keys);
  final AuthenticatedClient _client;
  final DeviceKeys _keys;

  Future<void> setPin(String pin) async {
    await _client.request('POST', '/api/v1/security/pin', body: {'pin': pin});
  }

  Future<bool> biometricAvailable() async {
    try { return await _keys.biometricAvailable(); }
    on DeviceSecurityException { return false; }
  }

  Future<void> enrollBiometrics(String pin) async {
    final session = await _client.session();
    final userId = session?['userId'] as String?;
    if (userId == null) throw const ApiException('Please sign in again to set up biometrics.', code: 'REAUTH_REQUIRED');
    final publicKey = await _keys.enrollBiometricKey(userId);
    // The system prompt can outlive navigation/logout. Never enroll into a different session.
    if ((await _client.session())?['userId'] != userId) {
      throw const ApiException('Your session changed. Please sign in again.', code: 'REAUTH_REQUIRED');
    }
    await _client.request('POST', '/api/v1/devices/biometric', body: {'publicKey': publicKey, 'pin': pin});
  }
}
