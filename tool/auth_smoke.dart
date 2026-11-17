import 'dart:io';

import 'package:dio/dio.dart';
import 'package:j_wallet/core/config/app_config.dart';
import 'package:j_wallet/core/crypto/e2e_cipher.dart';
import 'package:j_wallet/core/network/api_client.dart';
import 'package:j_wallet/core/network/api_exception.dart';
import 'package:uuid/uuid.dart';

/// Optional integration check against the configured backend.
Future<void> main() async {
  final config = AppConfig.fromEnvironment();
  final dio = Dio(
    BaseOptions(
      baseUrl: config.apiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 60),
    ),
  );
  final client = ApiClient(dio, E2eCipher(config));
  try {
    final login = await client.request(
      'POST',
      '/api/v1/auth/login',
      body: {
        'email': 'demo@jstack.co',
        'password': 'Demo@123',
        'deviceId': const Uuid().v4(),
      },
    );
    final token = login['accessToken'] as String;
    try {
      final profile = await client.request(
        'GET',
        '/api/v1/users/profile',
        accessToken: token,
      );
      if (profile['email'] != 'demo@jstack.co') {
        throw StateError('Unexpected profile');
      }
      stdout.writeln('Encrypted login and authenticated profile succeeded.');
    } finally {
      await client.request(
        'POST',
        '/api/v1/auth/logout',
        body: {},
        accessToken: token,
      );
      stdout.writeln('Test session revoked.');
    }
  } on ApiException catch (error) {
    stderr.writeln(error.message);
    exitCode = 1;
  } finally {
    dio.close();
  }
}
