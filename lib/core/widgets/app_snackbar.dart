import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/app_colors.dart';

/// App-wide snackbars. Server failures are shown with the API's own
/// `meta.message`; client-side validation stays inline under the field.
abstract final class AppSnackbar {
  /// Attached to MaterialApp so messages can be shown without a BuildContext
  /// (for example when a session expires in the background).
  static final messengerKey = GlobalKey<ScaffoldMessengerState>();

  static void show(
    BuildContext context,
    String message, {
    bool isError = false,
  }) => _show(ScaffoldMessenger.of(context), message, isError);

  static void showGlobal(String message, {bool isError = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final messenger = messengerKey.currentState;
      if (messenger != null) _show(messenger, message, isError);
    });
  }

  static void _show(
    ScaffoldMessengerState messenger,
    String message,
    bool isError,
  ) {
    final accent = isError ? AppColors.error : AppColors.credit;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.surfaceRaised,
          margin: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
            side: BorderSide(color: accent.withValues(alpha: 0.5)),
          ),
          duration: const Duration(seconds: 4),
          content: Semantics(
            liveRegion: true,
            child: Row(
              children: [
                Icon(
                  isError ? Icons.error_outline : Icons.check_circle_outline,
                  color: accent,
                  size: 20.r,
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Text(
                    message,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13.sp,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
  }
}
