import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';
import 'package:material_ui/material_ui.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/home_models.dart';

/// "My QR" bottom sheet. The code is for display only: it encodes a UPI-style
/// link built from the wallet id, but nothing scans or pays through it here.
class DemoQrSheet extends StatelessWidget {
  const DemoQrSheet({super.key, required this.profile, required this.wallet});

  final UserProfile profile;
  final WalletBalance wallet;

  static Future<void> show(
    BuildContext context, {
    required UserProfile profile,
    required WalletBalance wallet,
  }) => showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    showDragHandle: true,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
    ),
    builder: (_) => DemoQrSheet(profile: profile, wallet: wallet),
  );

  String get payload =>
      'upi://pay?pa=${wallet.walletId.toLowerCase()}@jwallet'
      '&pn=${Uri.encodeComponent(profile.name)}&cu=${wallet.currency}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(24.w, 0, 24.w, 24.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('MY QR', style: theme.textTheme.titleLarge),
            SizedBox(height: 4.h),
            Text(
              'Show this code to receive money',
              style: theme.textTheme.bodySmall,
            ),
            SizedBox(height: 20.h),
            Semantics(
              label: 'Demo QR code for ${profile.name}',
              image: true,
              child: Container(
                padding: EdgeInsets.all(8.r),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: QrImageView(
                  data: payload,
                  size: 220.r.clamp(180, 260),
                  backgroundColor: Colors.white,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: AppColors.tertiary,
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: AppColors.tertiary,
                  ),
                ),
              ),
            ),
            SizedBox(height: 16.h),
            Text(
              profile.name,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(wallet.cardMask, style: theme.textTheme.bodySmall),
            SizedBox(height: 14.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 5.h),
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(
                  color: AppColors.secondary.withValues(alpha: 0.5),
                ),
              ),
              child: Text(
                'DEMO QR  ·  FOR DISPLAY ONLY',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.secondary,
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
