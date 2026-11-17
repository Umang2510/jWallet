import 'package:flutter_test/flutter_test.dart';
import 'package:j_wallet/core/network/api_client.dart';
import 'package:j_wallet/core/network/api_exception.dart';
import 'package:j_wallet/core/storage/secure_store.dart';
import 'package:j_wallet/features/auth/data/auth_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockApi extends Mock implements ApiClient {}

class MockStore extends Mock implements SecureStore {}

void main() {
  late MockApi api;
  late MockStore store;
  late AuthRepository repository;
  setUp(() {
    api = MockApi();
    store = MockStore();
    repository = AuthRepository(api, store);
    when(() => store.deviceId()).thenAnswer((_) async => 'device-id');
    when(() => store.saveSession(any())).thenAnswer((_) async {});
    when(() => store.clearSession()).thenAnswer((_) async {});
  });

  test('login normalizes only email and securely stores tokens', () async {
    when(
      () => api.request('POST', '/api/v1/auth/login', body: any(named: 'body')),
    ).thenAnswer(
      (_) async => {
        'accessToken': 'access',
        'refreshToken': 'refresh',
        'security': {'pinSet': false},
      },
    );
    final result = await repository.login(
      email: ' DEMO@JSTACK.CO ',
      password: ' password ',
    );
    final body =
        verify(
              () => api.request(
                'POST',
                '/api/v1/auth/login',
                body: captureAny(named: 'body'),
              ),
            ).captured.single
            as Map;
    expect(body, {
      'email': 'demo@jstack.co',
      'password': ' password ',
      'deviceId': 'device-id',
    });
    verify(
      () => store.saveSession({
        'accessToken': 'access',
        'refreshToken': 'refresh',
      }),
    ).called(1);
    expect(result.pinSet, isFalse);
  });

  test('rejected login never persists credentials', () async {
    when(
      () => api.request('POST', '/api/v1/auth/login', body: any(named: 'body')),
    ).thenThrow(const ApiException('Invalid credentials', statusCode: 401));
    await expectLater(
      repository.login(email: 'a@b.co', password: 'wrong'),
      throwsA(isA<ApiException>()),
    );
    verifyNever(() => store.saveSession(any()));
  });

  test('restores only a server-validated session', () async {
    when(() => store.readSession())
        .thenAnswer((_) async => {'accessToken': 'access'});
    when(
      () => api.request('GET', '/api/v1/users/profile', accessToken: 'access'),
    ).thenAnswer(
      (_) async => {
        'security': {'pinSet': true},
      },
    );
    expect((await repository.restoreSession())?.pinSet, isTrue);
  });

  test(
    'clears expired sessions but retains them for connectivity failures',
    () async {
      when(() => store.readSession())
          .thenAnswer((_) async => {'accessToken': 'access'});
      when(
        () =>
            api.request('GET', '/api/v1/users/profile', accessToken: 'access'),
      ).thenThrow(const ApiException('Expired', statusCode: 401));
      expect(await repository.restoreSession(), isNull);
      verify(() => store.clearSession()).called(1);
      when(
        () =>
            api.request('GET', '/api/v1/users/profile', accessToken: 'access'),
      ).thenThrow(const ApiException('Offline'));
      await expectLater(
        repository.restoreSession(),
        throwsA(isA<ApiException>()),
      );
      verifyNever(() => store.clearSession());
    },
  );

  test(
    'logout clears local tokens even when the server is unreachable',
    () async {
      when(() => store.readSession())
          .thenAnswer((_) async => {'accessToken': 'access'});
      when(
        () => api.request(
          'POST',
          '/api/v1/auth/logout',
          body: any(named: 'body'),
          accessToken: 'access',
        ),
      ).thenThrow(const ApiException('Offline'));
      await expectLater(repository.logout(), throwsA(isA<ApiException>()));
      verify(() => store.clearSession()).called(1);
    },
  );
}
