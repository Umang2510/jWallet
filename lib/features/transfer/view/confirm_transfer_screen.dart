import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_gradients.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/pin_screen_layout.dart';
import '../../../core/widgets/state_views.dart';
import '../data/transfer_models.dart';
import '../view_model/transfer_cubit.dart';
import 'widgets/transfer_processing_view.dart';

/// Review, approve (fingerprint or PIN), the moving-light processing scene,
/// then on to the transaction details. One screen, driven by [TransferCubit].
class ConfirmTransferScreen extends StatefulWidget {
  const ConfirmTransferScreen({
    super.key,
    required this.draft,
    required this.onDone,
    this.successHold = const Duration(milliseconds: 750),
  });

  final TransferDraft draft;

  /// The transfer succeeded and the tick has been shown: open the details.
  final ValueChanged<TransferReceipt> onDone;

  /// How long the tick stays before the coin flies to the details screen.
  final Duration successHold;

  @override
  State<ConfirmTransferScreen> createState() => _ConfirmTransferScreenState();
}

class _ConfirmTransferScreenState extends State<ConfirmTransferScreen>
    with WidgetsBindingObserver {
  Timer? _hold;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _hold?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // A half-typed PIN never waits in memory while the app is in the background.
    if (state == AppLifecycleState.paused) {
      context.read<TransferCubit>().clearPin();
    }
  }

  void _onState(BuildContext context, TransferState state) {
    if (state.message != null) {
      AppSnackbar.show(context, state.message!, isError: true);
    }
    if (state.phase == TransferPhase.unavailable) {
      // Nothing was approved (balance, limit, ...): back to the amount.
      Navigator.of(context).maybePop();
    }
    if (state.phase == TransferPhase.success && state.receipt != null) {
      final receipt = state.receipt!;
      _hold?.cancel();
      _hold = Timer(widget.successHold, () {
        if (mounted) widget.onDone(receipt);
      });
    }
  }

  @override
  Widget build(BuildContext context) => BlocConsumer<TransferCubit, TransferState>(
    listenWhen: (previous, current) =>
        (current.message != null && current.failureId != previous.failureId) ||
        current.phase != previous.phase,
    listener: _onState,
    builder: (context, state) {
      final cubit = context.read<TransferCubit>();
      final inFlight =
          state.phase == TransferPhase.processing ||
          state.phase == TransferPhase.success;
      return PopScope(
        canPop:
            state.phase == TransferPhase.review ||
            state.phase == TransferPhase.preparing ||
            state.phase == TransferPhase.unavailable,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && state.phase == TransferPhase.pin) cubit.backToReview();
        },
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 450),
          switchInCurve: Curves.easeOut,
          child: KeyedSubtree(
            key: ValueKey(inFlight ? 'moving' : state.phase == TransferPhase.pin ? 'pin' : 'review'),
            child: switch (state.phase) {
              TransferPhase.processing || TransferPhase.success => Scaffold(
                body: TransferProcessingView(
                  amountLabel: Formatters.inr(widget.draft.amount),
                  recipientName: widget.draft.recipient.name,
                  success: state.phase == TransferPhase.success,
                ),
              ),
              TransferPhase.pin => _buildPin(context, state),
              _ => _buildReview(context, state),
            },
          ),
        ),
      );
    },
  );

  // ---- PIN ----

  Widget _buildPin(BuildContext context, TransferState state) {
    final cubit = context.read<TransferCubit>();
    final amount = Formatters.inr(widget.draft.amount);
    return PinScreenLayout(
      purpose: PinPurpose.transaction,
      step: 'APPROVE',
      title: 'Enter your PIN',
      subtitle: 'Approve sending $amount to ${widget.draft.recipient.name}.',
      entered: state.pinEntered,
      message: state.validation,
      onDigit: cubit.digit,
      onDelete: cubit.backspace,
      keypadEnabled: !state.pinLocked,
      onBack: cubit.backToReview,
      primaryLabel: 'SEND $amount',
      primaryIcon: Icons.arrow_forward,
      onPrimary: state.pinLocked ? null : cubit.submitPin,
    );
  }

  // ---- review ----

  Widget _buildReview(BuildContext context, TransferState state) {
    final theme = Theme.of(context);
    final cubit = context.read<TransferCubit>();
    final draft = widget.draft;
    final preparing = state.phase == TransferPhase.preparing ||
        state.phase == TransferPhase.unavailable;
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.2,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: Semantics(
            label: 'Back',
            button: true,
            excludeSemantics: true,
            child: IconButton(
              onPressed: state.busy ? null : () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back),
            ),
          ),
          title: Text(
            'REVIEW TRANSFER',
            style: theme.textTheme.labelLarge?.copyWith(
              fontSize: 16.sp,
              letterSpacing: 0.6,
            ),
          ),
        ),
        body: SafeArea(
          child: preparing
              ? const LoadingView()
              : CustomScrollView(
                  slivers: [
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 480),
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              20.w.clamp(16, 36),
                              6.h,
                              20.w.clamp(16, 36),
                              14.h,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildAmountCard(theme, draft),
                                SizedBox(height: 14.h),
                                _buildDetails(theme, draft, state),
                                const Spacer(),
                                SizedBox(height: 14.h),
                                _buildSecurityNote(theme),
                                SizedBox(height: 14.h),
                                ..._buildActions(state, cubit),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildAmountCard(ThemeData theme, TransferDraft draft) {
    const ink = AppColors.surface;
    final parts = Formatters.inr(draft.amount).split('.');
    final big = theme.textTheme.displaySmall?.copyWith(
      fontSize: 44.sp,
      color: ink,
      letterSpacing: -2,
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(8.r),
      child: Container(
        padding: EdgeInsets.all(20.r),
        decoration: const BoxDecoration(gradient: AppGradients.hero),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'YOU ARE SENDING',
              style: theme.textTheme.bodySmall?.copyWith(
                color: ink.withValues(alpha: 0.7),
                fontSize: 11.sp,
                letterSpacing: 1.4,
              ),
            ),
            SizedBox(height: 8.h),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: parts.first, style: big),
                    TextSpan(
                      text: '.${parts.last}',
                      style: big?.copyWith(color: ink.withValues(alpha: 0.6)),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'to ${draft.recipient.name}',
              style: theme.textTheme.titleMedium?.copyWith(
                color: ink,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetails(ThemeData theme, TransferDraft draft, TransferState state) {
    final rows = <(String, String)>[
      ('To', draft.recipient.name),
      ('Mobile', state.challenge?.maskedMobile ?? draft.recipient.displayMobile),
      ('UPI ID', draft.recipient.upiId),
      if (draft.remarks != null) ('Note', draft.remarks!),
      ('Fee', 'Zero fee'),
    ];
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 18.r, vertical: 6.r),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              Divider(height: 1, color: AppColors.border.withValues(alpha: 0.5)),
            Padding(
              padding: EdgeInsets.symmetric(vertical: 12.h),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(rows[i].$1, style: theme.textTheme.bodySmall),
                  SizedBox(width: 16.w),
                  Expanded(
                    child: Text(
                      rows[i].$2,
                      textAlign: TextAlign.end,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: rows[i].$1 == 'Fee'
                            ? AppColors.debit
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSecurityNote(ThemeData theme) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(Icons.lock_outline, size: 14.r, color: AppColors.textSecondary),
      SizedBox(width: 8.w),
      Flexible(
        child: Text(
          'You approve this with your fingerprint or PIN',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(fontSize: 11.sp),
        ),
      ),
    ],
  );

  List<Widget> _buildActions(TransferState state, TransferCubit cubit) {
    if (state.biometricAvailable) {
      return [
        AppButton(
          label: 'APPROVE WITH BIOMETRICS',
          icon: Icons.fingerprint,
          isLoading: state.busy,
          onPressed: cubit.approveWithBiometrics,
        ),
        TextButton(
          onPressed: state.busy ? null : cubit.usePin,
          style: TextButton.styleFrom(
            minimumSize: Size.fromHeight(44.h.clamp(40, 48)),
          ),
          child: const Text('USE PIN INSTEAD'),
        ),
      ];
    }
    return [
      AppButton(
        label: 'ENTER PIN TO SEND',
        icon: Icons.arrow_forward,
        onPressed: cubit.usePin,
      ),
    ];
  }
}
