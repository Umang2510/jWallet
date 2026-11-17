import 'package:flutter/services.dart';

class DeviceSecurityException implements Exception {
  const DeviceSecurityException(this.message, this.code);
  final String message;
  final String code;
  bool get cancelled => code == 'BIOMETRIC_CANCELLED';
}

/// Private keys stay in Android Keystore / iOS Keychain or Secure Enclave.
/// Device signing never prompts; biometric signing requires authentication per use.
class DeviceKeys {
  static const _channel = MethodChannel('com.jstack.jwallet/device_keys');

  Future<T> _invoke<T>(String method, [Map<String, dynamic>? arguments]) async {
    try {
      final result = await _channel.invokeMethod<T>(method, arguments);
      if (result == null) throw const DeviceSecurityException('Device security is unavailable.', 'UNAVAILABLE');
      return result;
    } on PlatformException catch (error) {
      throw DeviceSecurityException(error.message ?? 'Device security is unavailable.', error.code);
    } on MissingPluginException {
      throw const DeviceSecurityException('Device security is supported on Android and iOS.', 'UNSUPPORTED');
    }
  }

  Future<String> devicePublicKey() => _invoke<String>('devicePublicKey');
  Future<String> signRefresh(String payload) => _invoke<String>('signDevice', {'payload': payload});
  Future<bool> biometricAvailable() => _invoke<bool>('biometricAvailable');
  Future<bool> hasBiometricKey(String userId) => _invoke<bool>('hasBiometricKey', {'userId': userId});
  Future<String> enrollBiometricKey(String userId) => _invoke<String>('enrollBiometricKey', {'userId': userId});
  Future<String> signBiometric(String userId, String payload) => _invoke<String>('signBiometric', {'userId': userId, 'payload': payload});
}
