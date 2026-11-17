import 'package:flutter_test/flutter_test.dart';
import 'package:j_wallet/core/storage/secure_store.dart';
import 'package:j_wallet/features/app_lock/data/app_lock_repository.dart';
import 'package:local_auth/local_auth.dart';
import 'package:mocktail/mocktail.dart';

class MockStore extends Mock implements SecureStore {}

class MockAuth extends Mock implements LocalAuthentication {}

void main() {
  late MockStore store;
  late MockAuth auth;
  late AppLockRepository repository;
  late DateTime now;
  Map<String, dynamic>? saved;

  setUp(() {
    store = MockStore();
    auth = MockAuth();
    now = DateTime(2026, 11, 17, 10);
    saved = null;
    when(() => store.saveAppLock(any())).thenAnswer((invocation) async {
      saved = Map<String, dynamic>.of(
        invocation.positionalArguments.first as Map<String, dynamic>,
      );
    });
    when(() => store.readAppLock()).thenAnswer((_) async => saved);
    repository = AppLockRepository(store, auth, clock: () => now);
  });

  group('method', () {
    test('uses the phone screen lock when there is one', () async {
      when(() => auth.isDeviceSupported()).thenAnswer((_) async => true);
      expect(await repository.method(), AppLockMethod.deviceLock);
    });

    test('falls back to its own PIN when the phone has no screen lock', () async {
      when(() => auth.isDeviceSupported()).thenAnswer((_) async => false);
      expect(await repository.method(), AppLockMethod.pin);
    });

    test('treats a platform failure as having no screen lock', () async {
      when(() => auth.isDeviceSupported()).thenThrow(Exception('no plugin'));
      expect(await repository.method(), AppLockMethod.pin);
    });
  });

  group('PIN', () {
    test('stores only a salted hash, never the PIN', () async {
      await repository.createPin('1357');
      expect(saved.toString(), isNot(contains('1357')));
      expect(saved!['length'], 4);
      expect(await repository.hasPin(), isTrue);
      expect(await repository.pinLength(), 4);
    });

    test('same PIN, different salt, different hash', () async {
      await repository.createPin('1357');
      final first = saved!['hash'];
      await repository.createPin('1357');
      expect(saved!['hash'], isNot(first));
    });

    test('accepts the right PIN and rejects a wrong one', () async {
      await repository.createPin('258014');
      expect(
        (await repository.verifyPin('258014')).status,
        PinCheckStatus.correct,
      );
      final wrong = await repository.verifyPin('258015');
      expect(wrong.status, PinCheckStatus.wrong);
      expect(wrong.attemptsLeft, 4);
    });

    test('a correct PIN resets the failure counter', () async {
      await repository.createPin('1357');
      await repository.verifyPin('0000');
      await repository.verifyPin('0000');
      await repository.verifyPin('1357');
      expect((await repository.verifyPin('0000')).attemptsLeft, 4);
    });

    test('locks for 5 minutes after 5 wrong attempts, then recovers', () async {
      await repository.createPin('1357');
      for (var i = 0; i < 4; i++) {
        expect((await repository.verifyPin('0000')).status, PinCheckStatus.wrong);
      }
      final fifth = await repository.verifyPin('0000');
      expect(fifth.status, PinCheckStatus.locked);
      expect(fifth.lockedFor, AppLockRepository.lockDuration);

      // Even the right PIN is refused while locked.
      final during = await repository.verifyPin('1357');
      expect(during.status, PinCheckStatus.locked);

      now = now.add(const Duration(minutes: 5, seconds: 1));
      expect(
        (await repository.verifyPin('1357')).status,
        PinCheckStatus.correct,
      );
    });

    test('reports when no PIN exists', () async {
      expect((await repository.verifyPin('1357')).status, PinCheckStatus.notSet);
      expect(await repository.hasPin(), isFalse);
    });
  });
}
