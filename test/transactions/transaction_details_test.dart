import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:j_wallet/core/network/api_exception.dart';
import 'package:j_wallet/core/theme/app_theme.dart';
import 'package:j_wallet/core/widgets/responsive_app.dart';
import 'package:j_wallet/features/home/data/home_models.dart';
import 'package:j_wallet/features/transactions/data/transaction_details.dart';
import 'package:j_wallet/features/transactions/data/transaction_repository.dart';
import 'package:j_wallet/features/transactions/view/transaction_details_screen.dart';
import 'package:j_wallet/features/transactions/view_model/transaction_details_cubit.dart';
import 'package:j_wallet/features/transfer/view/widgets/transfer_hero_coin.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../transfer/transfer_fixtures.dart' as fixtures;

class MockTransactionRepository extends Mock implements TransactionRepository {}

TransactionDetails sample({
  TransactionType type = TransactionType.debit,
  TransactionStatus status = TransactionStatus.success,
  String? remarks = 'Dinner split & groceries',
}) => TransactionDetails(
  id: 'TXN20261117K7Q2MX',
  type: type,
  amount: 1500,
  currency: 'INR',
  counterparty: 'Rahul Sharma',
  status: status,
  createdAt: '2026-11-17T04:00:00.000Z',
  maskedMobile: 'XXXXXX3210',
  remarks: remarks,
);

void main() {
  late MockTransactionRepository repository;

  setUpAll(() async {
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    repository = MockTransactionRepository();
  });

  group('TransactionDetails', () {
    test('parses the API record', () {
      final details = TransactionDetails.fromJson({
        'id': 'TXN1',
        'type': 'CREDIT',
        'amount': 45000.5,
        'currency': 'INR',
        'beneficiaryName': 'Tech Corp',
        'status': 'PENDING',
        'createdAt': '2026-11-17T04:00:00.000Z',
        'mobileNumber': 'XXXXXX3210',
        'remarks': null,
      });
      expect(details.isCredit, isTrue);
      expect(details.status, TransactionStatus.pending);
      expect(details.amount, 45000.5);
      expect(details.remarks, isNull);
    });

    test('a transfer receipt becomes a successful debit', () {
      final details = TransactionDetails.fromReceipt(fixtures.receipt);
      expect(details.type, TransactionType.debit);
      expect(details.status, TransactionStatus.success);
      expect(details.id, 'TXN20261117K7Q2MX');
      expect(details.remarks, 'Dinner split & groceries');
    });
  });

  group('TransactionDetailsCubit', () {
    test('shows the receipt instantly, then the real record', () async {
      final fresh = sample(remarks: 'From the server');
      when(() => repository.details(any())).thenAnswer((_) async => fresh);
      final cubit = TransactionDetailsCubit(
        repository,
        'TXN20261117K7Q2MX',
        initial: sample(),
      );
      expect(cubit.state.details, sample());
      expect(cubit.state.status, DetailsStatus.loaded);
      await cubit.load();
      expect(cubit.state.details, fresh);
      await cubit.close();
    });

    test('a failed reload keeps the receipt and reports the API message', () async {
      when(() => repository.details(any())).thenThrow(
        const ApiException('Transaction not found', statusCode: 404),
      );
      final cubit = TransactionDetailsCubit(
        repository,
        'TXN1',
        initial: sample(),
      );
      await cubit.load();
      expect(cubit.state.status, DetailsStatus.loaded);
      expect(cubit.state.details, sample());
      expect(cubit.state.message, 'Transaction not found');
      await cubit.close();
    });

    test('with nothing to show, a failure is a failure', () async {
      when(() => repository.details(any())).thenThrow(
        const ApiException('Transaction not found', statusCode: 404),
      );
      final cubit = TransactionDetailsCubit(repository, 'TXN1');
      await cubit.load();
      expect(cubit.state.status, DetailsStatus.failure);
      expect(cubit.state.details, isNull);
      await cubit.close();
    });
  });

  group('TransactionDetailsScreen', () {
    Future<void> show(
      WidgetTester tester,
      TransactionDetails details, {
      VoidCallback? onDone,
      Size size = const Size(375, 812),
    }) async {
      when(() => repository.details(any())).thenAnswer((_) async => details);
      final cubit = TransactionDetailsCubit(
        repository,
        details.id,
        initial: details,
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
              theme: AppTheme.dark(),
              home: TransactionDetailsScreen(onDone: onDone ?? () {}),
            ),
          ),
        ),
      );
      await cubit.load();
      await tester.pumpAndSettle();
      await tester.runAsync(() => GoogleFonts.pendingFonts());
      await tester.pumpAndSettle();
    }

    testWidgets('shows the amount, who, when and the reference', (tester) async {
      await show(tester, sample());
      expect(find.text('TRANSACTION'), findsOneWidget);
      expect(find.text('Sent to Rahul Sharma'), findsOneWidget);
      expect(find.text('COMPLETED'), findsOneWidget);
      expect(find.text('XXXXXX3210'), findsOneWidget);
      expect(find.text('Dinner split & groceries'), findsOneWidget);
      expect(find.text('TXN20261117K7Q2MX'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText() == '-₹1,500.00',
        ),
        findsOneWidget,
      );
    });

    testWidgets('a successful transfer has the coin to land on', (tester) async {
      await show(tester, sample());
      expect(find.byType(TransferHeroCoin), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    });

    testWidgets('credits read as received', (tester) async {
      await show(tester, sample(type: TransactionType.credit));
      expect(find.text('Received from Rahul Sharma'), findsOneWidget);
      expect(find.text('RECEIVED'), findsOneWidget);
      expect(find.text('From'), findsOneWidget);
    });

    testWidgets('failed and pending are not shown as a success', (tester) async {
      await show(tester, sample(status: TransactionStatus.failed));
      expect(find.text('FAILED'), findsOneWidget);
      expect(find.byType(TransferHeroCoin), findsNothing);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    });

    testWidgets('a missing note is simply left out', (tester) async {
      await show(tester, sample(remarks: null));
      expect(find.text('Note'), findsNothing);
    });

    testWidgets('tapping the reference copies it', (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await show(tester, sample());
      await tester.tap(find.text('TXN20261117K7Q2MX'));
      await tester.pump();
      expect(copied, 'TXN20261117K7Q2MX');
      expect(find.text('Transaction ID copied'), findsOneWidget);
    });

    testWidgets('Done and close both leave', (tester) async {
      var left = 0;
      await show(tester, sample(), onDone: () => left++);
      await tester.tap(find.text('DONE'));
      await tester.tap(find.byIcon(Icons.close));
      expect(left, 2);
    });

    testWidgets('fits a small phone without scrolling', (tester) async {
      await show(tester, sample(), size: const Size(360, 640));
      expect(tester.takeException(), isNull);
      final scrollable = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );
      expect(scrollable.position.maxScrollExtent, 0);
    });
  });
}
