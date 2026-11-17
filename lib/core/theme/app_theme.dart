import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';

import 'app_colors.dart';

abstract final class AppTheme {
  /// Build inside ScreenUtilPlusInit so all sizing extensions are ready.
  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      brightness: Brightness.dark,
      seedColor: AppColors.secondary,
      primary: AppColors.primary,
      onPrimary: AppColors.surface,
      secondary: AppColors.secondary,
      onSecondary: AppColors.surface,
      tertiary: AppColors.tertiary,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      error: AppColors.error,
    );
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    final body = GoogleFonts.geistTextTheme(base.textTheme);
    final heading = GoogleFonts.spaceGroteskTextTheme(base.textTheme);
    final radius = BorderRadius.circular(12.r);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      textTheme: body.copyWith(
        displaySmall: heading.displaySmall?.copyWith(
          fontSize: 42.sp,
          height: 1.08,
          letterSpacing: -1.8,
        ),
        headlineMedium: heading.headlineMedium?.copyWith(
          fontSize: 30.sp,
          fontWeight: FontWeight.w500,
          letterSpacing: -1,
        ),
        titleLarge: heading.titleLarge?.copyWith(fontSize: 22.sp),
        titleMedium: heading.titleMedium?.copyWith(fontSize: 16.sp),
        bodyLarge: body.bodyLarge?.copyWith(fontSize: 16.sp),
        bodyMedium: body.bodyMedium?.copyWith(fontSize: 14.sp, height: 1.5),
        bodySmall: body.bodySmall?.copyWith(
          fontSize: 12.sp,
          color: AppColors.textSecondary,
          height: 1.5,
        ),
        labelLarge: body.labelLarge?.copyWith(
          fontSize: 14.sp,
          fontWeight: FontWeight.w600,
        ),
      ),
      appBarTheme: const AppBarThemeData(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.primary,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: AppColors.surfaceRaised,
        hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 14.sp),
        prefixIconColor: AppColors.textSecondary,
        suffixIconColor: AppColors.textSecondary,
        contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 17.h),
        border: OutlineInputBorder(
          borderRadius: radius,
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: const BorderSide(color: AppColors.secondary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        errorMaxLines: 3,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: Size(double.infinity, 54.h.clamp(48, 64)),
          shape: RoundedRectangleBorder(borderRadius: radius),
          textStyle: body.labelLarge?.copyWith(
            fontSize: 15.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: Size(double.infinity, 54.h.clamp(48, 64)),
          shape: RoundedRectangleBorder(borderRadius: radius),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
