import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:j_wallet/core/network/api_exception.dart';
import 'package:j_wallet/core/theme/app_theme.dart';
import 'package:j_wallet/core/widgets/responsive_app.dart';
import 'package:j_wallet/features/activity/data/activity_models.dart';
import 'package:j_wallet/features/activity/data/activity_repository.dart';
import 'package:j_wallet/features/activity/view/activity_screen.dart';
import 'package:j_wallet/features/activity/view_model/activity_cubit.dart';
import 'package:j_wallet/features/home/data/home_models.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import 'activity_fixtures.dart';

class MockActivityRepository extends Mock implements ActivityRepository {}

void main() {
  late MockActivityRepository repository;

  setUpAll(() async {
    registerFallbackValue(const ActivityFilters());
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    repository = MockActivityRepository();
  });

  void stubAll(TransactionPage result) => when(
    () => repository.list(any(), page: any(named: 'page')),
  ).thenAnswer((_) async => result);

  List<ActivityFilters> asked() => verify(
    () => repository.list(captureAny(), page: any(named: 'page')),
  ).captured.cast<ActivityFilters>();

  Future<ActivityCubit> show(
    WidgetTester tester, {
    Size size = const Size(375, 1500),
    ValueChanged<TransactionItem>? onOpen,
  }) async {
    final cubit = ActivityCubit(
      repository,
      searchDelay: const Duration(milliseconds: 10),
    );
    addTearDown(cubit.close);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      BlocProvider.value(
        value: cubit,
        child: ResponsiveApp(
          builder: (context, _) => MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.dark(),
            home: ActivityScreen(onOpen: onOpen ?? (_) {}),
          ),
        ),
      ),
    );
    await cubit.load();
    await tester.pumpAndSettle();
    await tester.runAsync(() => GoogleFonts.pendingFonts());
    await tester.pumpAndSettle();
    return cubit;
  }

  testWidgets('shows the ledger grouped by day, with the server total', (
    tester,
  ) async {
    stubAll(page(sampleItems(), total: 42, hasNext: true));
    await show(tester);
    expect(find.text('TRANSACTION HISTORY'), findsOneWidget);
    expect(find.text('ACTIVITY'), findsOneWidget);
    expect(find.text('STATEMENT LEDGER'), findsOneWidget);
    // The active tab carries the total from the API.
    expect(find.text('42'), findsOneWidget);
    expect(find.textContaining('TODAY,'), findsOneWidget);
    expect(find.textContaining('YESTERDAY,'), findsOneWidget);
    expect(find.text('2 txns'), findsNWidgets(2));
    expect(find.text('1 txn'), findsOneWidget);
    expect(find.text('-₹1,500.00'), findsOneWidget);
    expect(find.text('+₹2,400.00'), findsOneWidget);
    expect(find.text('+₹45,000.00'), findsOneWidget);
    expect(find.text('Settled'), findsOneWidget);
    expect(find.text('Credited'), findsNWidgets(2));
    expect(find.text('Pending'), findsWidgets);
    expect(find.text('Failed'), findsOneWidget);
    expect(find.text('Ref: TXN-A1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tabs ask the API for debits, credits and pending', (tester) async {
    stubAll(page(sampleItems()));
    await show(tester);
    await tester.tap(find.text('Debit (-)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Credit (+)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pending').first);
    await tester.pumpAndSettle();
    final filters = asked();
    expect(filters.map((f) => f.tab), [
      ActivityTab.all,
      ActivityTab.debit,
      ActivityTab.credit,
      ActivityTab.pending,
    ]);
    // The Pending tab owns the status chip.
    expect(find.text('Status: Pending'), findsOneWidget);
  });

  testWidgets('typing in the search box asks the API after a pause', (
    tester,
  ) async {
    stubAll(page(sampleItems()));
    await show(tester);
    await tester.enterText(find.byType(TextField), 'rahul');
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();
    expect(asked().last.query, 'rahul');
    expect(find.byIcon(Icons.close), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();
    expect(asked().last.query, '');
  });

  testWidgets('the month menu filters by month', (tester) async {
    stubAll(page(sampleItems()));
    await show(tester);
    final lastMonth = DateTime(DateTime.now().year, DateTime.now().month - 1);
    final label = DateFormat('MMMM yyyy').format(lastMonth);
    await tester.tap(find.text('All time'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
    expect(asked().last.month, lastMonth);
    expect(find.text(label), findsOneWidget);
    expect(find.text('All time'), findsNothing);
  });

  testWidgets('the status menu filters by status', (tester) async {
    stubAll(page(sampleItems()));
    await show(tester);
    expect(find.text('Status: Any'), findsOneWidget);
    await tester.tap(find.text('Status: Any'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Failed').last);
    await tester.pumpAndSettle();
    expect(asked().last.status, StatusFilter.failed);
    expect(find.text('Status: Failed'), findsOneWidget);
  });

  testWidgets('All Types and CSV / PDF are clearly demo only', (tester) async {
    stubAll(page(sampleItems()));
    await show(tester);
    await tester.tap(find.text('All Types'));
    await tester.pump();
    expect(
      find.text('Transaction categories are not available in the demo.'),
      findsOneWidget,
    );
    await tester.tap(find.text('CSV / PDF'));
    await tester.pump();
    expect(
      find.text('Statement export is a demo-only feature.'),
      findsOneWidget,
    );
    // Neither of them changed what is asked of the API.
    expect(asked(), hasLength(1));
  });

  testWidgets('no matches: say so and offer to clear the filters', (tester) async {
    stubAll(page(const []));
    final cubit = await show(tester);
    expect(find.text('No transactions yet.\nSend money to see it here.'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();
    expect(find.text('No transactions match these filters.'), findsOneWidget);
    stubAll(page(sampleItems()));
    await tester.tap(find.text('CLEAR FILTERS'));
    await tester.pumpAndSettle();
    expect(cubit.state.filters, const ActivityFilters());
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, '');
    expect(find.text('Rahul Sharma'), findsOneWidget);
  });

  testWidgets('a failed load shows the API message and can retry', (tester) async {
    when(() => repository.list(any(), page: any(named: 'page'))).thenThrow(
      const ApiException('Search text is too long', statusCode: 400),
    );
    await show(tester);
    expect(find.text('Search text is too long'), findsOneWidget);
    expect(find.text('We could not load your transactions.'), findsOneWidget);
    stubAll(page(sampleItems()));
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Rahul Sharma'), findsOneWidget);
  });

  testWidgets('tapping a row opens that transaction', (tester) async {
    stubAll(page(sampleItems()));
    TransactionItem? opened;
    await show(tester, onOpen: (item) => opened = item);
    await tester.tap(find.text('Deepa Nair'));
    expect(opened?.id, 'TXN-A2');
  });

  testWidgets('scrolling to the end loads the next page', (tester) async {
    when(() => repository.list(any(), page: 1)).thenAnswer(
      (_) async => page(
        [for (var i = 0; i < 8; i++) txn('P1-$i', name: 'Person $i')],
        total: 9,
        hasNext: true,
      ),
    );
    when(() => repository.list(any(), page: 2)).thenAnswer(
      (_) async => page([txn('P2-0', name: 'Last Person')], page: 2, total: 9),
    );
    await show(tester, size: const Size(375, 700));
    expect(find.text('Last Person'), findsNothing);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -3000));
    await tester.pumpAndSettle();
    verify(() => repository.list(any(), page: 2)).called(1);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -3000));
    await tester.pumpAndSettle();
    expect(find.text('Last Person'), findsOneWidget);
    expect(find.text('LOAD MORE'), findsNothing);
  });

  testWidgets('pull to refresh asks the API again', (tester) async {
    stubAll(page(sampleItems()));
    await show(tester, size: const Size(375, 900));
    await tester.fling(find.byType(CustomScrollView), const Offset(0, 500), 1000);
    await tester.pumpAndSettle();
    expect(asked(), hasLength(2));
  });

  testWidgets('every filter chip stays on screen on a narrow phone', (tester) async {
    stubAll(page(sampleItems()));
    await show(tester, size: const Size(360, 900));
    for (final label in ['All time', 'All Types', 'Status: Any']) {
      final box = tester.getRect(find.text(label));
      expect(box.right, lessThanOrEqualTo(360), reason: label);
      expect(box.left, greaterThanOrEqualTo(0), reason: label);
    }
  });

  for (final size in const [
    Size(320, 568),
    Size(360, 640),
    Size(375, 812),
    Size(412, 915),
    Size(768, 1024),
  ]) {
    testWidgets('lays out without overflow at $size', (tester) async {
      stubAll(page(sampleItems(), total: 42, hasNext: true));
      await show(tester, size: size);
      expect(tester.takeException(), isNull);
    });
  }
}
