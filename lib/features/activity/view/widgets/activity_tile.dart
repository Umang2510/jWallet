import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../home/data/home_models.dart';

/// "TODAY, 17 NOV 2026 ........ 2 txns"
class ActivityDayHeader extends StatelessWidget {
  const ActivityDayHeader({super.key, required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
      fontSize: 11.sp,
      letterSpacing: 1.2,
      fontWeight: FontWeight.w600,
    );
    return Container(
      width: double.infinity,
      color: AppColors.surface,
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: style?.copyWith(color: AppColors.textPrimary),
            ),
          ),
          Text('$count ${count == 1 ? 'txn' : 'txns'}', style: style),
        ],
      ),
    );
  }
}

/// One transaction row. Tap opens its details.
class ActivityTile extends StatelessWidget {
  const ActivityTile({super.key, required this.item, required this.onTap});

  final TransactionItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final credit = item.isCredit;
    final amount = '${credit ? '+' : '-'}${Formatters.inr(item.amount)}';
    final (statusLabel, statusIcon, statusColor) = switch (item.status) {
      TransactionStatus.success => (
        credit ? 'Credited' : 'Settled',
        credit ? Icons.south : Icons.check_circle_outline,
        credit ? AppColors.debit : AppColors.textSecondary,
      ),
      TransactionStatus.pending => (
        'Pending',
        Icons.schedule,
        AppColors.secondary,
      ),
      TransactionStatus.failed => (
        'Failed',
        Icons.error_outline,
        AppColors.error,
      ),
    };
    final time = Formatters.clock(item.createdAt);
    return Semantics(
      button: true,
      label:
          '${item.counterparty}, ${credit ? 'received' : 'sent'} $amount, '
          '${statusLabel.toLowerCase()}, $time. Opens details.',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
          child: Row(
            children: [
              Container(
                width: 46.r,
                height: 46.r,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: credit
                      ? AppColors.secondary.withValues(alpha: 0.22)
                      : AppColors.surfaceRaised,
                  borderRadius: BorderRadius.circular(4.r),
                ),
                child: Text(
                  Formatters.initials(item.counterparty),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: credit ? AppColors.secondary : AppColors.primary,
                  ),
                ),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.counterparty,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      '${credit ? 'Received' : 'Sent'}  ·  $time',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      'Ref: ${item.id}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 10.sp,
                        color: AppColors.textSecondary.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 10.w),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 140.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        amount,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.4,
                          color: credit
                              ? AppColors.debit
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 13.r, color: statusColor),
                        SizedBox(width: 4.w),
                        Text(
                          statusLabel,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: statusColor,
                            fontSize: 11.sp,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
