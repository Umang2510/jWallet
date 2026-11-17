import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:j_wallet/core/config/app_config.dart';
import 'package:j_wallet/core/crypto/e2e_cipher.dart';

Future<String> node(Map<String, dynamic> input) async {
  final process = await Process.start('node', ['test/fixtures/e2e_server.cjs']);
  process.stdin.write(jsonEncode(input));
  await process.stdin.close();
  final output = process.stdout.transform(utf8.decoder).join();
  final errors = process.stderr.transform(utf8.decoder).join();
  expect(await process.exitCode, 0, reason: await errors);
  return (await output).trim();
}

void main() {
  test('encrypted login interoperates with Node and rejects altered response/status', () async {
    final publicKey = await node({'publicKeyOnly': true});
    final cipher = E2eCipher(
      AppConfig(
        apiBaseUrl: 'http://localhost',
        encKeyId: 'test',
        encPublicKey: publicKey,
      ),
    );
    final body = {'email': 'demo@jstack.co', 'password': 'Demo@123'};
    final request = cipher.seal('POST', '/api/v1/auth/login', body);
    expect(jsonEncode(request.body), isNot(contains('Demo@123')));
    final response = jsonDecode(
      await node({'headers': request.headers, 'body': request.body}),
    ) as Map<String, dynamic>;
    final payload = response['payload'] as String;
    expect(request.openResponse(200, payload)['body'], {'received': body});
    expect(() => request.openResponse(401, payload), throwsA(anything));
    final tampered = base64Decode(payload);
    tampered[15] ^= 1;
    expect(
      () => request.openResponse(200, base64Encode(tampered)),
      throwsA(anything),
    );
    final second = cipher.seal('POST', '/api/v1/auth/login', body);
    expect(
      second.headers['X-Enc-Nonce'],
      isNot(request.headers['X-Enc-Nonce']),
    );
    expect(second.headers['X-Enc-Epk'], isNot(request.headers['X-Enc-Epk']));
  });
}
