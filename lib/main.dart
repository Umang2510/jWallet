import 'package:material_ui/material_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app/app.dart';
import 'app/di.dart';
import 'app/session/session_cubit.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  LicenseRegistry.addLicense(() async* {
    for (final family in ['Geist', 'SpaceGrotesk']) {
      final license = await rootBundle.loadString(
        'assets/fonts/$family-OFL.txt',
      );
      yield LicenseEntryWithLineBreaks([family], license);
    }
  });
  setupDependencies();
  // Check for a saved session while the splash screen shows.
  sl<SessionCubit>().start();
  runApp(const JWalletApp());
}
