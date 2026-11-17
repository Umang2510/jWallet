import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_gradients.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/state_views.dart';
import '../../home/data/home_models.dart';
import '../../transfer/view/widgets/transfer_hero_coin.dart';
import '../data/transaction_details.dart';
import '../view_model/transaction_details_cubit.dart';

/// One transaction. After a transfer the coin from the processing scene flies
/// into the status badge at the top.
class TransactionDetailsScreen extends StatelessWidget {
  const TransactionDetailsScreen({super.key, required this.onDone});

  /// Done / back: Home after a transfer, otherwise just close.
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<TransactionDetailsCubit, TransactionDetailsState>(
        listenWhen: (previous, current) =>
            current.message != null && current.failureId != previous.failureId,
        listener: (context, state) =>
            AppSnackbar.show(context, state.message!, isError: true),
        builder: (context, state) => MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.2,
          child: Scaffold(
            appBar: AppBar(
              automaticallyImplyLeading: false,
              leading: Semantics(
                label: 'Close',
                button: true,
                excludeSemantics: true,
                child: IconButton(
                  onPressed: onDone,
                  icon: const Icon(Icons.close),
                ),
              ),
              title: Text(
                'TRANSACTION',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontSize: 16.sp,
                  letterSpacing: 0.6,
                ),
              ),
            ),
            body: SafeArea(child: _buildBody(context, state)),
          ),
        ),
      );

  Widget _buildBody(BuildContext context, TransactionDetailsState state) {
    final details = state.details;
    if (details == null) {
      if (state.status == DetailsStatus.failure) {
        return ErrorView(
          message: 'We could not load this transaction.',
          onRetry: context.read<TransactionDetailsCubit>().load,
        );
      }
      return const LoadingView();
    }
    return CustomScrollView(
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
                    _SummaryCard(details: details),
                    SizedBox(height: 14.h),
                    // Appears as the page settles, after the coin has landed.
                    _SettleIn(child: _DetailsList(details: details)),
                    const Spacer(),
                    SizedBox(height: 16.h),
                    AppButton(
                      label: 'DONE',
                      icon: Icons.check,
                      onPressed: onDone,
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

/// Fades and lifts its child in alongside the page transition.
class _SettleIn extends StatelessWidget {
  const _SettleIn({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final route = ModalRoute.of(context)?.animation ?? kAlwaysCompleteAnimation;
    final curved = CurvedAnimation(
      parent: route,
      curve: const Interval(0.45, 1, curve: Curves.easeOut),
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, 0.06),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.details});
  final TransactionDetails details;

  @override
  Widget build(BuildContext context) {
    const ink = AppColors.surface;
    final theme = Theme.of(context);
    final credit = details.isCredit;
    final parts = Formatters.inr(details.amount).split('.');
    final big = theme.textTheme.displaySmall?.copyWith(
      fontSize: 42.sp,
      color: ink,
      letterSpacing: -2,
    );
    final (statusLabel, statusColor) = switch (details.status) {
      TransactionStatus.success => (
        credit ? 'RECEIVED' : 'COMPLETED',
        const Color(0xFF1F6B3A),
      ),
      TransactionStatus.pending => ('PENDING', const Color(0xFF9A3F12)),
      TransactionStatus.failed => ('FAILED', const Color(0xFFB3261E)),
    };
    return ClipRRect(
      borderRadius: BorderRadius.circular(8.r),
      child: Container(
        padding: EdgeInsets.fromLTRB(20.r, 24.r, 20.r, 22.r),
        decoration: const BoxDecoration(gradient: AppGradients.hero),
        child: Column(
          children: [
            _StatusBadge(status: details.status),
            SizedBox(height: 18.h),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: credit ? '+' : '-', style: big),
                    TextSpan(text: parts.first, style: big),
                    TextSpan(
                      text: '.${parts.last}',
                      style: big?.copyWith(color: ink.withValues(alpha: 0.6)),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              '${credit ? 'Received from' : 'Sent to'} ${details.counterparty}',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: ink,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 12.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 5.h),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: Text(
                statusLabel,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: statusColor,
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The coin (success) is the Hero target. Pending and failed get a plain badge.
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final TransactionStatus status;

  @override
  Widget build(BuildContext context) {
    if (status == TransactionStatus.success) {
      return TransferHeroCoin(size: 84.r, success: true);
    }
    final failed = status == TransactionStatus.failed;
    return Container(
      width: 84.r,
      height: 84.r,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surface,
        border: Border.all(
          color: failed ? AppColors.error : AppColors.secondary,
          width: 2,
        ),
      ),
      child: Icon(
        failed ? Icons.close_rounded : Icons.schedule,
        size: 40.r,
        color: failed ? AppColors.error : AppColors.secondary,
      ),
    );
  }
}

class _DetailsList extends StatelessWidget {
  const _DetailsList({required this.details});
  final TransactionDetails details;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rows = <_Row>[
      _Row('Date & time', Formatters.dateTime(details.createdAt)),
      _Row(details.isCredit ? 'From' : 'To', details.counterparty),
      if (details.maskedMobile != null) _Row('Mobile', details.maskedMobile!),
      if (details.remarks != null) _Row('Note', details.remarks!),
      _Row('Transaction ID', details.id, copyable: true),
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
            _buildRow(context, theme, rows[i]),
          ],
        ],
      ),
    );
  }

  Widget _buildRow(BuildContext context, ThemeData theme, _Row row) {
    final content = Padding(
      padding: EdgeInsets.symmetric(vertical: 12.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(row.label, style: theme.textTheme.bodySmall),
          SizedBox(width: 16.w),
          Expanded(
            child: Text(
              row.value,
              textAlign: TextAlign.end,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: row.copyable ? 12.sp : null,
              ),
            ),
          ),
          if (row.copyable) ...[
            SizedBox(width: 8.w),
            Icon(Icons.copy, size: 14.r, color: AppColors.textSecondary),
          ],
        ],
      ),
    );
    if (!row.copyable) return content;
    return Semantics(
      button: true,
      label: 'Copy transaction ID',
      child: InkWell(
        onTap: () async {
          await Clipboard.setData(ClipboardData(text: row.value));
          if (context.mounted) {
            AppSnackbar.show(context, 'Transaction ID copied');
          }
        },
        child: content,
      ),
    );
  }
}

class _Row {
  const _Row(this.label, this.value, {this.copyable = false});
  final String label;
  final String value;
  final bool copyable;
}
