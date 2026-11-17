import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

class SecureStore {
  SecureStore(this._storage);
  final FlutterSecureStorage _storage;
  static const _sessionKey = 'jwallet.session';
  static const _deviceKey = 'jwallet.device';

  Future<String> deviceId() async {
    final existing = await _storage.read(key: _deviceKey);
    if (existing != null) return existing;
    final id = const Uuid().v4();
    await _storage.write(key: _deviceKey, value: id);
    return id;
  }

  /// One record prevents partially written token pairs. Never stores passwords.
  Future<void> saveSession(Map<String, dynamic> session) =>
      _storage.write(key: _sessionKey, value: jsonEncode(session));
  Future<Map<String, dynamic>?> readSession() async {
    final value = await _storage.read(key: _sessionKey);
    return value == null ? null : jsonDecode(value) as Map<String, dynamic>;
  }

  Future<void> clearSession() => _storage.delete(key: _sessionKey);
}
