import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:j_wallet/app/session/session_cubit.dart';
import 'package:j_wallet/app/session/session_state.dart';
import 'package:j_wallet/core/network/api_exception.dart';
import 'package:j_wallet/core/theme/app_theme.dart';
import 'package:j_wallet/core/widgets/logout_button.dart';
import 'package:j_wallet/core/widgets/responsive_app.dart';
import 'package:j_wallet/features/auth/data/auth_repository.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository auth;
  late SessionCubit session;

  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    auth = MockAuthRepository();
    when(() => auth.expired).thenAnswer((_) => const Stream.empty());
    session = SessionCubit(auth)..loggedIn(pinSet: true);
  });
  tearDown(() => session.close());

  Future<void> show(WidgetTester tester) async {
    await tester.pumpWidget(
      BlocProvider.value(
        value: session,
        child: ResponsiveApp(
          builder: (context, _) => MaterialApp(
            theme: AppTheme.dark(),
            home: const Scaffold(body: Center(child: LogoutButton())),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(() => GoogleFonts.pendingFonts());
    await tester.pumpAndSettle();
  }

  testWidgets('it is one Log out button, not a menu', (tester) async {
    await show(tester);
    expect(find.byIcon(Icons.logout), findsOneWidget);
    expect(find.byType(PopupMenuButton), findsNothing);
    expect(find.text('Clear app storage'), findsNothing);
  });

  testWidgets('cancelling keeps you signed in', (tester) async {
    await show(tester);
    await tester.tap(find.byIcon(Icons.logout));
    await tester.pumpAndSettle();
    expect(find.text('Log out?'), findsOneWidget);
    await tester.tap(find.text('CANCEL'));
    await tester.pumpAndSettle();
    verifyNever(() => auth.logout());
    expect(session.state.isAuthenticated, isTrue);
    expect(find.text('Log out?'), findsNothing);
  });

  testWidgets('Log out calls the API, shows progress, then signs out', (
    tester,
  ) async {
    final pending = Completer<void>();
    when(() => auth.logout()).thenAnswer((_) => pending.future);
    await show(tester);
    await tester.tap(find.byIcon(Icons.logout));
    await tester.pumpAndSettle();
    await tester.tap(find.text('LOG OUT'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    // While the server is being told, a spinner blocks the screen.
    expect(find.text('Logging out…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(session.state.isAuthenticated, isTrue);
    pending.complete();
    await tester.pumpAndSettle();
    verify(() => auth.logout()).called(1);
    expect(find.text('Logging out…'), findsNothing);
    expect(session.state.status, SessionStatus.unauthenticated);
  });

  testWidgets('a failed logout call still signs out and closes the spinner', (
    tester,
  ) async {
    when(() => auth.logout()).thenThrow(
      const ApiException('Unable to connect.', notProcessed: true),
    );
    await show(tester);
    await tester.tap(find.byIcon(Icons.logout));
    await tester.pumpAndSettle();
    await tester.tap(find.text('LOG OUT'));
    await tester.pumpAndSettle();
    expect(find.text('Logging out…'), findsNothing);
    expect(session.state.status, SessionStatus.unauthenticated);
  });
}
