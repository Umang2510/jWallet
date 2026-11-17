import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/pin_keypad.dart';
import '../data/transfer_models.dart';
import '../view_model/send_money_cubit.dart';
import 'widgets/amount_card.dart';
import 'widgets/quick_amounts.dart';
import 'widgets/recipient_sheet.dart';
import 'widgets/remarks_field.dart';

/// Amount, recipient and note. Review hands the finished draft to the
/// approval screen. Fits the screen without scrolling; the keypad takes
/// whatever height is left.
class SendMoneyScreen extends StatefulWidget {
  const SendMoneyScreen({super.key, required this.onReview});

  final ValueChanged<TransferDraft> onReview;

  @override
  State<SendMoneyScreen> createState() => _SendMoneyScreenState();
}

class _SendMoneyScreenState extends State<SendMoneyScreen> {
  static const _minKeypadHeight = 4 * 40.0 + 3 * 5.0;

  @override
  void initState() {
    super.initState();
    // Opened without a recipient (Send, or "New"): ask who to pay first.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && context.read<SendMoneyCubit>().state.recipient == null) {
        _chooseRecipient();
      }
    });
  }

  Future<void> _chooseRecipient() async {
    final cubit = context.read<SendMoneyCubit>();
    final picked = await RecipientSheet.show(context);
    if (picked != null) cubit.setRecipient(picked);
  }

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<SendMoneyCubit, SendMoneyState>(
        listenWhen: (previous, current) =>
            current.message != null && current.failureId != previous.failureId,
        listener: (context, state) =>
            AppSnackbar.show(context, state.message!, isError: true),
        builder: (context, state) => MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.2,
          child: Scaffold(
            appBar: _buildAppBar(context),
            body: SafeArea(child: _buildBody(context, state)),
          ),
        ),
      );

  PreferredSizeWidget _buildAppBar(BuildContext context) => AppBar(
    automaticallyImplyLeading: false,
    leading: Semantics(
      label: 'Back',
      button: true,
      excludeSemantics: true,
      child: IconButton(
        onPressed: () => Navigator.of(context).maybePop(),
        icon: const Icon(Icons.arrow_back),
      ),
    ),
    title: Text(
      'SEND MONEY',
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        fontSize: 16.sp,
        letterSpacing: 0.6,
      ),
    ),
    // Profile is UI only for now.
    actions: [
      Padding(
        padding: EdgeInsets.only(right: 20.w),
        child: Container(
          width: 38.r,
          height: 38.r,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Icon(
            Icons.person_outline,
            color: AppColors.surface,
            size: 21.r,
          ),
        ),
      ),
    ],
  );

  Widget _buildBody(BuildContext context, SendMoneyState state) {
    final cubit = context.read<SendMoneyCubit>();
    final draft = state.draft;
    return CustomScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20.w.clamp(16, 36),
                  4.h,
                  20.w.clamp(16, 36),
                  12.h,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AmountCard(
                      amount: state.amount,
                      balance: state.balance,
                      balanceStatus: state.balanceStatus,
                      validation: state.validation,
                      recipient: state.recipient,
                      onChangeRecipient: _chooseRecipient,
                    ),
                    SizedBox(height: 10.h),
                    QuickAmounts(
                      currentValue: state.amount.value,
                      maxValue: state.maxSendable,
                      onAdd: cubit.add,
                      onSet: cubit.set,
                      onMax: cubit.max,
                    ),
                    SizedBox(height: 8.h),
                    RemarksField(onChanged: cubit.setRemarks),
                    SizedBox(height: 10.h),
                    Expanded(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          minHeight: _minKeypadHeight,
                        ),
                        child: PinKeypad(
                          showDecimal: true,
                          onDigit: cubit.press,
                          onDelete: cubit.backspace,
                        ),
                      ),
                    ),
                    SizedBox(height: 12.h),
                    AppButton(
                      label: 'REVIEW TRANSFER',
                      icon: Icons.arrow_forward,
                      onPressed: draft == null
                          ? null
                          : () => widget.onReview(draft),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
