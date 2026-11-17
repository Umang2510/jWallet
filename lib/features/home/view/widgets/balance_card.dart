import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/utils/formatters.dart';
import '../../data/home_models.dart';

/// Brand-gradient balance card with the Send / Add money / History actions.
class BalanceCard extends StatelessWidget {
  const BalanceCard({
    super.key,
    required this.profile,
    required this.wallet,
    required this.onScan,
    required this.onSend,
    required this.onAddMoney,
    required this.onHistory,
  });

  final UserProfile profile;
  final WalletBalance wallet;
  final VoidCallback onScan;
  final VoidCallback onSend;
  final VoidCallback onAddMoney;
  final VoidCallback onHistory;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(8.r),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(20.r),
            decoration: const BoxDecoration(gradient: AppGradients.hero),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(theme),
                SizedBox(height: 44.h),
                Text(
                  'AVAILABLE BALANCE  ·  ${wallet.currency}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.surface.withValues(alpha: 0.7),
                    fontSize: 11.sp,
                    letterSpacing: 1,
                  ),
                ),
                SizedBox(height: 4.h),
                _buildAmount(theme),
              ],
            ),
          ),
          Container(
            color: AppColors.primary,
            padding: EdgeInsets.symmetric(vertical: 14.h),
            child: Row(
              children: [
                _Action(
                  icon: Icons.north_east,
                  label: 'Send',
                  onTap: onSend,
                ),
                _Action(
                  icon: Icons.add_card_outlined,
                  label: 'Add money',
                  caption: 'Demo only',
                  dimmed: true,
                  onTap: onAddMoney,
                ),
                _Action(
                  icon: Icons.history,
                  label: 'History',
                  onTap: onHistory,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) => Row(
    children: [
      Container(
        width: 44.r,
        height: 44.r,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.tertiary,
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Text(
          profile.initials,
          style: theme.textTheme.titleMedium?.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      SizedBox(width: 12.w),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              profile.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppColors.surface,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              wallet.cardMask,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.surface.withValues(alpha: 0.65),
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
      Semantics(
        label: 'Show my demo QR code',
        button: true,
        excludeSemantics: true,
        child: InkResponse(
          onTap: onScan,
          radius: 24.r,
          child: Padding(
            padding: EdgeInsets.all(6.r),
            child: Icon(
              Icons.qr_code_scanner,
              color: AppColors.primary,
              size: 26.r,
            ),
          ),
        ),
      ),
      SizedBox(width: 6.w),
      Padding(
        padding: EdgeInsets.all(6.r),
        child: Icon(
          Icons.hexagon_outlined,
          color: AppColors.primary,
          size: 26.r,
        ),
      ),
    ],
  );

  Widget _buildAmount(ThemeData theme) {
    final parts = Formatters.inr(wallet.availableBalance).split('.');
    final whole = theme.textTheme.displaySmall?.copyWith(
      fontSize: 44.sp,
      color: AppColors.surface,
      letterSpacing: -2,
    );
    return Semantics(
      label: 'Available balance ${Formatters.inr(wallet.availableBalance)}',
      excludeSemantics: true,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(text: parts.first, style: whole),
              if (parts.length > 1)
                TextSpan(
                  text: '.${parts.last}',
                  style: whole?.copyWith(
                    fontSize: 26.sp,
                    letterSpacing: -1,
                    color: AppColors.surface.withValues(alpha: 0.55),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.label,
    required this.onTap,
    this.caption,
    this.dimmed = false,
  });

  final IconData icon;
  final String label;
  final String? caption;
  final bool dimmed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = dimmed
        ? AppColors.surface.withValues(alpha: 0.5)
        : AppColors.surface;
    return Expanded(
      child: Semantics(
        button: true,
        label: caption == null ? label : '$label, $caption',
        excludeSemantics: true,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 4.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: 24.r),
                SizedBox(height: 6.h),
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (caption != null)
                  Text(
                    caption!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: color,
                      fontSize: 9.sp,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
