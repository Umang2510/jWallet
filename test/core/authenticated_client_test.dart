import 'package:flutter_test/flutter_test.dart';
import 'package:j_wallet/core/crypto/device_keys.dart';
import 'package:j_wallet/core/network/api_client.dart';
import 'package:j_wallet/core/network/api_exception.dart';
import 'package:j_wallet/core/network/authenticated_client.dart';
import 'package:j_wallet/core/storage/secure_store.dart';
import 'package:mocktail/mocktail.dart';

class MockApi extends Mock implements ApiClient {}

class MockStore extends Mock implements SecureStore {}

class MockKeys extends Mock implements DeviceKeys {}

const _refreshPath = '/api/v1/auth/refresh';

const _tokenExpired = ApiException(
  'Access token has expired',
  statusCode: 401,
  code: 'TOKEN_EXPIRED',
);

void main() {
  late MockApi api;
  late MockStore store;
  late MockKeys keys;
  late AuthenticatedClient client;
  late List<ApiException> expired;
  late int refreshCalls;
  late Future<Map<String, dynamic>> Function() onRefresh;

  /// "old" is an expired access token; anything else is accepted.
  void stubApi() {
    when(
      () => api.request(
        any(),
        any(),
        body: any(named: 'body'),
        accessToken: any(named: 'accessToken'),
      ),
    ).thenAnswer((invocation) async {
      final path = invocation.positionalArguments[1] as String;
      final token = invocation.namedArguments[#accessToken] as String?;
      if (path == _refreshPath) {
        refreshCalls++;
        return onRefresh();
      }
      if (token == 'old') throw _tokenExpired;
      return {'ok': true, 'token': token};
    });
  }

  Future<Map<String, dynamic>> rotated() async {
    await Future<void>.delayed(const Duration(milliseconds: 10));
    return {'accessToken': 'new', 'refreshToken': 'rt-new'};
  }

  setUp(() async {
    api = MockApi();
    store = MockStore();
    keys = MockKeys();
    refreshCalls = 0;
    onRefresh = rotated;
    when(() => store.deviceId()).thenAnswer((_) async => 'device-id');
    when(() => store.saveSession(any())).thenAnswer((_) async {});
    when(() => store.clearSession()).thenAnswer((_) async {});
    when(() => keys.signRefresh(any())).thenAnswer((_) async => 'signature');
    stubApi();
    client = AuthenticatedClient(api, store, keys);
    expired = [];
    client.expired.listen(expired.add);
    await client.saveLogin({
      'accessToken': 'old',
      'refreshToken': 'rt-old',
      'user': {'id': 'user-1'},
    });
  });
  tearDown(() => client.dispose());

  test('sends the access token and does not refresh while it is valid', () async {
    await client.saveLogin({
      'accessToken': 'fresh',
      'refreshToken': 'rt',
      'user': {'id': 'user-1'},
    });
    final response = await client.request('GET', '/api/v1/users/profile');
    expect(response['token'], 'fresh');
    expect(refreshCalls, 0);
  });

  test('refreshes once on TOKEN_EXPIRED, retries, and stores the new pair', () async {
    final response = await client.request('GET', '/api/v1/users/profile');
    expect(response['token'], 'new');
    expect(refreshCalls, 1);
    final session = await client.session();
    expect(session?['accessToken'], 'new');
    expect(session?['refreshToken'], 'rt-new');
    verify(
      () => store.saveSession({
        'accessToken': 'new',
        'refreshToken': 'rt-new',
        'userId': 'user-1',
      }),
    ).called(1);
  });

  test('signs the refresh with the device key and binds the device', () async {
    await client.request('GET', '/api/v1/users/profile');
    final payload =
        verify(() => keys.signRefresh(captureAny())).captured.single as String;
    expect(payload, startsWith('JWALLET-REFRESH\nrt-old\n'));
    final body =
        verify(
              () => api.request(
                'POST',
                _refreshPath,
                body: captureAny(named: 'body'),
              ),
            ).captured.single
            as Map;
    expect(body['refreshToken'], 'rt-old');
    expect(body['deviceId'], 'device-id');
    expect(body['signature'], 'signature');
    expect(body['timestamp'], isA<int>());
  });

  test('concurrent expired requests share one refresh', () async {
    final results = await Future.wait([
      client.request('GET', '/api/v1/wallet/balance'),
      client.request('GET', '/api/v1/transactions'),
      client.request('GET', '/api/v1/users/profile'),
    ]);
    expect(results.map((r) => r['token']), everyElement('new'));
    expect(refreshCalls, 1);
  });

  test('a rejected refresh ends the session and reports why', () async {
    onRefresh = () async => throw const ApiException(
      'Session has expired. Please log in again.',
      statusCode: 401,
      code: 'REFRESH_TOKEN_EXPIRED',
    );
    await expectLater(
      client.request('GET', '/api/v1/users/profile'),
      throwsA(isA<ApiException>()),
    );
    expect(await client.session(), isNull);
    verify(() => store.clearSession()).called(1);
    expect(expired.single.message, 'Session has expired. Please log in again.');
  });

  test('reuse of a refresh token ends the session', () async {
    onRefresh = () async => throw const ApiException(
      'This refresh token was already used.',
      statusCode: 401,
      code: 'REFRESH_TOKEN_REUSED',
    );
    await expectLater(
      client.request('GET', '/api/v1/users/profile'),
      throwsA(isA<ApiException>()),
    );
    expect(await client.session(), isNull);
  });

  test('going offline during refresh keeps the session for a retry', () async {
    onRefresh = () async => throw const ApiException(
      'Unable to connect. Check your internet connection and try again.',
      notProcessed: true,
    );
    await expectLater(
      client.request('GET', '/api/v1/users/profile'),
      throwsA(isA<ApiException>()),
    );
    expect(await client.session(), isNotNull);
    verifyNever(() => store.clearSession());
    expect(expired, isEmpty);

    // The old refresh token was never consumed, so the next try succeeds.
    onRefresh = rotated;
    final response = await client.request('GET', '/api/v1/users/profile');
    expect(response['token'], 'new');
  });

  test('an uncertain refresh outcome ends the session (token may be spent)', () async {
    onRefresh = () async =>
        throw const ApiException('The request timed out. Please try again.');
    await expectLater(
      client.request('GET', '/api/v1/users/profile'),
      throwsA(isA<ApiException>()),
    );
    expect(await client.session(), isNull);
    expect(expired, hasLength(1));
  });

  test('a revoked or invalid access token ends the session', () async {
    when(
      () => api.request(
        'GET',
        '/api/v1/users/profile',
        body: any(named: 'body'),
        accessToken: any(named: 'accessToken'),
      ),
    ).thenThrow(
      const ApiException(
        'Session has ended. Please log in again.',
        statusCode: 401,
        code: 'SESSION_REVOKED',
      ),
    );
    await expectLater(
      client.request('GET', '/api/v1/users/profile'),
      throwsA(isA<ApiException>()),
    );
    expect(await client.session(), isNull);
    expect(refreshCalls, 0);
    expect(expired.single.code, 'SESSION_REVOKED');
  });

  test('a wrong PIN (403) is not treated as an expired session', () async {
    when(
      () => api.request(
        'POST',
        '/api/v1/devices/biometric',
        body: any(named: 'body'),
        accessToken: any(named: 'accessToken'),
      ),
    ).thenThrow(
      const ApiException(
        'Incorrect PIN. 2 attempts left.',
        statusCode: 403,
        code: 'INVALID_PIN',
      ),
    );
    await client.saveLogin({
      'accessToken': 'fresh',
      'refreshToken': 'rt',
      'user': {'id': 'user-1'},
    });
    await expectLater(
      client.request('POST', '/api/v1/devices/biometric', body: {'pin': '1'}),
      throwsA(
        isA<ApiException>().having(
          (e) => e.message,
          'message',
          'Incorrect PIN. 2 attempts left.',
        ),
      ),
    );
    expect(await client.session(), isNotNull);
    expect(refreshCalls, 0);
    expect(expired, isEmpty);
  });

  test('a device key failure ends the session with a clear message', () async {
    when(
      () => keys.signRefresh(any()),
    ).thenThrow(const DeviceSecurityException('Key is missing.', 'KEY_MISSING'));
    await expectLater(
      client.request('GET', '/api/v1/users/profile'),
      throwsA(isA<ApiException>()),
    );
    expect(await client.session(), isNull);
    expect(expired.single.message, contains('Please sign in again'));
  });

  test('requests without a session fail without touching the network', () async {
    await client.clear();
    await expectLater(
      client.request('GET', '/api/v1/users/profile'),
      throwsA(
        isA<ApiException>().having((e) => e.statusCode, 'statusCode', 401),
      ),
    );
    verifyNever(
      () => api.request(
        any(),
        any(),
        body: any(named: 'body'),
        accessToken: any(named: 'accessToken'),
      ),
    );
  });
}
