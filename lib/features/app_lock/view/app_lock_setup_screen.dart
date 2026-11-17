import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/widgets/pin_screen_layout.dart';
import '../view_model/app_lock_cubit.dart';
import '../view_model/app_lock_setup_cubit.dart';

/// Shown only on phones with no screen lock: a PIN of the app's own opens
/// jWallet. Phones that do have a screen lock never see this.
class AppLockSetupScreen extends StatefulWidget {
  const AppLockSetupScreen({super.key});

  @override
  State<AppLockSetupScreen> createState() => _AppLockSetupScreenState();
}

class _AppLockSetupScreenState extends State<AppLockSetupScreen>
    with WidgetsBindingObserver {
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
    if (state == AppLifecycleState.paused) {
      context.read<AppLockSetupCubit>().restart();
    }
  }

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<AppLockSetupCubit, AppLockSetupState>(
        listener: (context, state) {
          if (state.step == AppLockSetupStep.complete) {
            context.read<AppLockCubit>().setupCompleted();
          }
        },
        builder: (context, state) {
          final cubit = context.read<AppLockSetupCubit>();
          final confirming = state.step == AppLockSetupStep.confirm;
          return PinScreenLayout(
            purpose: PinPurpose.appLock,
            step: confirming ? 'CONFIRM  ·  2 OF 2' : 'CREATE  ·  1 OF 2',
            title: confirming ? 'Confirm lock PIN' : 'Set an app lock PIN',
            subtitle: confirming
                ? 'Enter the same ${state.length} digits again.'
                : 'Your phone has no screen lock, so this ${state.length}-digit '
                      'PIN will open jWallet when you come back to it.',
            entered: state.entered,
            dotLength: state.length,
            message: state.message,
            onDigit: cubit.digit,
            onDelete: cubit.backspace,
            busy: state.busy,
            onBack: confirming ? cubit.restart : null,
            hintLabel: confirming
                ? null
                : (state.length == 4 ? 'Use a 6-digit PIN' : 'Use a 4-digit PIN'),
            onHint: () => cubit.setLength(state.length == 4 ? 6 : 4),
            primaryLabel: confirming ? 'SET LOCK PIN' : 'CONTINUE',
            onPrimary: cubit.next,
          );
        },
      );
}
