import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:j_wallet/app/session/session_cubit.dart';
import 'package:j_wallet/app/session/session_state.dart';
import 'package:j_wallet/core/network/api_exception.dart';
import 'package:j_wallet/features/auth/data/auth_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  // Sign-out notices post a snackbar callback, which needs the binding.
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockAuthRepository repository;
  late StreamController<ApiException> expired;
  late SessionCubit cubit;

  setUp(() {
    repository = MockAuthRepository();
    expired = StreamController<ApiException>.broadcast(sync: true);
    when(() => repository.expired).thenAnswer((_) => expired.stream);
    when(() => repository.clearSession()).thenAnswer((_) async {});
    when(() => repository.logout()).thenAnswer((_) async {});
    cubit = SessionCubit(repository);
  });
  tearDown(() async {
    await cubit.close();
    await expired.close();
  });

  test('a restored session keeps its PIN and biometric state', () async {
    when(() => repository.restoreSession()).thenAnswer(
      (_) async => const AuthResult(pinSet: true, biometricEnrolled: true),
    );
    await cubit.start();
    expect(cubit.state.isAuthenticated, isTrue);
    expect(cubit.state.pinSet, isTrue);
    expect(cubit.state.biometricEnrolled, isTrue);
    expect(cubit.state.biometricSetupPending, isFalse);
    expect(cubit.state.restored, isTrue);
  });

  test('no saved session goes to login', () async {
    when(() => repository.restoreSession()).thenAnswer((_) async => null);
    await cubit.start();
    expect(cubit.state.status, SessionStatus.unauthenticated);
  });

  test('a failed restore never strands the splash screen', () async {
    when(
      () => repository.restoreSession(),
    ).thenThrow(const ApiException('Offline', notProcessed: true));
    await cubit.start();
    expect(cubit.state.status, SessionStatus.unauthenticated);
  });

  test('PIN comes before biometrics, even if biometrics are offered', () {
    cubit.loggedIn(pinSet: false, offerBiometricSetup: true);
    expect(cubit.state.pinSet, isFalse);
    expect(cubit.state.biometricSetupPending, isFalse);
  });

  test('login with a PIN can offer biometric setup', () {
    cubit.loggedIn(pinSet: true, offerBiometricSetup: true);
    expect(cubit.state.biometricSetupPending, isTrue);
    cubit.biometricSetupFinished(enrolled: true);
    expect(cubit.state.biometricSetupPending, isFalse);
    expect(cubit.state.biometricEnrolled, isTrue);
  });

  test('creating the PIN finishes setup (biometrics were offered there)', () {
    cubit.loggedIn(pinSet: false);
    cubit.pinCreated(biometricEnrolled: true);
    expect(cubit.state.isReady, isTrue);
    expect(cubit.state.biometricSetupPending, isFalse);
    expect(cubit.state.biometricEnrolled, isTrue);
    expect(cubit.state.restored, isFalse);
  });

  test('only a restored session asks for the app lock', () async {
    when(() => repository.restoreSession())
        .thenAnswer((_) async => const AuthResult(pinSet: true));
    await cubit.start();
    expect(cubit.state.restored, isTrue);
    cubit.loggedIn(pinSet: true);
    expect(cubit.state.restored, isFalse);
  });

  test('an expired session returns the user to login', () {
    cubit.loggedIn(pinSet: true);
    expired.add(const ApiException('Session has expired.', statusCode: 401));
    expect(cubit.state.status, SessionStatus.unauthenticated);
  });

  test('requireSignIn clears saved tokens and signs out', () async {
    cubit.loggedIn(pinSet: false);
    await cubit.requireSignIn('Please log in again.');
    verify(() => repository.clearSession()).called(1);
    expect(cubit.state.status, SessionStatus.unauthenticated);
  });

  test('logout signs out even when the server is unreachable', () async {
    when(
      () => repository.logout(),
    ).thenThrow(const ApiException('Offline', notProcessed: true));
    cubit.loggedIn(pinSet: true);
    await cubit.logout();
    expect(cubit.state.status, SessionStatus.unauthenticated);
  });
}
