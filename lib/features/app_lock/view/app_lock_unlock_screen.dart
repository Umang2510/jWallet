import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/session/session_cubit.dart';
import '../../../core/widgets/pin_screen_layout.dart';
import '../data/app_lock_repository.dart';
import '../view_model/app_lock_cubit.dart';

/// The lock screen. Phones with a screen lock open the system prompt
/// (fingerprint, face or the phone's own PIN); phones without one use the
/// app lock PIN.
class AppLockUnlockScreen extends StatefulWidget {
  const AppLockUnlockScreen({super.key});

  @override
  State<AppLockUnlockScreen> createState() => _AppLockUnlockScreenState();
}

class _AppLockUnlockScreenState extends State<AppLockUnlockScreen> {
  @override
  void initState() {
    super.initState();
    // Ask straight away; the Unlock button is there if the prompt is dismissed.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AppLockCubit>().unlockWithDevice();
    });
  }

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<AppLockCubit, AppLockState>(builder: _build);

  Widget _build(BuildContext context, AppLockState state) {
    final cubit = context.read<AppLockCubit>();
    if (state.method == AppLockMethod.deviceLock) {
      return PinScreenLayout(
        purpose: PinPurpose.appLock,
        step: 'LOCKED',
        title: 'Welcome back',
        subtitle: 'jWallet is locked to keep your money safe.',
        panel: PinPanel(
          purpose: PinPurpose.appLock,
          icon: Icons.lock_outline,
          text: state.message ??
              'Use your fingerprint, face or phone PIN to open jWallet.',
        ),
        busy: state.busy,
        primaryLabel: 'UNLOCK',
        primaryIcon: Icons.lock_open,
        onPrimary: cubit.unlockWithDevice,
        secondaryLabel: 'SIGN OUT',
        onSecondary: () => context.read<SessionCubit>().logout(),
      );
    }
    return PinScreenLayout(
      purpose: PinPurpose.appLock,
      step: 'LOCKED',
      title: 'Enter your lock PIN',
      subtitle: 'Enter the ${state.pinLength}-digit PIN you set to open jWallet.',
      entered: state.entered,
      dotLength: state.pinLength,
      message: state.message,
      onDigit: cubit.digit,
      onDelete: cubit.backspace,
      busy: state.busy,
      primaryLabel: 'UNLOCK',
      primaryIcon: Icons.lock_open,
      onPrimary: cubit.unlockWithPin,
      secondaryLabel: 'FORGOT PIN? SIGN OUT',
      onSecondary: () => context.read<SessionCubit>().logout(),
    );
  }
}
