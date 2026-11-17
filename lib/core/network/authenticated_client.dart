import 'dart:async';

import '../crypto/device_keys.dart';
import '../storage/secure_store.dart';
import 'api_client.dart';
import 'api_exception.dart';

/// All authenticated requests share one refresh operation and one token record.
class AuthenticatedClient {
  AuthenticatedClient(this._api, this._store, this._keys);
  final ApiClient _api;
  final SecureStore _store;
  final DeviceKeys _keys;
  final _expired = StreamController<ApiException>.broadcast(sync: true);
  Stream<ApiException> get expired => _expired.stream;
  Future<void>? _refreshing;
  Future<void> _writes = Future.value();
  Map<String, dynamic>? _session;
  bool _loaded = false;
  int _generation = 0;

  Future<Map<String, dynamic>?> session() async {
    if (!_loaded) {
      final generation = _generation;
      final stored = await _store.readSession();
      if (generation == _generation && !_loaded) {
        _session = stored;
        _loaded = true;
      }
    }
    return _session == null ? null : Map.of(_session!);
  }

  Future<void> _write(Future<void> Function() operation) {
    final next = _writes.then((_) => operation());
    _writes = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }

  Future<void> saveLogin(Map<String, dynamic> body) async {
    final generation = ++_generation;
    final record = <String, dynamic>{
      'accessToken': body['accessToken'] as String,
      'refreshToken': body['refreshToken'] as String,
      'userId': (body['user'] as Map<String, dynamic>)['id'] as String,
    };
    await _write(() async {
      if (generation != _generation) return;
      await _store.saveSession(record);
      _session = record;
      _loaded = true;
    });
  }

  Future<void> clear({ApiException? reason}) async {
    ++_generation;
    _session = null;
    _loaded = true;
    await _write(_store.clearSession);
    if (reason != null) _expired.add(reason);
  }

  Future<Map<String, dynamic>> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    final current = await session();
    if (current == null) throw const ApiException('Please sign in again.', statusCode: 401);
    final generation = _generation;
    var token = current['accessToken'] as String;
    try {
      return await _api.request(
        method,
        path,
        body: body,
        headers: headers,
        accessToken: token,
      );
    } on ApiException catch (error) {
      if (generation != _generation) rethrow;
      if (error.code != 'TOKEN_EXPIRED') {
        if (error.statusCode == 401 || error.code == 'ACCOUNT_INACTIVE' || error.code == 'DEVICE_REVOKED') {
          await clear(reason: error);
        }
        rethrow;
      }
    }
    await _refresh(token, generation);
    if (generation != _generation || _session == null) {
      throw const ApiException('Your session changed. Please sign in again.', statusCode: 401);
    }
    token = _session!['accessToken'] as String;
    try {
      // One retry only, freshly encrypted with a new nonce.
      return await _api.request(
        method,
        path,
        body: body,
        headers: headers,
        accessToken: token,
      );
    } on ApiException catch (error) {
      if (generation == _generation && (error.statusCode == 401 || error.code == 'ACCOUNT_INACTIVE')) {
        await clear(reason: error);
      }
      rethrow;
    }
  }

  Future<void> _refresh(String rejectedToken, int generation) async {
    if (generation != _generation) return;
    if (_session?['accessToken'] != rejectedToken) return;
    if (_refreshing != null) {
      await _refreshing;
      // A previous login's refresh must not be reused for a new session.
      if (generation == _generation && _session?['accessToken'] == rejectedToken) {
        return _refresh(rejectedToken, generation);
      }
      return;
    }
    final operation = _rotate(generation);
    _refreshing = operation;
    try {
      await operation;
    } finally {
      if (identical(_refreshing, operation)) _refreshing = null;
    }
  }

  Future<void> _rotate(int generation) async {
    try {
      final refresh = _session!['refreshToken'] as String;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final signature = await _keys.signRefresh('JWALLET-REFRESH\n$refresh\n$timestamp');
      if (generation != _generation) return;
      final body = await _api.request('POST', '/api/v1/auth/refresh', body: {
        'refreshToken': refresh,
        'deviceId': await _store.deviceId(),
        'timestamp': timestamp,
        'signature': signature,
      });
      await _write(() async {
        if (generation != _generation) return;
        final record = {..._session!, 'accessToken': body['accessToken'] as String, 'refreshToken': body['refreshToken'] as String};
        await _store.saveSession(record);
        _session = record;
      });
    } on ApiException catch (error) {
      // A refresh token works once. If the server may have consumed it (lost
      // response, timeout after send, 5xx) it can never be replayed, so the
      // session ends. If the request provably never ran (offline, rate
      // limited) the token is intact: keep the session and let the user retry.
      if (generation == _generation && !error.notProcessed) {
        await clear(reason: error);
      }
      rethrow;
    } on DeviceSecurityException catch (error) {
      final failure = ApiException('${error.message} Please sign in again.', statusCode: 401);
      if (generation == _generation) await clear(reason: failure);
      throw failure;
    } catch (_) {
      const failure = ApiException('Unable to renew your session securely. Please sign in again.', statusCode: 401);
      if (generation == _generation) await clear(reason: failure);
      throw failure;
    }
  }

  Future<void> dispose() => _expired.close();
}
