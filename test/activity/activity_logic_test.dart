import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:j_wallet/core/network/api_exception.dart';
import 'package:j_wallet/core/network/authenticated_client.dart';
import 'package:j_wallet/core/utils/formatters.dart';
import 'package:j_wallet/features/activity/data/activity_models.dart';
import 'package:j_wallet/features/activity/data/activity_repository.dart';
import 'package:j_wallet/features/activity/view_model/activity_cubit.dart';
import 'package:j_wallet/features/home/data/home_models.dart';
import 'package:mocktail/mocktail.dart';

import 'activity_fixtures.dart';

class MockClient extends Mock implements AuthenticatedClient {}

class MockActivityRepository extends Mock implements ActivityRepository {}

void main() {
  setUpAll(() => registerFallbackValue(const ActivityFilters()));

  group('ActivityFilters.path', () {
    String path(ActivityFilters f, {int page = 1}) =>
        f.path(page: page, limit: 20);

    test('no filters is just the page', () {
      expect(path(const ActivityFilters()), '/api/v1/transactions?page=1&limit=20');
      expect(
        path(const ActivityFilters(), page: 3),
        '/api/v1/transactions?page=3&limit=20',
      );
    });

    test('Debit and Credit tabs filter by type', () {
      expect(
        path(const ActivityFilters(tab: ActivityTab.debit)),
        contains('&type=DEBIT'),
      );
      expect(
        path(const ActivityFilters(tab: ActivityTab.credit)),
        contains('&type=CREDIT'),
      );
    });

    test('the Pending tab filters by status', () {
      final p = path(const ActivityFilters(tab: ActivityTab.pending));
      expect(p, contains('&status=PENDING'));
      expect(p, isNot(contains('type=')));
    });

    test('the Pending tab wins over the status chip', () {
      const f = ActivityFilters(
        tab: ActivityTab.pending,
        status: StatusFilter.failed,
      );
      expect(f.effectiveStatus, StatusFilter.pending);
      expect(path(f), contains('status=PENDING'));
    });

    test('status chip values', () {
      expect(
        path(const ActivityFilters(status: StatusFilter.success)),
        contains('status=SUCCESS'),
      );
      expect(
        path(const ActivityFilters(status: StatusFilter.failed)),
        contains('status=FAILED'),
      );
      expect(path(const ActivityFilters()), isNot(contains('status=')));
    });

    test('a month becomes its first and last day', () {
      expect(
        path(ActivityFilters(month: DateTime(2026, 10))),
        contains('&from=2026-10-01&to=2026-10-31'),
      );
      expect(
        path(ActivityFilters(month: DateTime(2028, 2))),
        contains('&from=2028-02-01&to=2028-02-29'),
      );
      expect(
        path(ActivityFilters(month: DateTime(2026, 12))),
        contains('&to=2026-12-31'),
      );
    });

    test('search text is trimmed and encoded', () {
      expect(
        path(const ActivityFilters(query: '  Rahul Sharma ')),
        contains('&q=Rahul%20Sharma'),
      );
      expect(path(const ActivityFilters(query: '   ')), isNot(contains('q=')));
    });

    test('everything combined, in a fixed order', () {
      expect(
        path(
          ActivityFilters(
            tab: ActivityTab.debit,
            status: StatusFilter.success,
            month: DateTime(2026, 10),
            query: 'rahul',
          ),
        ),
        '/api/v1/transactions?page=1&limit=20&type=DEBIT&status=SUCCESS'
        '&q=rahul&from=2026-10-01&to=2026-10-31',
      );
    });

    test('the encrypted channel signs exactly what goes on the wire', () {
      // Dart must not re-encode the query when it builds the request URI.
      for (final text in ["a b&c=d", 'é₹ 100%', "it's (50)*!", 'x/y?z#w', '+ +']) {
        final p = path(ActivityFilters(query: text));
        final wire = Uri.parse('https://api.example.test$p');
        expect('${wire.path}?${wire.query}', p, reason: text);
        expect(wire.queryParameters['q'], text.trim());
      }
    });

    test('isFiltered', () {
      expect(const ActivityFilters().isFiltered, isFalse);
      expect(const ActivityFilters(tab: ActivityTab.credit).isFiltered, isTrue);
      expect(const ActivityFilters(query: 'a').isFiltered, isTrue);
      expect(ActivityFilters(month: DateTime(2026, 10)).isFiltered, isTrue);
      expect(
        const ActivityFilters(status: StatusFilter.failed).isFiltered,
        isTrue,
      );
    });
  });

  group('ActivityRepository', () {
    test('requests the path and parses the page', () async {
      final client = MockClient();
      when(
        () => client.request('GET', '/api/v1/transactions?page=2&limit=20&type=DEBIT'),
      ).thenAnswer(
        (_) async => pageJson(
          [
            {
              'id': 'TXN1',
              'type': 'DEBIT',
              'amount': 1500,
              'currency': 'INR',
              'beneficiaryName': 'Rahul Sharma',
              'status': 'SUCCESS',
              'createdAt': '2026-11-17T04:00:00.000Z',
            },
          ],
          page: 2,
          total: 41,
          hasNext: true,
        ),
      );
      final result = await ActivityRepository(client).list(
        const ActivityFilters(tab: ActivityTab.debit),
        page: 2,
      );
      expect(result.items.single.counterparty, 'Rahul Sharma');
      expect(result.page, 2);
      expect(result.totalItems, 41);
      expect(result.hasNextPage, isTrue);
    });

    test('a malformed answer becomes a friendly error', () async {
      final client = MockClient();
      when(() => client.request('GET', any())).thenAnswer(
        (_) async => {'items': 'nope', 'pagination': <String, dynamic>{}},
      );
      await expectLater(
        ActivityRepository(client).list(const ActivityFilters()),
        throwsA(isA<ApiException>()),
      );
    });
  });

  group('ActivityCubit', () {
    late MockActivityRepository repository;
    late StreamController<void> wallet;
    late ActivityCubit cubit;

    setUp(() {
      repository = MockActivityRepository();
      wallet = StreamController<void>.broadcast();
      cubit = ActivityCubit(
        repository,
        walletChanges: wallet.stream,
        searchDelay: const Duration(milliseconds: 30),
      );
    });
    tearDown(() async {
      await cubit.close();
      await wallet.close();
    });

    void stub(TransactionPage result) => when(
      () => repository.list(any(), page: any(named: 'page')),
    ).thenAnswer((_) async => result);

    List<ActivityFilters> asked() => verify(
      () => repository.list(captureAny(), page: any(named: 'page')),
    ).captured.cast<ActivityFilters>();

    test('loads the first page and the server total', () async {
      stub(page(sampleItems(), total: 42, hasNext: true));
      await cubit.load();
      expect(cubit.state.status, ActivityStatus.loaded);
      expect(cubit.state.items, hasLength(5));
      expect(cubit.state.total, 42);
      expect(cubit.state.hasNext, isTrue);
    });

    test('every filter change reloads from the API', () async {
      stub(page(sampleItems()));
      await cubit.load();
      cubit.setTab(ActivityTab.debit);
      await pumpEventQueue();
      cubit.setStatus(StatusFilter.success);
      await pumpEventQueue();
      cubit.setMonth(DateTime(2026, 10, 17));
      await pumpEventQueue();
      final filters = asked();
      expect(filters[1].tab, ActivityTab.debit);
      expect(filters[2].status, StatusFilter.success);
      expect(filters[3].month, DateTime(2026, 10));
      expect(filters, hasLength(4));
    });

    test('choosing the same filter again does not reload', () async {
      stub(page(sampleItems()));
      await cubit.load();
      cubit.setTab(ActivityTab.all);
      await pumpEventQueue();
      expect(asked(), hasLength(1));
    });

    test('search waits for a pause in typing, then asks once', () async {
      stub(page(sampleItems()));
      await cubit.load();
      cubit
        ..setQuery('r')
        ..setQuery('ra')
        ..setQuery('rah');
      expect(cubit.state.filters.query, 'rah');
      await Future<void>.delayed(const Duration(milliseconds: 120));
      final filters = asked();
      expect(filters, hasLength(2));
      expect(filters.last.query, 'rah');
    });

    test('search is capped at 50 characters (the API limit)', () {
      cubit.setQuery('x' * 80);
      expect(cubit.state.filters.query.length, 50);
    });

    test('an older, slower answer never replaces a newer one', () async {
      final slow = Completer<TransactionPage>();
      when(
        () => repository.list(
          const ActivityFilters(),
          page: any(named: 'page'),
        ),
      ).thenAnswer((_) => slow.future);
      when(
        () => repository.list(
          const ActivityFilters(tab: ActivityTab.credit),
          page: any(named: 'page'),
        ),
      ).thenAnswer(
        (_) async => page([
          txn('NEW', type: TransactionType.credit),
        ]),
      );
      unawaited(cubit.load());
      cubit.setTab(ActivityTab.credit);
      await pumpEventQueue();
      slow.complete(page([txn('OLD')]));
      await pumpEventQueue();
      expect(cubit.state.items.single.id, 'NEW');
    });

    test('loads the next page and appends it', () async {
      when(
        () => repository.list(any(), page: 1),
      ).thenAnswer((_) async => page([txn('1'), txn('2')], total: 3, hasNext: true));
      when(
        () => repository.list(any(), page: 2),
      ).thenAnswer((_) async => page([txn('3')], page: 2, total: 3));
      await cubit.load();
      await cubit.loadMore();
      expect(cubit.state.items.map((e) => e.id), ['1', '2', '3']);
      expect(cubit.state.hasNext, isFalse);
      await cubit.loadMore(); // nothing left: no third request
      verify(() => repository.list(any(), page: 2)).called(1);
      verifyNever(() => repository.list(any(), page: 3));
    });

    test('does not load more twice at once', () async {
      final second = Completer<TransactionPage>();
      when(
        () => repository.list(any(), page: 1),
      ).thenAnswer((_) async => page([txn('1')], total: 2, hasNext: true));
      when(() => repository.list(any(), page: 2)).thenAnswer((_) => second.future);
      await cubit.load();
      final first = cubit.loadMore();
      await cubit.loadMore();
      second.complete(page([txn('2')], page: 2, total: 2));
      await first;
      verify(() => repository.list(any(), page: 2)).called(1);
    });

    test('a failed first load shows the API message', () async {
      when(() => repository.list(any(), page: any(named: 'page'))).thenThrow(
        const ApiException('Search text is too long', statusCode: 400),
      );
      await cubit.load();
      expect(cubit.state.status, ActivityStatus.failure);
      expect(cubit.state.message, 'Search text is too long');
    });

    test('a failed refresh or page keeps the rows on screen', () async {
      when(
        () => repository.list(any(), page: 1),
      ).thenAnswer((_) async => page([txn('1')], total: 2, hasNext: true));
      await cubit.load();
      when(() => repository.list(any(), page: 2)).thenThrow(
        const ApiException('Unable to connect.', notProcessed: true),
      );
      await cubit.loadMore();
      expect(cubit.state.items, hasLength(1));
      expect(cubit.state.status, ActivityStatus.loaded);
      expect(cubit.state.message, 'Unable to connect.');
      expect(cubit.state.loadingMore, isFalse);
      when(() => repository.list(any(), page: 1)).thenThrow(
        const ApiException('Server busy', statusCode: 503),
      );
      await cubit.refresh();
      expect(cubit.state.items, hasLength(1));
      expect(cubit.state.message, 'Server busy');
    });

    test('clearing filters returns to the full list', () async {
      stub(page(sampleItems()));
      cubit
        ..setTab(ActivityTab.credit)
        ..setStatus(StatusFilter.success);
      await pumpEventQueue();
      cubit.clearFilters();
      await pumpEventQueue();
      expect(cubit.state.filters, const ActivityFilters());
      expect(asked().last, const ActivityFilters());
    });

    test('an empty result is a loaded, empty list', () async {
      stub(page(const []));
      await cubit.load();
      expect(cubit.state.status, ActivityStatus.loaded);
      expect(cubit.state.items, isEmpty);
    });

    test('a transfer elsewhere refreshes the list', () async {
      stub(page(sampleItems()));
      await cubit.load();
      wallet.add(null);
      await pumpEventQueue();
      expect(asked(), hasLength(2));
    });
  });

  group('Formatters for the ledger', () {
    final now = DateTime(2026, 11, 17, 15);
    test('day headings', () {
      expect(
        Formatters.dayHeading(DateTime(2026, 11, 17), now: now),
        'TODAY, 17 NOV 2026',
      );
      expect(
        Formatters.dayHeading(DateTime(2026, 11, 16), now: now),
        'YESTERDAY, 16 NOV 2026',
      );
      expect(Formatters.dayHeading(DateTime(2026, 10, 20), now: now), '20 OCT 2026');
    });

    test('clock is two-digit with AM/PM', () {
      expect(Formatters.clock(at(DateTime(2026, 11, 17, 9, 42))), '09:42 AM');
      expect(Formatters.clock(at(DateTime(2026, 11, 17, 18, 30))), '06:30 PM');
    });
  });
}
