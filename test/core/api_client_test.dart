import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:j_wallet/core/config/app_config.dart';
import 'package:j_wallet/core/crypto/e2e_cipher.dart';
import 'package:j_wallet/core/network/api_client.dart';
import 'package:j_wallet/core/network/api_exception.dart';

void main() {
  late Dio dio;
  late ApiClient client;
  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
    client = ApiClient(dio, E2eCipher(AppConfig.fromEnvironment()));
  });
  tearDown(() => dio.close());

  test('never accepts a successful plaintext response', () async {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          expect(request.data, isNot(contains('password')));
          expect(request.headers['X-Encrypted'], '1');
          handler.resolve(
            Response(
              requestOptions: request,
              statusCode: 200,
              data: {
                'body': {'accessToken': 'untrusted'},
              },
            ),
          );
        },
      ),
    );
    await expectLater(
      client.request(
        'POST',
        '/api/v1/auth/login',
        body: {'password': 'secret'},
      ),
      throwsA(
        isA<ApiException>().having(
          (e) => e.message,
          'message',
          contains('verify'),
        ),
      ),
    );
  });

  test('preserves useful pre-encryption API errors', () async {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          handler.resolve(
            Response(
              requestOptions: request,
              statusCode: 400,
              data: {
                'meta': {'message': 'Encryption key is unknown'},
                'body': {'errorCode': 'ENCRYPTION_KEY_UNKNOWN'},
              },
            ),
          );
        },
      ),
    );
    await expectLater(
      client.request('GET', '/api/v1/users/profile'),
      throwsA(
        isA<ApiException>().having(
          (e) => e.code,
          'code',
          'ENCRYPTION_KEY_UNKNOWN',
        ),
      ),
    );
  });

  for (final type in [
    DioExceptionType.connectionTimeout,
    DioExceptionType.connectionError,
  ]) {
    test('maps $type to a retryable user-facing error', () async {
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            handler.reject(DioException(requestOptions: request, type: type));
          },
        ),
      );
      await expectLater(
        client.request('GET', '/api/v1/users/profile'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            contains(
              type == DioExceptionType.connectionTimeout
                  ? 'timed out'
                  : 'connect',
            ),
          ),
        ),
      );
    });
  }
}
