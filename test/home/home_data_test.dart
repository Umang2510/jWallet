import 'package:flutter_test/flutter_test.dart';
import 'package:j_wallet/core/network/api_exception.dart';
import 'package:j_wallet/core/network/authenticated_client.dart';
import 'package:j_wallet/core/utils/formatters.dart';
import 'package:j_wallet/features/home/data/home_models.dart';
import 'package:j_wallet/features/home/data/home_repository.dart';
import 'package:j_wallet/features/home/view_model/home_cubit.dart';
import 'package:mocktail/mocktail.dart';

import 'home_fixtures.dart';

class MockClient extends Mock implements AuthenticatedClient {}

class MockHomeRepository extends Mock implements HomeRepository {}

void main() {
  group('HomeRepository', () {
    late MockClient client;
    late HomeRepository repository;
    setUp(() {
      client = MockClient();
      repository = HomeRepository(client);
      when(
        () => client.request('GET', '/api/v1/users/profile'),
      ).thenAnswer((_) async => profileJson());
      when(
        () => client.request('GET', '/api/v1/wallet/balance'),
      ).thenAnswer((_) async => balanceJson());
      when(
        () => client.request('GET', '/api/v1/transactions?page=1&limit=5'),
      ).thenAnswer((_) async => transactionsJson());
    });

    test('parses profile, balance and the latest transactions', () async {
      final data = await repository.load();
      expect(data.profile.name, 'Demo User');
      expect(data.profile.initials, 'DU');
      expect(data.wallet.availableBalance, 25450.75);
      expect(data.wallet.cardMask, '•••• 4589');
      expect(data.recent, hasLength(2));
      expect(data.recent.first.type, TransactionType.debit);
      expect(data.recent.first.counterparty, 'Rahul Sharma');
      expect(data.recent.first.amount, 1500);
      expect(data.recent.last.isCredit, isTrue);
      expect(data.recent.last.status, TransactionStatus.failed);
      expect(data.recent.last.amount, 45000.5);
    });

    test('an API failure surfaces its own message', () async {
      when(
        () => client.request('GET', '/api/v1/wallet/balance'),
      ).thenThrow(const ApiException('Wallet not found', statusCode: 404));
      await expectLater(
        repository.load(),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            'Wallet not found',
          ),
        ),
      );
    });

    test('a malformed response becomes a friendly error', () async {
      when(
        () => client.request('GET', '/api/v1/wallet/balance'),
      ).thenAnswer((_) async => {'availableBalance': 'lots'});
      await expectLater(repository.load(), throwsA(isA<ApiException>()));
    });
  });

  group('HomeCubit', () {
    late MockHomeRepository repository;
    late HomeCubit cubit;
    setUp(() {
      repository = MockHomeRepository();
      cubit = HomeCubit(repository);
    });
    tearDown(() => cubit.close());

    test('loads and exposes the data', () async {
      when(() => repository.load()).thenAnswer((_) async => demoHome());
      await cubit.load();
      expect(cubit.state.status, HomeStatus.loaded);
      expect(cubit.state.data, demoHome());
      expect(cubit.state.message, isNull);
    });

    test('a failed first load keeps the API message for the snackbar', () async {
      when(
        () => repository.load(),
      ).thenThrow(const ApiException('Wallet not found', statusCode: 404));
      await cubit.load();
      expect(cubit.state.status, HomeStatus.failure);
      expect(cubit.state.data, isNull);
      expect(cubit.state.message, 'Wallet not found');
    });

    test('retry recovers after a failure', () async {
      when(() => repository.load()).thenThrow(const ApiException('Offline'));
      await cubit.load();
      when(() => repository.load()).thenAnswer((_) async => demoHome());
      await cubit.load();
      expect(cubit.state.status, HomeStatus.loaded);
      expect(cubit.state.message, isNull);
    });

    test('a failed refresh keeps the numbers on screen', () async {
      when(() => repository.load()).thenAnswer((_) async => demoHome());
      await cubit.load();
      when(
        () => repository.load(),
      ).thenThrow(const ApiException('Unable to connect.'));
      await cubit.refresh();
      expect(cubit.state.status, HomeStatus.loaded);
      expect(cubit.state.data, demoHome());
      expect(cubit.state.message, 'Unable to connect.');
    });

    test('the same failure twice is still a new state (snackbar again)', () async {
      when(() => repository.load()).thenAnswer((_) async => demoHome());
      await cubit.load();
      when(() => repository.load()).thenThrow(const ApiException('Offline'));
      await cubit.refresh();
      final first = cubit.state;
      await cubit.refresh();
      expect(cubit.state, isNot(first));
    });
  });

  group('Formatters.relativeDateTime', () {
    final now = DateTime(2026, 11, 17, 15);
    String at(DateTime t) =>
        Formatters.relativeDateTime(t.toUtc().toIso8601String(), now: now);

    test('today', () {
      expect(at(DateTime(2026, 11, 17, 9, 41)), 'Today, 9:41 AM');
    });
    test('yesterday', () {
      expect(at(DateTime(2026, 11, 16, 22, 5)), 'Yesterday, 10:05 PM');
    });
    test('older dates', () {
      expect(at(DateTime(2026, 10, 24, 8, 45)), '24 Oct, 8:45 AM');
    });
  });
}
