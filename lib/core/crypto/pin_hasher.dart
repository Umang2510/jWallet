import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

/// Salted PBKDF2-HMAC-SHA256 for the on-device app lock PIN.
///
/// The record lives in Keystore/Keychain-backed secure storage and wrong
/// guesses are rate limited, so the iteration count is kept modest to keep
/// unlocking instant on low-end phones. The transaction PIN is NOT handled
/// here: it never leaves the user's head except to the server.
abstract final class PinHasher {
  static const _iterations = 10000;

  static Uint8List newSalt() {
    final random = Random.secure();
    return Uint8List.fromList(List.generate(16, (_) => random.nextInt(256)));
  }

  /// Runs off the UI thread. Returns base64.
  static Future<String> hash(String pin, Uint8List salt) =>
      Isolate.run(() => _derive(pin, salt));

  static String _derive(String pin, Uint8List salt) {
    final derivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
      ..init(Pbkdf2Parameters(salt, _iterations, 32));
    return base64Encode(derivator.process(Uint8List.fromList(utf8.encode(pin))));
  }

  /// Compares without stopping at the first difference.
  static bool equal(String a, String b) {
    final x = utf8.encode(a);
    final y = utf8.encode(b);
    var diff = x.length ^ y.length;
    for (var i = 0; i < x.length && i < y.length; i++) {
      diff |= x[i] ^ y[i];
    }
    return diff == 0;
  }
}
