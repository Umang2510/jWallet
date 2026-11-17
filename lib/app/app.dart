import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../core/theme/app_theme.dart';
import '../core/widgets/responsive_app.dart';
import 'di.dart';
import 'session/session_cubit.dart';

/// Root widget: responsive sizing (ScreenUtil), app-wide session state and
/// the router.
class JWalletApp extends StatelessWidget {
  const JWalletApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: sl<SessionCubit>(),
      child: ResponsiveApp(
        builder: (context, _) => MaterialApp.router(
          title: 'jWallet Lite',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark(),
          routerConfig: sl<GoRouter>(),
        ),
      ),
    );
  }
}
