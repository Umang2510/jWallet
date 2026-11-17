import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

class SecureStore {
  SecureStore(this._storage);
  final FlutterSecureStorage _storage;
  static const _sessionKey = 'jwallet.session';
  static const _deviceKey = 'jwallet.device';
  static const _appLockKey = 'jwallet.applock';

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

  /// Ends the session: tokens AND the app lock PIN go together, so the next
  /// person to sign in sets up their own lock.
  Future<void> clearSession() async {
    await _storage.delete(key: _sessionKey);
    await _storage.delete(key: _appLockKey);
  }

  /// Everything the app stored on this phone: session, app lock PIN and the
  /// device id (the next sign-in registers as a brand new device).
  Future<void> clearAll() => _storage.deleteAll();

  /// The app lock PIN record (salted hash + attempt counters), only used on
  /// phones that have no screen lock of their own.
  Future<void> saveAppLock(Map<String, dynamic> record) =>
      _storage.write(key: _appLockKey, value: jsonEncode(record));
  Future<Map<String, dynamic>?> readAppLock() async {
    final value = await _storage.read(key: _appLockKey);
    return value == null ? null : jsonDecode(value) as Map<String, dynamic>;
  }
}
