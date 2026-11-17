import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';

/// Shown while the app checks for a saved session. Navigation away from it
/// is automatic (router redirect when the session state changes).
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72.dm,
              height: 72.dm,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: Icon(
                Icons.account_balance_wallet_rounded,
                size: 40.dm,
                color: AppColors.tertiary,
              ),
            ),
            SizedBox(height: 16.h),
            Text(
              'jWallet Lite',
              style: TextStyle(
                color: Colors.white,
                fontSize: 26.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 32.h),
            SizedBox.square(
              dimension: 24.r,
              child: const CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
