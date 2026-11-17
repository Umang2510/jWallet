import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/session/session_cubit.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/pin_screen_layout.dart';
import '../view_model/biometric_setup_cubit.dart';

/// Offered after a password login on a phone that has a transaction PIN but
/// no biometrics yet. One PIN entry confirms it; the first-time PIN flow
/// enables biometrics itself, without asking for the PIN again.
class BiometricSetupScreen extends StatefulWidget {
  const BiometricSetupScreen({super.key});

  @override
  State<BiometricSetupScreen> createState() => _BiometricSetupScreenState();
}

class _BiometricSetupScreenState extends State<BiometricSetupScreen>
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
      context.read<BiometricSetupCubit>().clearInput();
    }
  }

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<BiometricSetupCubit, BiometricSetupState>(
        listener: _onState,
        builder: (context, state) => PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && !state.busy) _skip();
          },
          child: _buildLayout(state),
        ),
      );

  Widget _buildLayout(BiometricSetupState state) {
    final cubit = context.read<BiometricSetupCubit>();
    const step = 'OPTIONAL';
    if (state.checking) {
      return const PinScreenLayout(
        purpose: PinPurpose.transaction,
        step: step,
        title: 'Approve with biometrics',
        subtitle: 'Checking what this phone supports...',
        panel: Center(child: CircularProgressIndicator()),
        primaryLabel: 'ENABLE BIOMETRICS',
        primaryIcon: Icons.fingerprint,
        onPrimary: null,
      );
    }
    if (!state.available) {
      return PinScreenLayout(
        purpose: PinPurpose.transaction,
        step: step,
        title: 'Biometrics are not ready',
        subtitle: 'You can keep approving transfers with your PIN.',
        panel: const PinPanel(
          purpose: PinPurpose.transaction,
          icon: Icons.fingerprint,
          text: 'Add a fingerprint or face in your phone settings, then '
              'check again.',
        ),
        onBack: _skip,
        primaryLabel: 'CHECK AGAIN',
        primaryIcon: Icons.refresh,
        onPrimary: cubit.checkAvailability,
        secondaryLabel: 'NOT NOW',
        onSecondary: _skip,
      );
    }
    return PinScreenLayout(
      purpose: PinPurpose.transaction,
      step: step,
      title: 'Enter your PIN',
      subtitle: 'Confirm your transaction PIN, then approve with your '
          'fingerprint or face.',
      entered: state.entered,
      message: state.validation,
      onDigit: cubit.digit,
      onDelete: cubit.backspace,
      keypadEnabled: !state.locked,
      busy: state.busy,
      onBack: _skip,
      primaryLabel: 'ENABLE BIOMETRICS',
      primaryIcon: Icons.fingerprint,
      onPrimary: state.locked ? null : cubit.enroll,
      secondaryLabel: 'NOT NOW',
      onSecondary: _skip,
    );
  }

  void _skip() =>
      context.read<SessionCubit>().biometricSetupFinished(enrolled: false);

  void _onState(BuildContext context, BiometricSetupState state) {
    final message = state.message;
    if (state.code == 'REAUTH_REQUIRED' && message != null) {
      context.read<SessionCubit>().requireSignIn(message);
    } else if (message != null) {
      // The API's meta.message, e.g. "Incorrect PIN. 2 attempts left."
      AppSnackbar.show(context, message, isError: true);
    }
    if (state.complete) {
      AppSnackbar.show(context, 'Biometric approval enabled.');
      context.read<SessionCubit>().biometricSetupFinished(enrolled: true);
    }
  }
}
