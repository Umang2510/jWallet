import 'package:flutter_test/flutter_test.dart';
import 'package:j_wallet/app/session/session_cubit.dart';
import 'package:j_wallet/features/app_lock/data/app_lock_repository.dart';
import 'package:j_wallet/features/app_lock/view_model/app_lock_cubit.dart';
import 'package:j_wallet/features/app_lock/view_model/app_lock_setup_cubit.dart';
import 'package:j_wallet/features/auth/data/auth_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockAppLockRepository extends Mock implements AppLockRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockAuthRepository auth;
  late MockAppLockRepository repository;
  late SessionCubit session;
  late AppLockCubit lock;
  late DateTime now;

  /// A signed-in session that finished every setup step.
  Future<void> ready({bool restored = false}) async {
    session.loggedIn(pinSet: true, restored: restored);
    await pumpEventQueue();
  }

  void usePin({bool saved = true, int length = 4}) {
    when(() => repository.method()).thenAnswer((_) async => AppLockMethod.pin);
    when(() => repository.hasPin()).thenAnswer((_) async => saved);
    when(() => repository.pinLength()).thenAnswer((_) async => length);
  }

  void type(String digits) => digits.split('').forEach(lock.digit);

  setUp(() {
    auth = MockAuthRepository();
    when(() => auth.expired).thenAnswer((_) => const Stream.empty());
    when(() => auth.logout()).thenAnswer((_) async {});
    repository = MockAppLockRepository();
    session = SessionCubit(auth);
    now = DateTime(2026, 11, 17, 10);
    when(
      () => repository.method(),
    ).thenAnswer((_) async => AppLockMethod.deviceLock);
    when(() => repository.hasPin()).thenAnswer((_) async => false);
    when(() => repository.pinLength()).thenAnswer((_) async => null);
    lock = AppLockCubit(repository, session, clock: () => now);
  });
  tearDown(() async {
    await lock.close();
    await session.close();
  });

  group('when the lock engages', () {
    test('stays idle while signed out or mid-setup', () async {
      expect(lock.state.status, AppLockStatus.idle);
      session.loggedIn(pinSet: false);
      await pumpEventQueue();
      expect(lock.state.status, AppLockStatus.idle);
    });

    test('a login made just now is not locked again', () async {
      await ready();
      expect(lock.state.status, AppLockStatus.unlocked);
    });

    test('a restored session starts locked', () async {
      await ready(restored: true);
      expect(lock.state.status, AppLockStatus.locked);
      expect(lock.state.method, AppLockMethod.deviceLock);
    });

    test('a phone with no screen lock and no PIN must set one up', () async {
      usePin(saved: false);
      await ready();
      expect(lock.state.status, AppLockStatus.setupRequired);
      expect(lock.state.method, AppLockMethod.pin);
    });

    test('a phone with no screen lock but a PIN starts locked on restore', () async {
      usePin(length: 6);
      await ready(restored: true);
      expect(lock.state.status, AppLockStatus.locked);
      expect(lock.state.pinLength, 6);
    });

    test('goes idle again when the session ends', () async {
      await ready(restored: true);
      await session.logout();
      await pumpEventQueue();
      expect(lock.state.status, AppLockStatus.idle);
    });

    test('finishing the one-time PIN setup opens the app', () async {
      usePin(saved: false);
      await ready();
      lock.setupCompleted();
      expect(lock.state.status, AppLockStatus.unlocked);
    });
  });

  group('unlocking with the phone screen lock', () {
    setUp(() => ready(restored: true));

    test('opens the app when the prompt succeeds', () async {
      when(
        () => repository.authenticateWithDevice(),
      ).thenAnswer((_) async => true);
      await lock.unlockWithDevice();
      expect(lock.state.status, AppLockStatus.unlocked);
    });

    test('stays locked, with a hint, when the prompt is dismissed', () async {
      when(
        () => repository.authenticateWithDevice(),
      ).thenAnswer((_) async => false);
      await lock.unlockWithDevice();
      expect(lock.state.status, AppLockStatus.locked);
      expect(lock.state.message, contains('cancelled'));
      expect(lock.state.busy, isFalse);
    });

    test('stays locked when the system prompt fails', () async {
      when(
        () => repository.authenticateWithDevice(),
      ).thenThrow(Exception('boom'));
      await lock.unlockWithDevice();
      expect(lock.state.status, AppLockStatus.locked);
      expect(lock.state.busy, isFalse);
      expect(lock.state.message, isNotNull);
    });
  });

  group('unlocking with the app lock PIN', () {
    setUp(() async {
      usePin();
      await ready(restored: true);
    });

    test('ignores extra digits and non-digits', () {
      type('13579a');
      expect(lock.state.entered, 4);
    });

    test('asks for the full PIN first', () async {
      type('13');
      await lock.unlockWithPin();
      expect(lock.state.message, contains('4-digit'));
      verifyNever(() => repository.verifyPin(any()));
    });

    test('opens the app with the right PIN', () async {
      when(
        () => repository.verifyPin('1357'),
      ).thenAnswer((_) async => const PinCheck(PinCheckStatus.correct));
      type('1357');
      await lock.unlockWithPin();
      expect(lock.state.status, AppLockStatus.unlocked);
    });

    test('a wrong PIN says how many attempts are left and clears the dots', () async {
      when(() => repository.verifyPin(any())).thenAnswer(
        (_) async => const PinCheck(PinCheckStatus.wrong, attemptsLeft: 3),
      );
      type('1111');
      await lock.unlockWithPin();
      expect(lock.state.status, AppLockStatus.locked);
      expect(lock.state.message, 'Incorrect PIN. 3 attempts left.');
      expect(lock.state.entered, 0);
    });

    test('too many attempts shows the wait', () async {
      when(() => repository.verifyPin(any())).thenAnswer(
        (_) async => const PinCheck(
          PinCheckStatus.locked,
          lockedFor: Duration(minutes: 5),
        ),
      );
      type('1111');
      await lock.unlockWithPin();
      expect(lock.state.message, contains('5 minutes'));
      expect(lock.state.status, AppLockStatus.locked);
    });
  });

  group('coming back from the background', () {
    setUp(() => ready());

    test('locks after 30 seconds away', () async {
      lock.appPaused();
      now = now.add(const Duration(seconds: 31));
      lock.appResumed();
      await pumpEventQueue();
      expect(lock.state.status, AppLockStatus.locked);
    });

    test('a quick app switch does not lock', () async {
      lock.appPaused();
      now = now.add(const Duration(seconds: 10));
      lock.appResumed();
      await pumpEventQueue();
      expect(lock.state.status, AppLockStatus.unlocked);
    });

    test('does nothing while signed out', () async {
      await session.logout();
      await pumpEventQueue();
      lock.appPaused();
      now = now.add(const Duration(minutes: 5));
      lock.appResumed();
      await pumpEventQueue();
      expect(lock.state.status, AppLockStatus.idle);
    });
  });

  group('AppLockSetupCubit', () {
    late AppLockSetupCubit setup;
    setUp(() => setup = AppLockSetupCubit(repository));
    tearDown(() => setup.close());

    void enter(String pin) => pin.split('').forEach(setup.digit);

    test('two entries, then the PIN is saved on the phone', () async {
      when(() => repository.createPin(any())).thenAnswer((_) async {});
      enter('1234');
      await setup.next();
      expect(setup.state.step, AppLockSetupStep.confirm);
      enter('1234');
      await setup.next();
      verify(() => repository.createPin('1234')).called(1);
      expect(setup.state.step, AppLockSetupStep.complete);
    });

    test('a mismatch asks again without saving', () async {
      enter('1357');
      await setup.next();
      enter('1358');
      await setup.next();
      expect(setup.state.message, contains('do not match'));
      verifyNever(() => repository.createPin(any()));
    });

    test('rejects a PIN that is not 4 or 6 digits', () async {
      enter('13');
      await setup.next();
      expect(setup.state.message, 'PIN must be 4 or 6 digits');
      expect(setup.state.step, AppLockSetupStep.create);
    });

    test('a storage failure returns to the start with a message', () async {
      when(() => repository.createPin(any())).thenThrow(Exception('storage'));
      enter('1357');
      await setup.next();
      enter('1357');
      await setup.next();
      expect(setup.state.step, AppLockSetupStep.create);
      expect(setup.state.message, isNotNull);
    });
  });
}
