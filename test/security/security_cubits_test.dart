import 'package:flutter_test/flutter_test.dart';
import 'package:j_wallet/core/crypto/device_keys.dart';
import 'package:j_wallet/core/network/api_exception.dart';
import 'package:j_wallet/features/security/data/security_repository.dart';
import 'package:j_wallet/features/security/view_model/biometric_setup_cubit.dart';
import 'package:j_wallet/features/security/view_model/pin_setup_cubit.dart';
import 'package:mocktail/mocktail.dart';

class MockSecurityRepository extends Mock implements SecurityRepository {}

void main() {
  late MockSecurityRepository repository;
  setUp(() => repository = MockSecurityRepository());

  group('PinSetupCubit', () {
    late PinSetupCubit cubit;
    setUp(() {
      when(() => repository.biometricAvailable()).thenAnswer((_) async => false);
      cubit = PinSetupCubit(repository);
    });
    tearDown(() => cubit.close());

    void type(String pin) => pin.split('').forEach(cubit.digit);

    test('has no pattern rules: 1234 and 0000 are fine', () async {
      for (final pin in ['1234', '0000', '1111']) {
        cubit.restart();
        type(pin);
        await cubit.next();
        expect(cubit.state.step, PinStep.confirm, reason: pin);
        expect(cubit.state.validation, isNull, reason: pin);
      }
    });

    test('rejects a short PIN', () async {
      type('13');
      await cubit.next();
      expect(cubit.state.validation, 'PIN must be 4 or 6 digits');
    });

    test('ignores digits beyond the chosen length', () {
      type('135792');
      expect(cubit.state.entered, 4);
      cubit.setLength(6);
      type('1357924');
      expect(cubit.state.entered, 6);
    });

    test('a mismatching confirmation asks again without a request', () async {
      type('1357');
      await cubit.next();
      expect(cubit.state.step, PinStep.confirm);
      type('1358');
      await cubit.next();
      expect(cubit.state.validation, contains('do not match'));
      verifyNever(() => repository.setPin(any()));
    });

    test('a confirmed PIN is sent once and completes', () async {
      when(() => repository.setPin(any())).thenAnswer((_) async {});
      type('1357');
      await cubit.next();
      type('1357');
      await cubit.next();
      verify(() => repository.setPin('1357')).called(1);
      expect(cubit.state.step, PinStep.complete);
    });

    test('shows the API message and restarts when the server refuses', () async {
      when(() => repository.setPin(any())).thenThrow(
        const ApiException(
          'PIN could not be saved.',
          statusCode: 400,
          code: 'VALIDATION_ERROR',
        ),
      );
      type('1357');
      await cubit.next();
      type('1357');
      await cubit.next();
      expect(cubit.state.message, 'PIN could not be saved.');
      expect(cubit.state.step, PinStep.create);
      expect(cubit.state.entered, 0);
    });

    test('PIN entered exactly twice, then biometrics reuse it (no 3rd prompt)', () async {
      when(() => repository.setPin(any())).thenAnswer((_) async {});
      when(() => repository.biometricAvailable()).thenAnswer((_) async => true);
      when(() => repository.enrollBiometrics(any())).thenAnswer((_) async {});
      type('1357');
      await cubit.next();
      type('1357');
      await cubit.next();
      expect(cubit.state.step, PinStep.biometric);
      // The fingerprint step takes no digits.
      cubit.digit('9');
      expect(cubit.state.entered, 0);
      await cubit.enableBiometrics();
      verify(() => repository.enrollBiometrics('1357')).called(1);
      expect(cubit.state.step, PinStep.complete);
      expect(cubit.state.biometricEnrolled, isTrue);
    });

    test('skipping biometrics finishes without enrolling', () async {
      when(() => repository.setPin(any())).thenAnswer((_) async {});
      when(() => repository.biometricAvailable()).thenAnswer((_) async => true);
      type('1357');
      await cubit.next();
      type('1357');
      await cubit.next();
      cubit.skipBiometrics();
      expect(cubit.state.step, PinStep.complete);
      expect(cubit.state.biometricEnrolled, isFalse);
      verifyNever(() => repository.enrollBiometrics(any()));
    });

    test('a failed enrollment shows the API message and can be retried', () async {
      when(() => repository.setPin(any())).thenAnswer((_) async {});
      when(() => repository.biometricAvailable()).thenAnswer((_) async => true);
      when(() => repository.enrollBiometrics(any())).thenThrow(
        const ApiException(
          'Biometric enrollment failed.',
          statusCode: 400,
          code: 'VALIDATION_ERROR',
        ),
      );
      type('1357');
      await cubit.next();
      type('1357');
      await cubit.next();
      await cubit.enableBiometrics();
      expect(cubit.state.step, PinStep.biometric);
      expect(cubit.state.message, 'Biometric enrollment failed.');
      when(() => repository.enrollBiometrics(any())).thenAnswer((_) async {});
      await cubit.enableBiometrics();
      expect(cubit.state.step, PinStep.complete);
    });

    test('leaving the app does not undo a saved PIN', () async {
      when(() => repository.setPin(any())).thenAnswer((_) async {});
      when(() => repository.biometricAvailable()).thenAnswer((_) async => true);
      type('1357');
      await cubit.next();
      type('1357');
      await cubit.next();
      cubit.restart();
      expect(cubit.state.step, PinStep.biometric);
    });

    test('reports an expired login so the screen can sign out', () async {
      when(() => repository.setPin(any())).thenThrow(
        const ApiException(
          'For your security, please log in again to set your PIN.',
          statusCode: 403,
          code: 'REAUTH_REQUIRED',
        ),
      );
      type('1357');
      await cubit.next();
      type('1357');
      await cubit.next();
      expect(cubit.state.code, 'REAUTH_REQUIRED');
    });

    test('an already-set PIN moves on instead of trapping the user', () async {
      when(() => repository.setPin(any())).thenThrow(
        const ApiException(
          'A transaction PIN is already set.',
          statusCode: 409,
          code: 'PIN_ALREADY_SET',
        ),
      );
      type('1357');
      await cubit.next();
      type('1357');
      await cubit.next();
      expect(cubit.state.step, PinStep.complete);
    });
  });

  group('BiometricSetupCubit', () {
    late BiometricSetupCubit cubit;
    setUp(() {
      when(() => repository.biometricAvailable()).thenAnswer((_) async => true);
      cubit = BiometricSetupCubit(repository);
    });
    tearDown(() => cubit.close());

    Future<void> ready(String pin) async {
      await cubit.checkAvailability();
      pin.split('').forEach(cubit.digit);
    }

    test('reports devices without usable biometrics', () async {
      when(() => repository.biometricAvailable()).thenAnswer((_) async => false);
      await cubit.checkAvailability();
      expect(cubit.state.available, isFalse);
      expect(cubit.state.checking, isFalse);
    });

    test('requires a valid PIN before touching the keystore', () async {
      await ready('12');
      await cubit.enroll();
      expect(cubit.state.validation, isNotNull);
      verifyNever(() => repository.enrollBiometrics(any()));
    });

    test('enrolls with the PIN and completes', () async {
      when(() => repository.enrollBiometrics(any())).thenAnswer((_) async {});
      await ready('1357');
      await cubit.enroll();
      verify(() => repository.enrollBiometrics('1357')).called(1);
      expect(cubit.state.complete, isTrue);
    });

    test('shows the API message for a wrong PIN and clears the entry', () async {
      when(() => repository.enrollBiometrics(any())).thenThrow(
        const ApiException(
          'Incorrect PIN. 2 attempts left.',
          statusCode: 403,
          code: 'INVALID_PIN',
        ),
      );
      await ready('1357');
      await cubit.enroll();
      expect(cubit.state.message, 'Incorrect PIN. 2 attempts left.');
      expect(cubit.state.entered, 0);
      expect(cubit.state.locked, isFalse);
    });

    test('a locked PIN disables further attempts', () async {
      when(() => repository.enrollBiometrics(any())).thenThrow(
        const ApiException(
          'PIN is locked for 24 hours.',
          statusCode: 423,
          code: 'PIN_LOCKED',
        ),
      );
      await ready('1357');
      await cubit.enroll();
      expect(cubit.state.locked, isTrue);
    });

    test('cancelling the system prompt is a calm retryable message', () async {
      when(() => repository.enrollBiometrics(any())).thenThrow(
        const DeviceSecurityException('Cancelled', 'BIOMETRIC_CANCELLED'),
      );
      await ready('1357');
      await cubit.enroll();
      expect(cubit.state.message, contains('cancelled'));
      expect(cubit.state.complete, isFalse);
    });
  });
}
