import 'dart:convert';

import 'package:local_auth/local_auth.dart';

import '../../../core/crypto/pin_hasher.dart';
import '../../../core/storage/secure_store.dart';

/// How the app is locked on this phone.
enum AppLockMethod {
  /// The phone has its own screen lock (PIN, pattern, password, fingerprint,
  /// face). The app reuses it, so there is nothing for the user to remember.
  deviceLock,

  /// The phone has no screen lock, so the app keeps its own PIN.
  pin,
}

enum PinCheckStatus { correct, wrong, locked, notSet }

class PinCheck {
  const PinCheck(this.status, {this.attemptsLeft = 0, this.lockedFor});
  final PinCheckStatus status;
  final int attemptsLeft;
  final Duration? lockedFor;
}

class AppLockRepository {
  AppLockRepository(this._store, this._auth, {DateTime Function()? clock})
    : _now = clock ?? DateTime.now;

  final SecureStore _store;
  final LocalAuthentication _auth;
  final DateTime Function() _now;

  static const maxAttempts = 5;
  static const lockDuration = Duration(minutes: 5);

  /// Phone screen lock if there is one, otherwise the app's own PIN.
  Future<AppLockMethod> method() async {
    try {
      return await _auth.isDeviceSupported()
          ? AppLockMethod.deviceLock
          : AppLockMethod.pin;
    } catch (_) {
      return AppLockMethod.pin;
    }
  }

  /// Shows the system unlock prompt (biometric or the phone's PIN/pattern).
  /// False when the user dismissed it or it failed.
  Future<bool> authenticateWithDevice() => _auth.authenticate(
    localizedReason: 'Unlock jWallet',
    persistAcrossBackgrounding: true,
  );

  Future<bool> hasPin() async => await _store.readAppLock() != null;

  /// Length of the stored PIN (needed to draw the right number of dots).
  Future<int?> pinLength() async =>
      (await _store.readAppLock())?['length'] as int?;

  Future<void> createPin(String pin) async {
    final salt = PinHasher.newSalt();
    await _store.saveAppLock({
      'salt': base64Encode(salt),
      'hash': await PinHasher.hash(pin, salt),
      'length': pin.length,
      'failed': 0,
      'lockedUntil': 0,
    });
  }

  /// Checks a PIN and enforces the attempt limit: [maxAttempts] wrong tries
  /// lock the PIN for [lockDuration]. The counter is stored on the phone.
  Future<PinCheck> verifyPin(String pin) async {
    final record = await _store.readAppLock();
    if (record == null) return const PinCheck(PinCheckStatus.notSet);
    final now = _now().millisecondsSinceEpoch;
    final lockedUntil = record['lockedUntil'] as int? ?? 0;
    if (lockedUntil > now) {
      return PinCheck(
        PinCheckStatus.locked,
        lockedFor: Duration(milliseconds: lockedUntil - now),
      );
    }
    final salt = base64Decode(record['salt'] as String);
    final correct = PinHasher.equal(
      record['hash'] as String,
      await PinHasher.hash(pin, salt),
    );
    if (correct) {
      await _store.saveAppLock({...record, 'failed': 0, 'lockedUntil': 0});
      return const PinCheck(PinCheckStatus.correct);
    }
    final failed = (record['failed'] as int? ?? 0) + 1;
    if (failed >= maxAttempts) {
      await _store.saveAppLock({
        ...record,
        'failed': 0,
        'lockedUntil': now + lockDuration.inMilliseconds,
      });
      return const PinCheck(PinCheckStatus.locked, lockedFor: lockDuration);
    }
    await _store.saveAppLock({...record, 'failed': failed});
    return PinCheck(PinCheckStatus.wrong, attemptsLeft: maxAttempts - failed);
  }
}
