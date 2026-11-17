import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/utils/formatters.dart';
import '../../data/amount_input.dart';
import '../../data/recipient.dart';
import '../../view_model/send_money_cubit.dart';

/// The brand-gradient card: amount being typed, balance, and who gets it.
class AmountCard extends StatelessWidget {
  const AmountCard({
    super.key,
    required this.amount,
    required this.balance,
    required this.balanceStatus,
    required this.validation,
    required this.recipient,
    required this.onChangeRecipient,
  });

  final AmountInput amount;
  final num? balance;
  final BalanceStatus balanceStatus;
  final String? validation;
  final Recipient? recipient;
  final VoidCallback onChangeRecipient;

  /// Dark text that stays readable on every part of the light gradient.
  static const _ink = AppColors.surface;
  static const _warning = Color(0xFFB3261E);
  static const _accent = Color(0xFF9A3F12);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(8.r),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(18.r),
        decoration: const BoxDecoration(gradient: AppGradients.hero),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTopRow(theme),
            SizedBox(height: 10.h),
            _buildAmount(theme),
            SizedBox(height: 4.h),
            _buildBalanceRow(theme),
            SizedBox(height: 10.h),
            _buildDivider(),
            SizedBox(height: 10.h),
            _buildRecipient(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildTopRow(ThemeData theme) => Row(
    children: [
      Expanded(
        child: Text(
          'SEND AMOUNT',
          style: theme.textTheme.bodySmall?.copyWith(
            color: _ink.withValues(alpha: 0.7),
            fontSize: 11.sp,
            letterSpacing: 1.4,
          ),
        ),
      ),
      Container(
        padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 4.h),
        decoration: BoxDecoration(
          color: AppColors.tertiary,
          borderRadius: BorderRadius.circular(4.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6.r,
              height: 6.r,
              decoration: const BoxDecoration(
                color: AppColors.secondary,
                shape: BoxShape.circle,
              ),
            ),
            SizedBox(width: 6.w),
            Text(
              'INR (₹)',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.primary,
                fontSize: 10.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _buildAmount(ThemeData theme) {
    final big = theme.textTheme.displaySmall?.copyWith(
      fontSize: 44.sp,
      color: _ink,
      letterSpacing: -2,
    );
    final label =
        '₹${amount.wholePart}.${amount.fractionPart}';
    return Semantics(
      label: 'Amount $label',
      liveRegion: true,
      excludeSemantics: true,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '₹',
                style: big?.copyWith(
                  fontSize: 30.sp,
                  color: _accent,
                  letterSpacing: 0,
                ),
              ),
              TextSpan(text: amount.wholePart, style: big),
              TextSpan(
                text: '.${amount.fractionPart}',
                style: big?.copyWith(
                  color: amount.isEmpty ? _ink.withValues(alpha: 0.4) : _ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBalanceRow(ThemeData theme) {
    final small = theme.textTheme.bodySmall?.copyWith(
      color: _ink.withValues(alpha: 0.75),
      fontSize: 12.sp,
    );
    final balanceText = switch (balanceStatus) {
      BalanceStatus.loading => 'Balance: …',
      BalanceStatus.failed => 'Balance: unavailable',
      BalanceStatus.ready => 'Balance: ${Formatters.inr(balance ?? 0)}',
    };
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(child: Text(balanceText, style: small)),
        SizedBox(width: 8.w),
        Semantics(
          liveRegion: true,
          child: Text(
            validation ?? 'Zero fee transfer',
            style: small?.copyWith(
              color: validation == null ? _accent : _warning,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() => Row(
    children: [
      Expanded(child: Divider(color: _ink.withValues(alpha: 0.2), height: 1)),
      Padding(
        padding: EdgeInsets.symmetric(horizontal: 8.w),
        child: Icon(Icons.arrow_downward, size: 14.r, color: _ink.withValues(alpha: 0.6)),
      ),
      Expanded(child: Divider(color: _ink.withValues(alpha: 0.2), height: 1)),
    ],
  );

  Widget _buildRecipient(ThemeData theme) {
    final r = recipient;
    return Semantics(
      button: true,
      label: r == null
          ? 'Choose a recipient'
          : 'Sending to ${r.name}. Tap to change.',
      excludeSemantics: true,
      child: Material(
        color: AppColors.primary.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(6.r),
        child: InkWell(
          borderRadius: BorderRadius.circular(6.r),
          onTap: onChangeRecipient,
          child: Padding(
            padding: EdgeInsets.all(10.r),
            child: r == null ? _buildEmptyRecipient(theme) : _buildFilled(theme, r),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyRecipient(ThemeData theme) => Row(
    children: [
      _avatar(theme, child: Icon(Icons.person_add_alt, color: AppColors.secondary, size: 20.r)),
      SizedBox(width: 12.w),
      Expanded(
        child: Text(
          'Choose who to pay',
          style: theme.textTheme.titleMedium?.copyWith(
            color: _ink,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      Icon(Icons.chevron_right, color: _ink.withValues(alpha: 0.6)),
    ],
  );

  Widget _buildFilled(ThemeData theme, Recipient r) => Row(
    children: [
      _avatar(
        theme,
        child: Text(
          r.initials,
          style: theme.textTheme.titleMedium?.copyWith(
            color: AppColors.secondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      SizedBox(width: 12.w),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flexible(
                  child: Text(
                    r.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: _ink,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (r.saved) ...[
                  SizedBox(width: 6.w),
                  Icon(Icons.verified_outlined, size: 16.r, color: _accent),
                ],
              ],
            ),
            Text(
              r.displayMobile,
              style: theme.textTheme.bodySmall?.copyWith(
                color: _ink.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
      SizedBox(width: 8.w),
      Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            'UPI ID',
            style: theme.textTheme.bodySmall?.copyWith(
              color: _ink.withValues(alpha: 0.6),
              fontSize: 9.sp,
              letterSpacing: 1,
            ),
          ),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 120.w),
            child: Text(
              r.upiId,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: _ink,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    ],
  );

  Widget _avatar(ThemeData theme, {required Widget child}) => Container(
    width: 42.r,
    height: 42.r,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: AppColors.tertiary,
      borderRadius: BorderRadius.circular(6.r),
    ),
    child: child,
  );
}
