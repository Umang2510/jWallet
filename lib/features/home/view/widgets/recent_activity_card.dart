import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../data/home_models.dart';

class RecentActivityCard extends StatelessWidget {
  const RecentActivityCard({
    super.key,
    required this.items,
    required this.onViewAll,
  });

  final List<TransactionItem> items;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'RECENT ACTIVITY',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              Semantics(
                button: true,
                label: 'View all activity',
                excludeSemantics: true,
                child: InkWell(
                  onTap: onViewAll,
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 6.h),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'VIEW ALL',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.debit,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),
                        SizedBox(width: 4.w),
                        Icon(
                          Icons.arrow_forward,
                          size: 14.r,
                          color: AppColors.debit,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          if (items.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 28.h),
              child: Text(
                'No transactions yet.\nSend money to see it here.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            )
          else
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0)
                Divider(height: 1, color: AppColors.border.withValues(alpha: 0.5)),
              TransactionTile(item: items[i]),
            ],
        ],
      ),
    );
  }
}

/// One transaction row. Also what the Activity list will reuse.
class TransactionTile extends StatelessWidget {
  const TransactionTile({super.key, required this.item});
  final TransactionItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final credit = item.isCredit;
    final amount =
        '${credit ? '+' : '-'}${Formatters.inr(item.amount)}';
    final (status, statusColor) = switch (item.status) {
      TransactionStatus.success => (
        credit ? 'RECEIVED' : 'COMPLETED',
        credit ? AppColors.debit : AppColors.textSecondary,
      ),
      TransactionStatus.pending => ('PENDING', AppColors.secondary),
      TransactionStatus.failed => ('FAILED', AppColors.error),
    };
    final when = Formatters.relativeDateTime(item.createdAt);
    return Semantics(
      label:
          '${item.counterparty}, ${credit ? 'received' : 'sent'} $amount, '
          '${status.toLowerCase()}, $when',
      excludeSemantics: true,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 14.h),
        child: Row(
          children: [
            Container(
              width: 44.r,
              height: 44.r,
              decoration: BoxDecoration(
                color: credit
                    ? AppColors.secondary.withValues(alpha: 0.22)
                    : AppColors.surfaceRaised,
                borderRadius: BorderRadius.circular(4.r),
              ),
              child: Icon(
                credit ? Icons.south_west : Icons.north_east,
                size: 20.r,
                color: credit ? AppColors.secondary : AppColors.primary,
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
                    when,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            SizedBox(width: 10.w),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  amount,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                    color: credit ? AppColors.debit : AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  status,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: statusColor,
                    fontSize: 10.sp,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
