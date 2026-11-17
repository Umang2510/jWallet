import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:j_wallet/core/network/api_exception.dart';
import 'package:j_wallet/core/theme/app_theme.dart';
import 'package:j_wallet/core/widgets/responsive_app.dart';
import 'package:j_wallet/features/transfer/data/transfer_models.dart';
import 'package:j_wallet/features/transfer/data/transfer_repository.dart';
import 'package:j_wallet/features/transfer/view/confirm_transfer_screen.dart';
import 'package:j_wallet/features/transfer/view/send_money_screen.dart';
import 'package:j_wallet/features/transfer/view/widgets/transfer_hero_coin.dart';
import 'package:j_wallet/features/transfer/view_model/send_money_cubit.dart';
import 'package:j_wallet/features/transfer/view_model/transfer_cubit.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import 'transfer_fixtures.dart';

class MockTransferRepository extends Mock implements TransferRepository {}

void main() {
  late MockTransferRepository repository;

  setUpAll(() async {
    registerFallbackValue(draft);
    registerFallbackValue(challenge());
    registerFallbackValue(const PinApproval('1357'));
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });

  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    repository = MockTransferRepository();
    when(() => repository.availableBalance()).thenAnswer((_) async => 25450.75);
  });

  Future<void> pumpApp(
    WidgetTester tester,
    Widget home, {
    Size size = const Size(375, 812),
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ResponsiveApp(
        builder: (context, _) => MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark(),
          home: home,
        ),
      ),
    );
  }

  Future<void> settleFonts(WidgetTester tester) async {
    await tester.pumpAndSettle();
    await tester.runAsync(() => GoogleFonts.pendingFonts());
    await tester.pumpAndSettle();
  }

  bool amountShows(String text) => find
      .byWidgetPredicate(
        (w) => w is RichText && w.text.toPlainText() == text,
      )
      .evaluate()
      .isNotEmpty;

  group('SendMoneyScreen', () {
    Future<SendMoneyCubit> showSend(
      WidgetTester tester, {
      bool withRecipient = true,
      ValueChanged<TransferDraft>? onReview,
      Size size = const Size(375, 812),
    }) async {
      final cubit = SendMoneyCubit(
        repository,
        recipient: withRecipient ? rahul : null,
      );
      addTearDown(cubit.close);
      await pumpApp(
        tester,
        BlocProvider.value(
          value: cubit,
          child: SendMoneyScreen(onReview: onReview ?? (_) {}),
        ),
        size: size,
      );
      await cubit.load();
      await settleFonts(tester);
      return cubit;
    }

    ElevatedButton? reviewButton(WidgetTester tester) => null;

    VoidCallback? reviewAction(WidgetTester tester) => tester
        .widget<FilledButton>(find.byType(FilledButton))
        .onPressed;

    testWidgets('shows the recipient, balance and an empty amount', (
      tester,
    ) async {
      await showSend(tester);
      expect(find.text('SEND MONEY'), findsOneWidget);
      expect(find.text('Rahul Sharma'), findsOneWidget);
      expect(find.text('+91 98765 43210'), findsOneWidget);
      expect(find.text('rahul@okaxis'), findsOneWidget);
      expect(find.text('Balance: ₹25,450.75'), findsOneWidget);
      expect(find.text('Zero fee transfer'), findsOneWidget);
      expect(reviewAction(tester), isNull);
      reviewButton(tester);
    });

    testWidgets('typing on the keypad builds the amount', (tester) async {
      await showSend(tester);
      for (final key in ['1', '5', '0', '0']) {
        await tester.tap(find.text(key).first);
      }
      await tester.pump();
      expect(amountShows('₹1,500.00'), isTrue);
      await tester.tap(find.text('.'));
      await tester.tap(find.text('5'));
      await tester.pump();
      expect(amountShows('₹1,500.50'), isTrue);
      await tester.tap(find.byIcon(Icons.backspace_outlined));
      await tester.pump();
      expect(amountShows('₹1,500.00'), isTrue);
    });

    testWidgets('chips add, set and fill the maximum', (tester) async {
      final cubit = await showSend(tester);
      await tester.tap(find.text('+₹500'));
      await tester.tap(find.text('+₹2,000'));
      await tester.pump();
      expect(cubit.state.amount.value, 2500);
      await tester.tap(find.text('₹1,500'));
      await tester.pump();
      expect(cubit.state.amount.value, 1500);
      await tester.tap(find.text('Max'));
      await tester.pump();
      expect(cubit.state.amount.value, 25450.75);
    });

    testWidgets('an amount over the balance is flagged and cannot be reviewed', (
      tester,
    ) async {
      final cubit = await showSend(tester);
      cubit.set(30000);
      await tester.pumpAndSettle();
      expect(find.text('Exceeds your balance'), findsOneWidget);
      expect(find.text('Zero fee transfer'), findsNothing);
      expect(reviewAction(tester), isNull);
    });

    testWidgets('Review hands over the finished draft', (tester) async {
      TransferDraft? reviewed;
      final cubit = await showSend(tester, onReview: (d) => reviewed = d);
      cubit.set(1500);
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'Dinner split & groceries');
      await tester.pump();
      expect(find.byIcon(Icons.close), findsOneWidget);
      reviewAction(tester)!();
      expect(reviewed?.amount, 1500);
      expect(reviewed?.recipient, rahul);
      expect(reviewed?.remarks, 'Dinner split & groceries');
    });

    testWidgets('the note can be cleared', (tester) async {
      final cubit = await showSend(tester);
      await tester.enterText(find.byType(TextField), 'rent');
      await tester.pump();
      expect(cubit.state.remarks, 'rent');
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      expect(cubit.state.remarks, '');
    });

    testWidgets('opens the recipient picker when none is chosen', (
      tester,
    ) async {
      final cubit = await showSend(tester, withRecipient: false);
      expect(find.text('SEND TO'), findsOneWidget);
      await tester.tap(find.text('Priya Patel'));
      await tester.pumpAndSettle();
      expect(cubit.state.recipient?.name, 'Priya Patel');
      expect(find.text('SEND TO'), findsNothing);
    });

    testWidgets('a new recipient is validated, then used', (tester) async {
      final cubit = await showSend(tester, withRecipient: false);
      await tester.enterText(find.byType(TextFormField).at(0), 'Asha Rao');
      await tester.enterText(find.byType(TextFormField).at(1), '12345');
      await tester.ensureVisible(find.text('CONTINUE'));
      await tester.tap(find.text('CONTINUE'));
      await tester.pump();
      expect(find.text('Enter a valid 10-digit mobile number'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).at(1), '9812345678');
      await tester.tap(find.text('CONTINUE'));
      await tester.pumpAndSettle();
      expect(cubit.state.recipient?.name, 'Asha Rao');
      expect(cubit.state.recipient?.mobile, '9812345678');
    });

    testWidgets('a balance failure shows the API message in a snackbar', (
      tester,
    ) async {
      when(() => repository.availableBalance()).thenThrow(
        const ApiException('Wallet not found', statusCode: 404),
      );
      await showSend(tester);
      expect(find.text('Wallet not found'), findsOneWidget);
      expect(find.text('Balance: unavailable'), findsOneWidget);
    });

    for (final size in const [
      Size(360, 640),
      Size(375, 667),
      Size(375, 812),
      Size(412, 915),
      Size(768, 1024),
    ]) {
      testWidgets('fits $size without scrolling', (tester) async {
        final cubit = await showSend(tester, size: size);
        cubit.set(1500);
        await tester.pump();
        expect(tester.takeException(), isNull);
        final scrollable = tester.state<ScrollableState>(
          find.byType(Scrollable).first,
        );
        expect(scrollable.position.maxScrollExtent, 0);
      });
    }
  });

  group('ConfirmTransferScreen', () {
    void stubPrepare({bool biometric = false}) {
      when(
        () => repository.createChallenge(any()),
      ).thenAnswer((_) async => challenge(biometric: biometric));
      when(
        () => repository.canApproveWithBiometrics(any()),
      ).thenAnswer((_) async => biometric);
    }

    void stubTransfer(Future<TransferReceipt> Function() answer) => when(
      () => repository.transfer(
        draft: any(named: 'draft'),
        challenge: any(named: 'challenge'),
        approval: any(named: 'approval'),
        idempotencyKey: any(named: 'idempotencyKey'),
      ),
    ).thenAnswer((_) => answer());

    Future<TransferCubit> showConfirm(
      WidgetTester tester, {
      ValueChanged<TransferReceipt>? onDone,
      // The loading spinner never stops animating, so it cannot "settle".
      bool settle = true,
    }) async {
      final cubit = TransferCubit(repository, draft, minProcessing: Duration.zero);
      addTearDown(cubit.close);
      await pumpApp(
        tester,
        BlocProvider.value(
          value: cubit,
          child: ConfirmTransferScreen(
            draft: draft,
            successHold: Duration.zero,
            onDone: onDone ?? (_) {},
          ),
        ),
      );
      await cubit.prepare();
      if (settle) {
        await settleFonts(tester);
      } else {
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
      }
      return cubit;
    }

    Future<void> typePin(WidgetTester tester, String pin) async {
      for (final digit in pin.split('')) {
        await tester.tap(find.text(digit).first);
      }
      await tester.pump();
    }

    testWidgets('review shows what will be sent', (tester) async {
      stubPrepare();
      await showConfirm(tester);
      expect(find.text('REVIEW TRANSFER'), findsOneWidget);
      expect(find.text('YOU ARE SENDING'), findsOneWidget);
      expect(find.text('XXXXXX3210'), findsOneWidget);
      expect(find.text('Dinner split & groceries'), findsOneWidget);
      expect(find.text('Zero fee'), findsOneWidget);
      expect(find.text('ENTER PIN TO SEND'), findsOneWidget);
      expect(find.text('APPROVE WITH BIOMETRICS'), findsNothing);
    });

    testWidgets('offers biometrics first when available', (tester) async {
      stubPrepare(biometric: true);
      await showConfirm(tester);
      expect(find.text('APPROVE WITH BIOMETRICS'), findsOneWidget);
      expect(find.text('USE PIN INSTEAD'), findsOneWidget);
    });

    testWidgets('PIN → processing scene → details handoff', (tester) async {
      stubPrepare();
      stubTransfer(() async => receipt);
      TransferReceipt? done;
      await showConfirm(tester, onDone: (r) => done = r);
      await tester.tap(find.text('ENTER PIN TO SEND'));
      await tester.pumpAndSettle();
      expect(find.text('TRANSACTION PIN'), findsOneWidget);
      expect(find.text('Enter your PIN'), findsOneWidget);
      expect(find.textContaining('Approve sending ₹1,500.00 to Rahul Sharma'), findsOneWidget);
      await typePin(tester, '1357');
      await tester.tap(find.text('SEND ₹1,500.00'));
      // The light scene loops forever, so advance time instead of settling.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('TRANSFER COMPLETE').evaluate().isNotEmpty ||
          find.text('SECURING YOUR TRANSFER').evaluate().isNotEmpty, isTrue);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('TRANSFER COMPLETE'), findsOneWidget);
      expect(done?.transactionId, 'TXN20261117K7Q2MX');
      // The PIN is never kept or shown on screen.
      expect(find.text('1357'), findsNothing);
    });

    testWidgets('a wrong PIN shows the API message and stays on the PIN step', (
      tester,
    ) async {
      stubPrepare();
      stubTransfer(
        () async => throw const ApiException(
          'Incorrect PIN. 2 attempts left.',
          statusCode: 403,
          code: 'INVALID_PIN',
        ),
      );
      var done = false;
      await showConfirm(tester, onDone: (_) => done = true);
      await tester.tap(find.text('ENTER PIN TO SEND'));
      await tester.pumpAndSettle();
      await typePin(tester, '1111');
      await tester.tap(find.text('SEND ₹1,500.00'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.text('Incorrect PIN. 2 attempts left.'), findsOneWidget);
      expect(find.text('Enter your PIN'), findsOneWidget);
      expect(done, isFalse);
    });

    testWidgets('the PIN step has a way back to the review', (tester) async {
      stubPrepare();
      await showConfirm(tester);
      await tester.tap(find.text('ENTER PIN TO SEND'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(find.text('REVIEW TRANSFER'), findsOneWidget);
    });

    testWidgets('a refusal before approval shows the API message', (tester) async {
      when(() => repository.createChallenge(any())).thenThrow(
        const ApiException(
          'Insufficient wallet balance',
          statusCode: 409,
          code: 'INSUFFICIENT_BALANCE',
        ),
      );
      await showConfirm(tester, settle: false);
      expect(find.text('Insufficient wallet balance'), findsOneWidget);
    });
  });

  group('Hero', () {
    testWidgets('the coin flies from the processing screen to the details badge', (
      tester,
    ) async {
      final navigator = GlobalKey<NavigatorState>();
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(375, 812);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ResponsiveApp(
          builder: (context, _) => MaterialApp(
            navigatorKey: navigator,
            theme: AppTheme.dark(),
            home: Scaffold(body: Center(child: TransferHeroCoin(size: 124))),
          ),
        ),
      );
      await tester.pumpAndSettle();
      navigator.currentState!.pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 40),
                child: TransferHeroCoin(size: 84, success: true),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      // Mid-flight there is a round coin between the two sizes.
      final sizes = [
        for (final box in tester.widgetList<DecoratedBox>(
          find.byType(DecoratedBox),
        ))
          if (box.decoration is BoxDecoration &&
              (box.decoration as BoxDecoration).shape == BoxShape.circle)
            tester.getSize(find.byWidget(box)).width,
      ];
      expect(
        sizes.any((w) => w > 85 && w < 123),
        isTrue,
        reason: 'a coin should be mid-flight, saw $sizes',
      );
      await tester.pumpAndSettle();
      expect(find.byType(TransferHeroCoin), findsOneWidget);
    });
  });
}
