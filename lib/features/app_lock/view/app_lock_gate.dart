import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/di.dart';
import '../../../app/session/session_cubit.dart';
import '../../../app/session/session_state.dart';
import '../../splash/view/splash_screen.dart';
import '../view_model/app_lock_cubit.dart';
import '../view_model/app_lock_setup_cubit.dart';
import 'app_lock_setup_screen.dart';
import 'app_lock_unlock_screen.dart';

/// Wraps the whole app. While the app lock has something to ask (set up, or
/// unlock) it covers everything and takes the app's content off screen. The
/// router and its pages keep their state underneath, so unlocking returns
/// the user exactly where they were.
class AppLockGate extends StatefulWidget {
  const AppLockGate({super.key, required this.child});
  final Widget child;

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final lock = context.read<AppLockCubit>();
    if (state == AppLifecycleState.paused) lock.appPaused();
    if (state == AppLifecycleState.resumed) lock.appResumed();
  }

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<SessionCubit, SessionState>(
        builder: (context, session) =>
            BlocBuilder<AppLockCubit, AppLockState>(
              builder: (context, lock) {
                // Covered from the very first frame of a ready session, so
                // the app never flashes before the lock is decided.
                final covered =
                    session.isReady && lock.status != AppLockStatus.unlocked;
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    Offstage(offstage: covered, child: widget.child),
                    if (covered) _buildCover(lock),
                  ],
                );
              },
            ),
      );

  Widget _buildCover(AppLockState lock) => switch (lock.status) {
    AppLockStatus.setupRequired => BlocProvider(
      create: (_) => sl<AppLockSetupCubit>(),
      child: const AppLockSetupScreen(),
    ),
    AppLockStatus.locked => const AppLockUnlockScreen(),
    _ => const SplashScreen(),
  };
}
