import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:j_wallet/core/network/api_exception.dart';
import 'package:j_wallet/core/theme/app_theme.dart';
import 'package:j_wallet/core/widgets/responsive_app.dart';
import 'package:j_wallet/features/home/data/home_repository.dart';
import 'package:j_wallet/features/home/view/home_screen.dart';
import 'package:j_wallet/features/home/view/widgets/demo_qr_sheet.dart';
import 'package:j_wallet/features/home/view_model/home_cubit.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'home_fixtures.dart';

class MockHomeRepository extends Mock implements HomeRepository {}

void main() {
  late MockHomeRepository repository;
  late HomeCubit cubit;
  var sent = 0;
  var openedActivity = 0;

  setUpAll(() async {
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });

  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    repository = MockHomeRepository();
    cubit = HomeCubit(repository);
    sent = 0;
    openedActivity = 0;
  });
  tearDown(() => cubit.close());

  Future<void> showHome(
    WidgetTester tester, {
    Size size = const Size(375, 812),
  }) async {
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
            home: HomeScreen(
              onSend: (_) => sent++,
              onActivity: () => openedActivity++,
            ),
          ),
        ),
      ),
    );
    await cubit.load();
    await tester.pumpAndSettle();
    await tester.runAsync(() => GoogleFonts.pendingFonts());
    await tester.pumpAndSettle();
  }

  testWidgets('shows API data: name, balance, masked account and activity', (
    tester,
  ) async {
    when(() => repository.load()).thenAnswer((_) async => demoHome());
    await showHome(tester);
    expect(find.text('HOME'), findsOneWidget);
    expect(find.text('Demo User'), findsOneWidget);
    expect(find.text('DU'), findsOneWidget);
    expect(find.text('•••• 4589'), findsOneWidget);
    expect(find.textContaining('25,450'), findsOneWidget);
    expect(find.textContaining('.75'), findsOneWidget);
    expect(find.text('Rahul Sharma'), findsOneWidget);
    expect(find.text('-₹1,500.00'), findsOneWidget);
    expect(find.text('+₹45,000.00'), findsOneWidget);
    expect(find.text('COMPLETED'), findsOneWidget);
    expect(find.text('RECEIVED'), findsOneWidget);
    expect(find.text('PENDING'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('has no monthly up/down percentage', (tester) async {
    when(() => repository.load()).thenAnswer((_) async => demoHome());
    await showHome(tester);
    expect(find.textContaining('%'), findsNothing);
    expect(find.textContaining('this month'), findsNothing);
  });

  testWidgets('Quick Send is local and always present', (tester) async {
    when(() => repository.load()).thenAnswer((_) async => demoHome());
    await showHome(tester);
    expect(find.text('QUICK SEND'), findsOneWidget);
    for (final name in ['Rahul', 'Priya', 'TechCorp', 'New']) {
      expect(find.text(name), findsOneWidget);
    }
    await tester.ensureVisible(find.text('Priya'));
    await tester.tap(find.text('Priya'));
    expect(sent, 1);
  });

  testWidgets('the scanner icon shows a demo QR code', (tester) async {
    when(() => repository.load()).thenAnswer((_) async => demoHome());
    await showHome(tester);
    expect(find.byType(QrImageView), findsNothing);
    await tester.tap(find.byIcon(Icons.qr_code_scanner));
    await tester.pumpAndSettle();
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('DEMO QR  ·  FOR DISPLAY ONLY'), findsOneWidget);
    final sheet = tester.widget<DemoQrSheet>(find.byType(DemoQrSheet));
    expect(sheet.payload, startsWith('upi://pay?pa=wallet20001@jwallet'));
    expect(sheet.payload, contains('Demo%20User'));
  });

  testWidgets('Send, History and View all go to the right place', (
    tester,
  ) async {
    when(() => repository.load()).thenAnswer((_) async => demoHome());
    await showHome(tester);
    await tester.tap(find.text('Send'));
    expect(sent, 1);
    await tester.tap(find.text('History'));
    expect(openedActivity, 1);
    await tester.ensureVisible(find.text('VIEW ALL'));
    await tester.tap(find.text('VIEW ALL'));
    expect(openedActivity, 2);
  });

  testWidgets('Add money is demo only', (tester) async {
    when(() => repository.load()).thenAnswer((_) async => demoHome());
    await showHome(tester);
    expect(find.text('Demo only'), findsOneWidget);
    await tester.tap(find.text('Add money'));
    await tester.pump();
    expect(find.text('Add money is a demo-only feature.'), findsOneWidget);
  });

  testWidgets('an empty history shows a friendly message', (tester) async {
    when(
      () => repository.load(),
    ).thenAnswer((_) async => demoHome(recent: const []));
    await showHome(tester);
    await tester.ensureVisible(find.textContaining('No transactions yet'));
    expect(find.textContaining('No transactions yet'), findsOneWidget);
  });

  testWidgets('a failed load shows the API message in a snackbar and retries', (
    tester,
  ) async {
    when(() => repository.load()).thenThrow(
      const ApiException('Wallet not found', statusCode: 404),
    );
    await showHome(tester);
    expect(find.text('Wallet not found'), findsOneWidget);
    expect(find.text('We could not load your wallet.'), findsOneWidget);
    when(() => repository.load()).thenAnswer((_) async => demoHome());
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Demo User'), findsOneWidget);
  });

  testWidgets('pull to refresh reloads the numbers', (tester) async {
    when(() => repository.load()).thenAnswer((_) async => demoHome());
    await showHome(tester);
    await tester.fling(find.byType(Scrollable).first, const Offset(0, 400), 1000);
    await tester.pumpAndSettle();
    verify(() => repository.load()).called(2);
  });

  for (final size in const [
    Size(320, 568),
    Size(360, 640),
    Size(375, 812),
    Size(412, 915),
    Size(768, 1024),
  ]) {
    testWidgets('lays out without overflow at $size', (tester) async {
      when(() => repository.load()).thenAnswer((_) async => demoHome());
      await showHome(tester, size: size);
      expect(tester.takeException(), isNull);
    });
  }
}
