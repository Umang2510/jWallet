import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:j_wallet/core/theme/app_theme.dart';
import 'package:j_wallet/core/widgets/pin_keypad.dart';
import 'package:j_wallet/core/widgets/pin_screen_layout.dart';
import 'package:j_wallet/core/widgets/responsive_app.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  setUpAll(() async {
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<void> show(
    WidgetTester tester,
    Size size, {
    double textScale = 1,
    PinPurpose purpose = PinPurpose.transaction,
    bool withPanel = false,
    // Real screens show one of these, never both: the create step has the
    // "Use a 6-digit PIN" hint, the unlock screen has the sign-out link.
    bool withHint = true,
    bool withSecondary = false,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ResponsiveApp(
        builder: (context, _) => MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: PinScreenLayout(
            purpose: purpose,
            step: 'STEP 1 OF 2  ·  CREATE PIN',
            title: 'Create your PIN',
            subtitle:
                'Choose a 4-digit PIN. You will enter it to approve every '
                'transfer.',
            entered: 2,
            dotLength: 4,
            message: 'PIN must be 4 or 6 digits',
            onDigit: (_) {},
            onDelete: () {},
            panel: withPanel
                ? const PinPanel(
                    purpose: PinPurpose.transaction,
                    icon: Icons.fingerprint,
                    text: 'Your fingerprint and face data never leave this '
                        'phone.',
                  )
                : null,
            hintLabel: withHint ? 'Use a 6-digit PIN' : null,
            secondaryLabel: withSecondary ? 'SIGN OUT' : null,
            onBack: () {},
            primaryLabel: 'CONTINUE',
            onPrimary: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(() => GoogleFonts.pendingFonts());
    await tester.pumpAndSettle();
  }

  double scrollExtent(WidgetTester tester) => tester
      .state<ScrollableState>(find.byType(Scrollable).first)
      .position
      .maxScrollExtent;

  // Common phones, small to large, plus a tablet.
  const phones = {
    'small 360x640': Size(360, 640),
    'iPhone SE 375x667': Size(375, 667),
    'standard 375x812': Size(375, 812),
    'Pixel 393x851': Size(393, 851),
    'large 412x915': Size(412, 915),
    'tablet 768x1024': Size(768, 1024),
  };

  for (final entry in phones.entries) {
    testWidgets('fits ${entry.key} without scrolling', (tester) async {
      await show(tester, entry.value);
      expect(tester.takeException(), isNull);
      expect(scrollExtent(tester), 0, reason: 'screen must not scroll');
      // The action button and every key stay on screen and tappable.
      expect(
        tester.getRect(find.text('CONTINUE')).bottom,
        lessThanOrEqualTo(entry.value.height),
      );
      expect(
        tester.getSize(find.byType(PinKeypad)).height,
        greaterThanOrEqualTo(4 * 40.0),
        reason: 'keys need a comfortable touch size',
      );
    });
  }

  for (final entry in phones.entries) {
    testWidgets('unlock screen (sign-out link) fits ${entry.key}', (
      tester,
    ) async {
      await show(
        tester,
        entry.value,
        purpose: PinPurpose.appLock,
        withHint: false,
        withSecondary: true,
      );
      expect(tester.takeException(), isNull);
      expect(scrollExtent(tester), 0, reason: 'screen must not scroll');
    });
  }

  testWidgets('still fits at 1.3x text size on a standard phone', (tester) async {
    await show(tester, const Size(375, 812), textScale: 1.3);
    expect(tester.takeException(), isNull);
    expect(scrollExtent(tester), 0);
  });

  testWidgets('a very short screen scrolls instead of overflowing', (tester) async {
    await show(tester, const Size(320, 480), textScale: 1.3);
    expect(tester.takeException(), isNull);
    expect(scrollExtent(tester), greaterThan(0));
  });

  testWidgets('the fingerprint panel step fits too', (tester) async {
    await show(
      tester,
      const Size(360, 640),
      withPanel: true,
      withHint: false,
      withSecondary: true,
    );
    expect(tester.takeException(), isNull);
    expect(scrollExtent(tester), 0);
  });

  testWidgets('app lock and transaction PIN are visibly different', (tester) async {
    await show(tester, const Size(375, 812), purpose: PinPurpose.appLock);
    expect(find.text('APP LOCK'), findsOneWidget);
    expect(find.text('OPENS THE APP'), findsOneWidget);
    expect(find.text('TRANSACTION PIN'), findsNothing);

    await show(tester, const Size(375, 812), purpose: PinPurpose.transaction);
    await tester.pumpAndSettle();
    expect(find.text('TRANSACTION PIN'), findsOneWidget);
    expect(find.text('APPROVES TRANSFERS'), findsOneWidget);
    expect(find.text('APP LOCK'), findsNothing);
  });
}
