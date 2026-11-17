import 'package:flutter_test/flutter_test.dart';
import 'package:j_wallet/core/crypto/device_keys.dart';
import 'package:j_wallet/core/events/wallet_events.dart';
import 'package:j_wallet/core/network/api_exception.dart';
import 'package:j_wallet/core/network/authenticated_client.dart';
import 'package:j_wallet/features/transfer/data/amount_input.dart';
import 'package:j_wallet/features/transfer/data/recipient.dart';
import 'package:j_wallet/features/transfer/data/transfer_models.dart';
import 'package:j_wallet/features/transfer/data/transfer_repository.dart';
import 'package:j_wallet/features/transfer/view_model/send_money_cubit.dart';
import 'package:j_wallet/features/transfer/view_model/transfer_cubit.dart';
import 'package:mocktail/mocktail.dart';

import 'transfer_fixtures.dart';

class MockClient extends Mock implements AuthenticatedClient {}

class MockKeys extends Mock implements DeviceKeys {}

class MockTransferRepository extends Mock implements TransferRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue(draft);
    registerFallbackValue(challenge());
    registerFallbackValue(const PinApproval('1357'));
  });

  group('AmountInput', () {
    AmountInput type(String keys) =>
        keys.split('').fold(const AmountInput(), (a, k) => a.press(k));

    test('builds an amount digit by digit', () {
      expect(type('1500').value, 1500);
      expect(type('1500').wholePart, '1,500');
      expect(type('1500').fractionPart, '00');
    });

    test('uses Indian digit grouping', () {
      expect(type('100000').wholePart, '1,00,000');
      expect(type('25450').wholePart, '25,450');
    });

    test('allows one decimal point and two decimals only', () {
      expect(type('12.345').text, '12.34');
      expect(type('1.2.3').text, '1.23');
      expect(type('.5').text, '0.5');
      expect(type('.5').value, 0.5);
      expect(type('12.5').fractionPart, '50');
    });

    test('no leading zeros', () {
      expect(type('007').text, '7');
      expect(type('0').text, '0');
      expect(type('00').text, '0');
    });

    test('ignores a digit that would pass the per-transfer limit', () {
      expect(type('100000').value, 100000);
      expect(type('1000000').text, '100000');
      expect(type('100000.5').value, 100000);
    });

    test('backspace and ignoring junk', () {
      expect(type('125').backspace().text, '12');
      expect(const AmountInput().backspace().text, '');
      expect(type('1a2').text, '12');
    });

    test('chips add or set, never past the limit', () {
      expect(const AmountInput().plus(500).value, 500);
      expect(type('600').plus(500).value, 1100);
      expect(type('99000').plus(2000).value, 100000);
      expect(AmountInput.of(1500).text, '1500');
      expect(AmountInput.of(25450.75).text, '25450.75');
      expect(AmountInput.of(0).isEmpty, isTrue);
    });
  });

  group('Recipient', () {
    test('custom recipient tidies the name and derives a UPI id', () {
      final r = Recipient.custom(name: '  Asha   Rao ', mobile: '9812345678');
      expect(r.name, 'Asha Rao');
      expect(r.upiId, '9812345678@jwallet');
      expect(r.displayMobile, '+91 98123 45678');
      expect(r.saved, isFalse);
    });

    test('a saved contact is marked saved', () {
      expect(rahul.saved, isTrue);
      expect(rahul.initials, 'RS');
      expect(rahul.displayMobile, '+91 98765 43210');
    });
  });

  group('TransferDraft', () {
    test('sends exactly the fields the server hashes', () {
      expect(draft.toBody(), {
        'beneficiaryName': 'Rahul Sharma',
        'mobileNumber': '9876543210',
        'amount': 1500.0,
        'remarks': 'Dinner split & groceries',
      });
    });

    test('leaves out an empty note', () {
      final plain = TransferDraft(recipient: rahul, amount: 10, remarks: '  ');
      expect(plain.toBody().containsKey('remarks'), isFalse);
    });
  });

  group('TransferRepository', () {
    late MockClient client;
    late MockKeys keys;
    late TransferRepository repository;
    setUp(() {
      client = MockClient();
      keys = MockKeys();
      repository = TransferRepository(client, keys, WalletEvents());
      when(() => client.session()).thenAnswer((_) async => {'userId': 'USR1'});
    });

    test('asks for a challenge with the draft', () async {
      when(
        () => client.request(
          'POST',
          '/api/v1/transactions/transfer/challenge',
          body: any(named: 'body'),
        ),
      ).thenAnswer((_) async => challengeJson(biometric: true));
      final c = await repository.createChallenge(draft);
      expect(c.challengeId, 'c-1');
      expect(c.biometricOffered, isTrue);
      expect(c.maskedMobile, 'XXXXXX3210');
    });

    test('sends the transfer with the idempotency key and approval', () async {
      when(
        () => client.request(
          'POST',
          '/api/v1/transactions/transfer',
          body: any(named: 'body'),
          headers: any(named: 'headers'),
        ),
      ).thenAnswer((_) async => transferJson());
      final result = await repository.transfer(
        draft: draft,
        challenge: challenge(id: 'c-1'),
        approval: const PinApproval('1357'),
        idempotencyKey: 'key-1234567890',
      );
      expect(result.transactionId, 'TXN20261117K7Q2MX');
      final captured = verify(
        () => client.request(
          'POST',
          '/api/v1/transactions/transfer',
          body: captureAny(named: 'body'),
          headers: captureAny(named: 'headers'),
        ),
      ).captured;
      expect(captured[1], {'Idempotency-Key': 'key-1234567890'});
      expect(captured[0], {
        ...draft.toBody(),
        'challengeId': 'c-1',
        'approval': {'method': 'PIN', 'pin': '1357'},
      });
    });

    test('an unreadable success answer warns not to retry blindly', () async {
      when(
        () => client.request(
          'POST',
          '/api/v1/transactions/transfer',
          body: any(named: 'body'),
          headers: any(named: 'headers'),
        ),
      ).thenAnswer((_) async => {'transactionId': 5});
      await expectLater(
        repository.transfer(
          draft: draft,
          challenge: challenge(),
          approval: const PinApproval('1357'),
          idempotencyKey: 'key-1234567890',
        ),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            contains('Check your Activity'),
          ),
        ),
      );
    });

    test('biometrics need both the server offer and the phone key', () async {
      when(() => keys.hasBiometricKey('USR1')).thenAnswer((_) async => true);
      expect(
        await repository.canApproveWithBiometrics(challenge(biometric: true)),
        isTrue,
      );
      expect(
        await repository.canApproveWithBiometrics(challenge(biometric: false)),
        isFalse,
      );
      when(() => keys.hasBiometricKey('USR1')).thenAnswer((_) async => false);
      expect(
        await repository.canApproveWithBiometrics(challenge(biometric: true)),
        isFalse,
      );
    });

    test('signs the server payload with the biometric key', () async {
      when(
        () => keys.signBiometric('USR1', any()),
      ).thenAnswer((_) async => 'c2lnbmF0dXJl');
      final approval = await repository.approveWithBiometrics(
        challenge(id: 'c-9'),
      );
      expect(approval.toJson(), {
        'method': 'BIOMETRIC',
        'signature': 'c2lnbmF0dXJl',
      });
      verify(
        () => keys.signBiometric('USR1', any(that: contains('c-9'))),
      ).called(1);
    });
  });

  group('SendMoneyCubit', () {
    late MockTransferRepository repository;
    late SendMoneyCubit cubit;
    setUp(() {
      repository = MockTransferRepository();
      when(() => repository.availableBalance()).thenAnswer((_) async => 5000);
      cubit = SendMoneyCubit(repository, recipient: rahul);
    });
    tearDown(() => cubit.close());

    test('cannot review before the balance is known', () {
      cubit.set(100);
      expect(cubit.state.canReview, isFalse);
    });

    test('a valid amount and recipient can be reviewed', () async {
      await cubit.load();
      cubit.set(1500);
      cubit.setRemarks('  rent ');
      expect(cubit.state.canReview, isTrue);
      expect(cubit.state.draft!.amount, 1500);
      expect(cubit.state.draft!.remarks, 'rent');
      expect(cubit.state.draft!.recipient, rahul);
    });

    test('zero, empty and no recipient cannot be reviewed', () async {
      await cubit.load();
      expect(cubit.state.canReview, isFalse);
      cubit.press('0');
      expect(cubit.state.canReview, isFalse);
      final bare = SendMoneyCubit(repository);
      await bare.load();
      bare.set(100);
      expect(bare.state.canReview, isFalse);
      await bare.close();
    });

    test('more than the balance is refused with an inline hint', () async {
      await cubit.load();
      cubit.set(5000.5);
      expect(cubit.state.validation, 'Exceeds your balance');
      expect(cubit.state.canReview, isFalse);
      cubit.set(5000);
      expect(cubit.state.validation, isNull);
    });

    test('Max is the balance, capped at the per-transfer limit', () async {
      await cubit.load();
      cubit.max();
      expect(cubit.state.amount.value, 5000);
      when(
        () => repository.availableBalance(),
      ).thenAnswer((_) async => 250000.75);
      await cubit.load();
      cubit.max();
      expect(cubit.state.amount.value, 100000);
    });

    test('a balance failure shows the API message but does not block', () async {
      when(() => repository.availableBalance()).thenThrow(
        const ApiException('Wallet not found', statusCode: 404),
      );
      await cubit.load();
      expect(cubit.state.message, 'Wallet not found');
      expect(cubit.state.balanceStatus, BalanceStatus.failed);
      cubit.set(100);
      expect(cubit.state.canReview, isTrue);
    });
  });

  group('TransferCubit', () {
    late MockTransferRepository repository;
    var keys = 0;

    TransferCubit make({Duration min = Duration.zero}) => TransferCubit(
      repository,
      draft,
      minProcessing: min,
      newKey: () => 'key-${++keys}',
    );

    void stubPrepare({bool biometric = false}) {
      when(
        () => repository.createChallenge(any()),
      ).thenAnswer((_) async => challenge(biometric: biometric));
      when(
        () => repository.canApproveWithBiometrics(any()),
      ).thenAnswer((_) async => biometric);
    }

    setUp(() {
      repository = MockTransferRepository();
      keys = 0;
    });

    test('prepares: the server checks the transfer and we offer approval', () async {
      stubPrepare(biometric: true);
      final cubit = make();
      await cubit.prepare();
      expect(cubit.state.phase, TransferPhase.review);
      expect(cubit.state.biometricAvailable, isTrue);
      await cubit.close();
    });

    test('a refused transfer (balance, limit) leaves with the API message', () async {
      when(() => repository.createChallenge(any())).thenThrow(
        const ApiException(
          'Insufficient wallet balance',
          statusCode: 409,
          code: 'INSUFFICIENT_BALANCE',
        ),
      );
      final cubit = make();
      await cubit.prepare();
      expect(cubit.state.phase, TransferPhase.unavailable);
      expect(cubit.state.message, 'Insufficient wallet balance');
      await cubit.close();
    });

    test('PIN: needs 4 or 6 digits before anything is sent', () async {
      stubPrepare();
      final cubit = make();
      await cubit.prepare();
      cubit.usePin();
      '12'.split('').forEach(cubit.digit);
      await cubit.submitPin();
      expect(cubit.state.validation, isNotNull);
      verifyNever(
        () => repository.transfer(
          draft: any(named: 'draft'),
          challenge: any(named: 'challenge'),
          approval: any(named: 'approval'),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      );
      await cubit.close();
    });

    test('PIN: success goes through processing to success', () async {
      stubPrepare();
      when(
        () => repository.transfer(
          draft: any(named: 'draft'),
          challenge: any(named: 'challenge'),
          approval: any(named: 'approval'),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenAnswer((_) async => receipt);
      final cubit = make();
      final phases = <TransferPhase>[];
      cubit.stream.listen((s) => phases.add(s.phase));
      await cubit.prepare();
      cubit.usePin();
      '1357'.split('').forEach(cubit.digit);
      await cubit.submitPin();
      await pumpEventQueue();
      expect(phases, containsAllInOrder([
        TransferPhase.review,
        TransferPhase.pin,
        TransferPhase.processing,
        TransferPhase.success,
      ]));
      expect(cubit.state.receipt, receipt);
      final approval = verify(
        () => repository.transfer(
          draft: draft,
          challenge: any(named: 'challenge'),
          approval: captureAny(named: 'approval'),
          idempotencyKey: 'key-1',
        ),
      ).captured.single as PinApproval;
      expect(approval.pin, '1357');
      await cubit.close();
    });

    test('processing lasts at least the minimum so the animation is seen', () async {
      stubPrepare();
      when(
        () => repository.transfer(
          draft: any(named: 'draft'),
          challenge: any(named: 'challenge'),
          approval: any(named: 'approval'),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenAnswer((_) async => receipt);
      final cubit = make(min: const Duration(milliseconds: 300));
      await cubit.prepare();
      cubit.usePin();
      '1357'.split('').forEach(cubit.digit);
      final clock = Stopwatch()..start();
      await cubit.submitPin();
      expect(clock.elapsedMilliseconds, greaterThanOrEqualTo(290));
      await cubit.close();
    });

    test('a wrong PIN returns to the PIN step with the API message', () async {
      stubPrepare();
      when(
        () => repository.transfer(
          draft: any(named: 'draft'),
          challenge: any(named: 'challenge'),
          approval: any(named: 'approval'),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenThrow(
        const ApiException(
          'Incorrect PIN. 2 attempts left.',
          statusCode: 403,
          code: 'INVALID_PIN',
        ),
      );
      final cubit = make();
      await cubit.prepare();
      cubit.usePin();
      '1111'.split('').forEach(cubit.digit);
      await cubit.submitPin();
      expect(cubit.state.phase, TransferPhase.pin);
      expect(cubit.state.message, 'Incorrect PIN. 2 attempts left.');
      expect(cubit.state.pinEntered, 0);
      expect(cubit.state.pinLocked, isFalse);
      await cubit.close();
    });

    test('a locked PIN disables the keypad', () async {
      stubPrepare();
      when(
        () => repository.transfer(
          draft: any(named: 'draft'),
          challenge: any(named: 'challenge'),
          approval: any(named: 'approval'),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenThrow(
        const ApiException('PIN locked', statusCode: 423, code: 'PIN_LOCKED'),
      );
      final cubit = make();
      await cubit.prepare();
      cubit.usePin();
      '1111'.split('').forEach(cubit.digit);
      await cubit.submitPin();
      expect(cubit.state.pinLocked, isTrue);
      cubit.digit('1');
      expect(cubit.state.pinEntered, 0);
      await cubit.close();
    });

    test('the same idempotency key is reused when the user retries', () async {
      stubPrepare();
      when(
        () => repository.transfer(
          draft: any(named: 'draft'),
          challenge: any(named: 'challenge'),
          approval: any(named: 'approval'),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenThrow(const ApiException('Unable to connect.', notProcessed: true));
      final cubit = make();
      await cubit.prepare();
      cubit.usePin();
      '1357'.split('').forEach(cubit.digit);
      await cubit.submitPin();
      '1357'.split('').forEach(cubit.digit);
      await cubit.submitPin();
      final keysUsed = verify(
        () => repository.transfer(
          draft: any(named: 'draft'),
          challenge: any(named: 'challenge'),
          approval: any(named: 'approval'),
          idempotencyKey: captureAny(named: 'idempotencyKey'),
        ),
      ).captured;
      expect(keysUsed, ['key-1', 'key-1']);
      await cubit.close();
    });

    test('an expired challenge is replaced before approving', () async {
      var n = 0;
      when(() => repository.createChallenge(any())).thenAnswer(
        (_) async => challenge(
          id: 'c-${++n}',
          expiresAt: n == 1
              ? DateTime.now().toUtc().add(const Duration(seconds: 5))
              : null,
        ),
      );
      when(
        () => repository.canApproveWithBiometrics(any()),
      ).thenAnswer((_) async => false);
      when(
        () => repository.transfer(
          draft: any(named: 'draft'),
          challenge: any(named: 'challenge'),
          approval: any(named: 'approval'),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenAnswer((_) async => receipt);
      final cubit = make();
      await cubit.prepare();
      cubit.usePin();
      '1357'.split('').forEach(cubit.digit);
      await cubit.submitPin();
      final used = verify(
        () => repository.transfer(
          draft: any(named: 'draft'),
          challenge: captureAny(named: 'challenge'),
          approval: any(named: 'approval'),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).captured.single as TransferChallenge;
      expect(used.challengeId, 'c-2');
      await cubit.close();
    });

    test('biometrics: approves with the signature and succeeds', () async {
      stubPrepare(biometric: true);
      when(
        () => repository.approveWithBiometrics(any()),
      ).thenAnswer((_) async => const BiometricApproval('c2ln'));
      when(
        () => repository.transfer(
          draft: any(named: 'draft'),
          challenge: any(named: 'challenge'),
          approval: any(named: 'approval'),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenAnswer((_) async => receipt);
      final cubit = make();
      await cubit.prepare();
      await cubit.approveWithBiometrics();
      expect(cubit.state.phase, TransferPhase.success);
      await cubit.close();
    });

    test('biometrics: cancelling the prompt changes nothing', () async {
      stubPrepare(biometric: true);
      when(() => repository.approveWithBiometrics(any())).thenThrow(
        const DeviceSecurityException('Cancelled', 'BIOMETRIC_CANCELLED'),
      );
      final cubit = make();
      await cubit.prepare();
      await cubit.approveWithBiometrics();
      expect(cubit.state.phase, TransferPhase.review);
      expect(cubit.state.busy, isFalse);
      expect(cubit.state.message, isNull);
      expect(cubit.state.biometricAvailable, isTrue);
      await cubit.close();
    });

    test('biometrics: a lost key falls back to the PIN', () async {
      stubPrepare(biometric: true);
      when(() => repository.approveWithBiometrics(any())).thenThrow(
        const DeviceSecurityException(
          'Biometrics changed. Please set up biometric approval again.',
          'KEY_INVALIDATED',
        ),
      );
      final cubit = make();
      await cubit.prepare();
      await cubit.approveWithBiometrics();
      expect(cubit.state.biometricAvailable, isFalse);
      expect(cubit.state.message, contains('Biometrics changed'));
      await cubit.close();
    });

    test('clearing the PIN wipes a half-typed entry', () async {
      stubPrepare();
      final cubit = make();
      await cubit.prepare();
      cubit.usePin();
      '13'.split('').forEach(cubit.digit);
      cubit.clearPin();
      expect(cubit.state.pinEntered, 0);
      await cubit.close();
    });
  });
}
