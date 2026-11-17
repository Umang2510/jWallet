import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:j_wallet/core/network/api_exception.dart';
import 'package:j_wallet/features/auth/data/auth_repository.dart';
import 'package:j_wallet/features/auth/view_model/login_cubit.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository repository;
  late LoginCubit cubit;

  setUp(() {
    repository = MockAuthRepository();
    cubit = LoginCubit(repository);
  });
  tearDown(() => cubit.close());

  test('blocks duplicate submissions and forwards the PIN status', () async {
    final pending = Completer<AuthResult>();
    when(
      () => repository.login(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) => pending.future);
    final submission = cubit.submit(
      email: 'demo@jstack.co',
      password: 'Demo@123',
    );
    expect(cubit.state.isSubmitting, isTrue);
    await cubit.submit(email: 'demo@jstack.co', password: 'Demo@123');
    verify(
      () => repository.login(email: 'demo@jstack.co', password: 'Demo@123'),
    ).called(1);
    pending.complete(const AuthResult(pinSet: false));
    await submission;
    expect(cubit.state.status, LoginStatus.success);
    expect(cubit.state.pinSet, isFalse);
  });

  test('shows API errors and permits retry', () async {
    when(
      () => repository.login(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenThrow(
      const ApiException('Invalid email or password', statusCode: 401),
    );
    await cubit.submit(email: 'a@b.co', password: 'wrong');
    expect(cubit.state.message, 'Invalid email or password');
    when(
      () => repository.login(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async => const AuthResult(pinSet: true));
    await cubit.submit(email: 'a@b.co', password: 'right');
    expect(cubit.state.status, LoginStatus.success);
    expect(cubit.state.pinSet, isTrue);
  });

  test('closing during a request does not emit after disposal', () async {
    final pending = Completer<AuthResult>();
    when(
      () => repository.login(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) => pending.future);
    final submission = cubit.submit(email: 'a@b.co', password: 'password');
    await cubit.close();
    pending.complete(const AuthResult(pinSet: true));
    await expectLater(submission, completes);
  });
}
