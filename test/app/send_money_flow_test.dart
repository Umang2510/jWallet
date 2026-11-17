import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:j_wallet/app/di.dart';
import 'package:j_wallet/app/router/app_routes.dart';
import 'package:j_wallet/app/router/app_router.dart';
import 'package:j_wallet/app/session/session_cubit.dart';
import 'package:j_wallet/core/crypto/device_keys.dart';
import 'package:j_wallet/core/events/wallet_events.dart';
import 'package:j_wallet/core/network/authenticated_client.dart';
import 'package:j_wallet/core/theme/app_theme.dart';
import 'package:j_wallet/core/widgets/responsive_app.dart';
import 'package:j_wallet/features/auth/data/auth_repository.dart';
import 'package:j_wallet/features/home/data/home_repository.dart';
import 'package:j_wallet/features/home/view/home_screen.dart';
import 'package:j_wallet/features/home/view_model/home_cubit.dart';
import 'package:j_wallet/features/transactions/data/transaction_repository.dart';
import 'package:j_wallet/features/transfer/data/transfer_repository.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../home/home_fixtures.dart';
import '../transfer/transfer_fixtures.dart';

class MockClient extends Mock implements AuthenticatedClient {}

class MockKeys extends Mock implements DeviceKeys {}

class MockAuthRepository extends Mock implements AuthRepository {}

