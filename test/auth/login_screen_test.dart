import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:j_wallet/app/session/session_cubit.dart';
import 'package:j_wallet/app/session/session_state.dart';
import 'package:j_wallet/core/network/api_exception.dart';
import 'package:j_wallet/core/theme/app_theme.dart';
import 'package:j_wallet/core/widgets/responsive_app.dart';
import 'package:j_wallet/features/auth/data/auth_repository.dart';
import 'package:j_wallet/features/auth/view/login_screen.dart';
import 'package:j_wallet/features/auth/view_model/login_cubit.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository repository;
  late LoginCubit login;
  late SessionCubit session;
  final previewKey = GlobalKey();

  setUpAll(() async {
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });

  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    repository = MockAuthRepository();
    when(() => repository.expired).thenAnswer((_) => const Stream.empty());
    login = LoginCubit(repository);
    session = SessionCubit(repository);
  });
  tearDown(() async {
    await login.close();
    await session.close();
  });

  Future<void> showLogin(
    WidgetTester tester, {
    Size size = const Size(375, 900),
    double textScale = 1,
    double keyboard = 0,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider.value(value: login),
          BlocProvider.value(value: session),
        ],
        child: ResponsiveApp(
          builder: (context, _) => MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.dark(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            ),
            home: RepaintBoundary(key: previewKey, child: const LoginScreen()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(() => GoogleFonts.pendingFonts());
    await tester.pumpAndSettle();
  }

  Future<void> tapSignIn(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Sign in'));
    await tester.tap(find.text('Sign in'));
    await tester.pump();
  }

  testWidgets(
    'invalid form never calls the API and password toggles visibility',
    (tester) async {
      await showLogin(tester);
      await tapSignIn(tester);
      expect(find.text('Email is required'), findsOneWidget);
      expect(find.text('Password is required'), findsOneWidget);
      verifyNever(
        () => repository.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'secret');
      expect(
        tester.widget<TextField>(find.byType(TextField).at(1)).obscureText,
        isTrue,
      );
      await tester.tap(find.byTooltip('Show password'));
      await tester.pump();
      expect(
        tester.widget<TextField>(find.byType(TextField).at(1)).obscureText,
        isFalse,
      );
    },
  );

  testWidgets('shows loading, API failure, and permits successful retry', (
    tester,
  ) async {
    final pending = Completer<AuthResult>();
    when(
      () => repository.login(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) => pending.future);
    await showLogin(tester);
    await tester.enterText(find.byType(TextFormField).at(0), 'demo@jstack.co');
    await tester.enterText(find.byType(TextFormField).at(1), 'wrong');
    await tapSignIn(tester);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    pending.completeError(
      const ApiException('Invalid email or password', statusCode: 401),
    );
    await tester.pumpAndSettle();
    expect(find.text('Invalid email or password'), findsOneWidget);
    when(
      () => repository.login(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async => const AuthResult(pinSet: false));
    await tapSignIn(tester);
    await tester.pumpAndSettle();
    expect(session.state.status, SessionStatus.authenticated);
    expect(session.state.pinSet, isFalse);
  });

  for (final size in [
    const Size(320, 568),
    const Size(375, 900),
    const Size(844, 390),
    const Size(768, 1024),
  ]) {
    testWidgets(
      'layout stays usable at $size with enlarged text and keyboard',
      (tester) async {
        await showLogin(tester, size: size, textScale: 1.8, keyboard: 180);
        await tapSignIn(tester);
        expect(find.text('Email is required'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('renders the branded login preview', (tester) async {
    await showLogin(tester);
    expect(find.text('Your money.\nYour rhythm.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    if (const bool.fromEnvironment('CAPTURE_LOGIN')) {
      final boundary =
          previewKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory('build/previews').create(recursive: true);
        await File('build/previews/login.png')
            .writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
    }
  });
}
