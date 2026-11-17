import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/session/session_cubit.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/pin_screen_layout.dart';
import '../view_model/pin_setup_cubit.dart';

/// Transaction PIN setup. Two PIN entries only (create + confirm); the
/// optional fingerprint step reuses the PIN already entered.
class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({super.key});

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen>
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
    if (state != AppLifecycleState.paused) return;
    // Never leave a half-typed PIN, or the confirmed one, behind.
    final cubit = context.read<PinSetupCubit>();
    cubit.restart();
    cubit.skipBiometrics();
  }

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<PinSetupCubit, PinSetupState>(
        listener: _onState,
        builder: (context, state) => PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && state.step == PinStep.confirm) {
              context.read<PinSetupCubit>().restart();
            }
          },
          child: state.step == PinStep.biometric
              ? _buildBiometric(state)
              : _buildPin(state),
        ),
      );

  Widget _buildPin(PinSetupState state) {
    final cubit = context.read<PinSetupCubit>();
    final confirming = state.step == PinStep.confirm;
    return PinScreenLayout(
      purpose: PinPurpose.transaction,
      step: confirming ? 'CONFIRM  ·  2 OF 2' : 'CREATE  ·  1 OF 2',
      title: confirming ? 'Confirm your PIN' : 'Create your PIN',
      subtitle: confirming
          ? 'Enter the same ${state.length} digits again.'
          : 'Choose a ${state.length}-digit PIN. You will enter it to approve '
                'every transfer.',
      entered: state.entered,
      dotLength: state.length,
      message: state.validation,
      onDigit: cubit.digit,
      onDelete: cubit.backspace,
      busy: state.busy,
      onBack: confirming ? cubit.restart : () => _signOut(),
      hintLabel: confirming
          ? null
          : (state.length == 4 ? 'Use a 6-digit PIN' : 'Use a 4-digit PIN'),
      onHint: () => cubit.setLength(state.length == 4 ? 6 : 4),
      primaryLabel: confirming ? 'SET PIN' : 'CONTINUE',
      onPrimary: cubit.next,
    );
  }

  Widget _buildBiometric(PinSetupState state) {
    final cubit = context.read<PinSetupCubit>();
    return PinScreenLayout(
      purpose: PinPurpose.transaction,
      step: 'OPTIONAL',
      title: 'Approve with biometrics',
      subtitle: 'Use your fingerprint or face instead of typing the PIN '
          'each time you send money.',
      panel: const PinPanel(
        purpose: PinPurpose.transaction,
        icon: Icons.fingerprint,
        text: 'Your fingerprint and face data never leave this phone. '
            'Your PIN stays available as a backup.',
      ),
      busy: state.busy,
      primaryLabel: 'ENABLE BIOMETRICS',
      primaryIcon: Icons.fingerprint,
      onPrimary: cubit.enableBiometrics,
      secondaryLabel: 'NOT NOW',
      onSecondary: cubit.skipBiometrics,
    );
  }

  void _onState(BuildContext context, PinSetupState state) {
    final message = state.message;
    if (state.code == 'REAUTH_REQUIRED' && message != null) {
      // requireSignIn shows the API message itself after returning to login.
      context.read<SessionCubit>().requireSignIn(message);
      return;
    }
    if (message != null) {
      // The API's meta.message, e.g. a rejected PIN.
      AppSnackbar.show(context, message, isError: true);
    }
    if (state.step == PinStep.complete) {
      context.read<SessionCubit>().pinCreated(
        biometricEnrolled: state.biometricEnrolled,
      );
    }
  }

  void _signOut() => context.read<SessionCubit>().logout();
}
