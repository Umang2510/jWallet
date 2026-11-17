import 'package:flutter_test/flutter_test.dart';
import 'package:j_wallet/core/crypto/device_keys.dart';
import 'package:j_wallet/core/network/api_client.dart';
import 'package:j_wallet/core/network/api_exception.dart';
import 'package:j_wallet/core/network/authenticated_client.dart';
import 'package:j_wallet/core/storage/secure_store.dart';
import 'package:j_wallet/features/auth/data/auth_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockApi extends Mock implements ApiClient {}

class MockStore extends Mock implements SecureStore {}

class MockAuthenticated extends Mock implements AuthenticatedClient {}

class MockKeys extends Mock implements DeviceKeys {}

void main() {
  late MockApi api;
  late MockStore store;
  late MockAuthenticated authenticated;
  late MockKeys keys;
  late AuthRepository repository;

  Map<String, dynamic> loginBody({
    bool pinSet = true,
    bool biometricEnrolled = false,
  }) => {
    'accessToken': 'access',
    'refreshToken': 'refresh',
    'user': {'id': 'user-1'},
    'security': {'pinSet': pinSet, 'biometricEnrolled': biometricEnrolled},
  };

  void stubLogin(Map<String, dynamic> body) => when(
    () => api.request('POST', '/api/v1/auth/login', body: any(named: 'body')),
  ).thenAnswer((_) async => body);

  setUp(() {
    api = MockApi();
    store = MockStore();
    authenticated = MockAuthenticated();
    keys = MockKeys();
    repository = AuthRepository(api, store, authenticated, keys);
    when(() => store.deviceId()).thenAnswer((_) async => 'device-id');
    when(() => keys.devicePublicKey()).thenAnswer((_) async => 'public-key');
    when(() => keys.biometricAvailable()).thenAnswer((_) async => true);
    when(() => keys.hasBiometricKey(any())).thenAnswer((_) async => false);
    when(() => authenticated.saveLogin(any())).thenAnswer((_) async {});
    when(() => authenticated.clear()).thenAnswer((_) async {});
    when(() => store.clearAll()).thenAnswer((_) async {});
  });

  test('login normalizes only email and binds the device key', () async {
    stubLogin(loginBody());
    await repository.login(email: ' DEMO@JSTACK.CO ', password: ' password ');
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
      'devicePublicKey': 'public-key',
    });
    verify(() => authenticated.saveLogin(any())).called(1);
  });

  test('rejected login never persists credentials', () async {
    when(
      () => api.request('POST', '/api/v1/auth/login', body: any(named: 'body')),
    ).thenThrow(const ApiException('Invalid credentials', statusCode: 401));
    await expectLater(
      repository.login(email: 'a@b.co', password: 'wrong'),
      throwsA(isA<ApiException>()),
    );
    verifyNever(() => authenticated.saveLogin(any()));
  });

  test('a new PIN-less account is sent to PIN setup, not biometrics', () async {
    stubLogin(loginBody(pinSet: false));
    final result = await repository.login(email: 'a@b.co', password: 'pw');
    expect(result.pinSet, isFalse);
    expect(result.offerBiometricSetup, isFalse);
  });

  test('offers biometrics when a PIN exists and none is enrolled here', () async {
    stubLogin(loginBody());
    final result = await repository.login(email: 'a@b.co', password: 'pw');
    expect(result.offerBiometricSetup, isTrue);
  });

  test('does not offer biometrics the device cannot provide', () async {
    stubLogin(loginBody());
    when(() => keys.biometricAvailable()).thenAnswer((_) async => false);
    final result = await repository.login(email: 'a@b.co', password: 'pw');
    expect(result.offerBiometricSetup, isFalse);
  });

  test('treats server enrollment without a local key as not enrolled', () async {
    stubLogin(loginBody(biometricEnrolled: true));
    final result = await repository.login(email: 'a@b.co', password: 'pw');
    expect(result.biometricEnrolled, isFalse);
    expect(result.offerBiometricSetup, isTrue);
  });

  test('keeps biometrics when the server and the device key agree', () async {
    stubLogin(loginBody(biometricEnrolled: true));
    when(() => keys.hasBiometricKey('user-1')).thenAnswer((_) async => true);
    final result = await repository.login(email: 'a@b.co', password: 'pw');
    expect(result.biometricEnrolled, isTrue);
    expect(result.offerBiometricSetup, isFalse);
  });

  group('restoreSession', () {
    setUp(() {
      when(
        () => authenticated.session(),
      ).thenAnswer((_) async => {'accessToken': 'access'});
    });

    test('returns the server-validated security state', () async {
      when(
        () => authenticated.request('GET', '/api/v1/users/profile'),
      ).thenAnswer(
        (_) async => {
          'id': 'user-1',
          'security': {'pinSet': true, 'biometricEnrolled': false},
        },
      );
      final result = await repository.restoreSession();
      expect(result?.pinSet, isTrue);
      expect(result?.offerBiometricSetup, isFalse);
    });

    test('returns null for a rejected session', () async {
      when(
        () => authenticated.request('GET', '/api/v1/users/profile'),
      ).thenThrow(const ApiException('Expired', statusCode: 401));
      expect(await repository.restoreSession(), isNull);
    });

    test('rethrows connectivity failures so the session is kept', () async {
      when(
        () => authenticated.request('GET', '/api/v1/users/profile'),
      ).thenThrow(const ApiException('Offline', notProcessed: true));
      await expectLater(
        repository.restoreSession(),
        throwsA(isA<ApiException>()),
      );
      verifyNever(() => authenticated.clear());
    });
  });

  test('logout clears local tokens even when the server is unreachable', () async {
    when(
      () => authenticated.session(),
    ).thenAnswer((_) async => {'accessToken': 'access'});
    when(
      () => authenticated.request(
        'POST',
        '/api/v1/auth/logout',
        body: any(named: 'body'),
      ),
    ).thenThrow(const ApiException('Offline'));
    await expectLater(repository.logout(), throwsA(isA<ApiException>()));
    verify(() => authenticated.clear()).called(1);
  });

  group('logout (API call, then wipe everything)', () {
    void stubLogoutCall({Object? error}) {
      when(
        () => authenticated.session(),
      ).thenAnswer((_) async => {'accessToken': 'access'});
      final call = when(
        () => authenticated.request(
          'POST',
          '/api/v1/auth/logout',
          body: any(named: 'body'),
        ),
      );
      error == null
          ? call.thenAnswer((_) async => {})
          : call.thenThrow(error);
    }

    test('tells the server, then wipes everything on the phone', () async {
      stubLogoutCall();
      await repository.logout();
      verify(
        () => authenticated.request(
          'POST',
          '/api/v1/auth/logout',
          body: any(named: 'body'),
        ),
      ).called(1);
      verify(() => authenticated.clear()).called(1);
      verify(() => store.clearAll()).called(1);
    });

    test('still wipes the phone when the server cannot be reached', () async {
      stubLogoutCall(
        error: const ApiException('Offline', notProcessed: true),
      );
      await expectLater(repository.logout(), throwsA(isA<ApiException>()));
      verify(() => authenticated.clear()).called(1);
      verify(() => store.clearAll()).called(1);
    });

    test('with no saved session there is nobody to tell', () async {
      when(() => authenticated.session()).thenAnswer((_) async => null);
      await repository.logout();
      verifyNever(
        () => authenticated.request(any(), any(), body: any(named: 'body')),
      );
      verify(() => store.clearAll()).called(1);
    });
  });
}
