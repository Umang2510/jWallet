import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../core/theme/app_theme.dart';
import '../core/widgets/app_snackbar.dart';
import '../core/widgets/responsive_app.dart';
import '../features/app_lock/view/app_lock_gate.dart';
import '../features/app_lock/view_model/app_lock_cubit.dart';
import 'di.dart';
import 'session/session_cubit.dart';

/// Root widget: responsive sizing (ScreenUtil), app-wide session state and
/// the router.
class JWalletApp extends StatelessWidget {
  const JWalletApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: sl<SessionCubit>()),
        BlocProvider.value(value: sl<AppLockCubit>()),
      ],
      child: ResponsiveApp(
        builder: (context, _) => MaterialApp.router(
          title: 'jWallet Lite',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark(),
          scaffoldMessengerKey: AppSnackbar.messengerKey,
          routerConfig: sl<GoRouter>(),
          builder: (context, child) => AppLockGate(child: child!),
        ),
      ),
    );
  }
}
