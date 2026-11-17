import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

import '../config/app_config.dart';

/// Matches the backend's JWALLET-E2E-v1 protocol. A fresh key per request.
class E2eCipher {
  E2eCipher(this.config);
  final AppConfig config;

  EncryptedRequest seal(
    String method,
    String path,
    Map<String, dynamic>? body,
  ) {
    final domain = ECDomainParameters('prime256v1');
    final random = FortunaRandom()..seed(KeyParameter(_randomBytes(32)));
    final generator = ECKeyGenerator()
      ..init(ParametersWithRandom(ECKeyGeneratorParameters(domain), random));
    final pair = generator.generateKeyPair();
    final agreement = ECDHBasicAgreement()..init(pair.privateKey);
    final serverPoint = domain.curve.decodePoint(
      base64Decode(config.encPublicKey),
    );
    if (serverPoint == null || serverPoint.isInfinity) {
      throw const FormatException('Invalid server encryption key');
    }
    final shared = agreement.calculateAgreement(
      ECPublicKey(serverPoint, domain),
    );
    final sharedBytes = Uint8List(32);
    var value = shared;
    for (var i = 31; i >= 0; i--) {
      sharedBytes[i] = (value & BigInt.from(255)).toInt();
      value >>= 8;
    }
    final nonceBytes = _randomBytes(16);
    final nonce = base64UrlEncode(nonceBytes).replaceAll('=', '');
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final derivator = HKDFKeyDerivator(SHA256Digest())
      ..init(
        HkdfParameters(
          sharedBytes,
          32,
          nonceBytes,
          _bytes('JWALLET-E2E-v1|${config.encKeyId}'),
        ),
      );
    final key = Uint8List(32);
    derivator.deriveKey(null, 0, key, 0);
    final aad =
        'JWALLET-E2E-v1\nREQ\n${method.toUpperCase()}\n$path\n$timestamp\n$nonce';
    return EncryptedRequest(
      key,
      nonce: nonce,
      headers: {
        'X-Encrypted': '1',
        'X-Enc-Kid': config.encKeyId,
        'X-Enc-Epk': base64Encode(pair.publicKey.Q!.getEncoded(false)),
        'X-Enc-Ts': timestamp,
        'X-Enc-Nonce': nonce,
      },
      body: body == null
          ? null
          : {'payload': _seal(key, jsonEncode(body), aad)},
    );
  }

  static Uint8List _randomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List.generate(length, (_) => random.nextInt(256)),
    );
  }

  static Uint8List _bytes(String value) =>
      Uint8List.fromList(utf8.encode(value));

  static String _seal(Uint8List key, String plaintext, String aad) {
    final iv = _randomBytes(12);
    final cipher = GCMBlockCipher(AESEngine())
      ..init(true, AEADParameters(KeyParameter(key), 128, iv, _bytes(aad)));
    return base64Encode([...iv, ...cipher.process(_bytes(plaintext))]);
  }
}

class EncryptedRequest {
  EncryptedRequest(
    this._key, {
    required this.nonce,
    required this.headers,
    required this.body,
  });
  final Uint8List _key;
  final String nonce;
  final Map<String, String> headers;
  final Map<String, String>? body;

  Map<String, dynamic> openResponse(int status, String payload) {
    final bytes = base64Decode(payload);
    if (bytes.length < 28) {
      throw const FormatException('Invalid encrypted response');
    }
    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        false,
        AEADParameters(
          KeyParameter(_key),
          128,
          bytes.sublist(0, 12),
          E2eCipher._bytes('JWALLET-E2E-v1\nRES\n$nonce\n$status'),
        ),
      );
    return jsonDecode(utf8.decode(cipher.process(bytes.sublist(12))))
        as Map<String, dynamic>;
  }
}