/// The real router, real repositories and cubits; only the network is faked.
void main() {
  late MockClient client;
  late SessionCubit session;
  late WalletEvents events;
  late double balance;

  setUpAll(() async {
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });

  setUp(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await sl.reset();
    balance = 25450.75;
    client = MockClient();
    events = WalletEvents();
    final keys = MockKeys();
    final auth = MockAuthRepository();
    when(() => auth.expired).thenAnswer((_) => const Stream.empty());
    session = SessionCubit(auth);

    when(() => client.session()).thenAnswer((_) async => {'userId': 'USR1'});
    when(
      () => client.request('GET', '/api/v1/users/profile'),
    ).thenAnswer((_) async => profileJson());
    when(() => client.request('GET', '/api/v1/wallet/balance')).thenAnswer(
      (_) async => {...balanceJson(), 'availableBalance': balance},
    );
    when(
      () => client.request('GET', '/api/v1/transactions?page=1&limit=5'),
    ).thenAnswer((_) async => transactionsJson());
    when(
      () => client.request(
        'POST',
        '/api/v1/transactions/transfer/challenge',
        body: any(named: 'body'),
      ),
    ).thenAnswer((_) async => challengeJson());
    when(
      () => client.request(
        'POST',
        '/api/v1/transactions/transfer',
        body: any(named: 'body'),
        headers: any(named: 'headers'),
      ),
    ).thenAnswer((_) async {
      balance -= 1500;
      return transferJson();
    });
    when(
      () => client.request('GET', '/api/v1/transactions/TXN20261117K7Q2MX'),
    ).thenAnswer(
      (_) async => {
        'id': 'TXN20261117K7Q2MX',
        'type': 'DEBIT',
        'amount': 1500,
        'currency': 'INR',
        'beneficiaryName': 'Rahul Sharma',
        'status': 'SUCCESS',
        'createdAt': '2026-11-17T04:00:00.000Z',
        'mobileNumber': 'XXXXXX3210',
        'remarks': 'Dinner split & groceries',
      },
    );

    sl
      ..registerSingleton<WalletEvents>(events)
      ..registerSingleton<HomeRepository>(HomeRepository(client))
      ..registerSingleton<TransferRepository>(
        TransferRepository(client, keys, events),
      )
      ..registerSingleton<TransactionRepository>(TransactionRepository(client))
      ..registerFactory<HomeCubit>(
        () => HomeCubit(sl(), walletChanges: events.changes),
      );
  });
  tearDown(() async {
    await session.close();
    await sl.reset();
  });

  Future<GoRouter> launch(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(375, 812);
    addTearDown(tester.view.reset);
    final router = createRouter(session);
    await tester.pumpWidget(
      BlocProvider.value(
        value: session,
        child: ResponsiveApp(
          builder: (context, _) => MaterialApp.router(
            theme: AppTheme.dark(),
            routerConfig: router,
          ),
        ),
      ),
    );
    session.loggedIn(pinSet: true);
    await tester.pumpAndSettle();
    await tester.runAsync(() => GoogleFonts.pendingFonts());
    await tester.pumpAndSettle();
    return router;
  }

  /// Send ₹1,500 to Rahul, approve with PIN 1357, and wait for the details.
  Future<void> sendUntilDetails(WidgetTester tester) async {
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();
    expect(find.text('SEND TO'), findsOneWidget);
    await tester.tap(find.text('Rahul Sharma'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('₹1,500'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('REVIEW TRANSFER'));
    await tester.pumpAndSettle();
    expect(find.text('YOU ARE SENDING'), findsOneWidget);
    await tester.tap(find.text('ENTER PIN TO SEND'));
    await tester.pumpAndSettle();
    for (final digit in '1357'.split('')) {
      await tester.tap(find.text(digit).first);
    }
    await tester.pump();
    await tester.tap(find.text('SEND ₹1,500.00'));
    await tester.pump();
    // The light scene loops, so step through time until the details appear.
    for (var i = 0; i < 80; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.text('TRANSACTION').evaluate().isNotEmpty) break;
    }
    await tester.pumpAndSettle();
  }

  testWidgets('Home → Send → approve → processing → details → Done → Home', (
    tester,
  ) async {
    await launch(tester);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.textContaining('25,450'), findsOneWidget);

    await sendUntilDetails(tester);
    expect(find.text('TRANSACTION'), findsOneWidget);
    expect(find.text('Sent to Rahul Sharma'), findsOneWidget);
    expect(find.text('COMPLETED'), findsOneWidget);
    expect(find.text('TXN20261117K7Q2MX'), findsOneWidget);

    // The money was sent with an idempotency key and the PIN approval.
    final sent = verify(
      () => client.request(
        'POST',
        '/api/v1/transactions/transfer',
        body: captureAny(named: 'body'),
        headers: captureAny(named: 'headers'),
      ),
    ).captured;
    expect((sent[1] as Map)['Idempotency-Key'], isNotEmpty);
    expect(sent[0], containsPair('approval', {'method': 'PIN', 'pin': '1357'}));
    expect(sent[0], containsPair('mobileNumber', '9876543210'));
    expect(sent[0], containsPair('amount', 1500.0));

    await tester.tap(find.text('DONE'));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.textContaining('23,950'), findsOneWidget,
        reason: 'Home must show the balance after the transfer');
    expect(find.textContaining('25,450'), findsNothing);
  });

  testWidgets('system back from the details goes Home, not to the amount', (
    tester,
  ) async {
    await launch(tester);
    await sendUntilDetails(tester);
    expect(find.text('TRANSACTION'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('SEND MONEY'), findsNothing);
  });

  testWidgets('a Quick Send tile opens Send Money already addressed', (
    tester,
  ) async {
    await launch(tester);
    await tester.ensureVisible(find.text('Priya'));
    await tester.tap(find.text('Priya'));
    await tester.pumpAndSettle();
    expect(find.text('SEND MONEY'), findsOneWidget);
    expect(find.text('Priya Patel'), findsOneWidget);
    expect(find.text('SEND TO'), findsNothing);
  });

  testWidgets('the confirm page without a draft restarts at the amount', (
    tester,
  ) async {
    final router = await launch(tester);
    router.go(AppRoutes.transferConfirm);
    await tester.pumpAndSettle();
    expect(find.text('SEND MONEY'), findsOneWidget);
    expect(find.text('REVIEW TRANSFER'), findsOneWidget);
  });
}
