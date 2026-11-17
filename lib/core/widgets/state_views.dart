import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/app_colors.dart';

/// Centered spinner for loading states.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator());
}

/// Error message with an optional Retry button.
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return _Message(
      icon: Icons.error_outline,
      iconColor: AppColors.error,
      message: message,
      action: onRetry == null
          ? null
          : OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
    );
  }
}

/// Friendly message when a list has nothing to show.
class EmptyView extends StatelessWidget {
  const EmptyView({super.key, required this.message, this.icon});

  final String message;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => _Message(
    icon: icon ?? Icons.inbox_outlined,
    iconColor: AppColors.textSecondary,
    message: message,
  );
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.iconColor,
    required this.message,
    this.action,
  });

  final IconData icon;
  final Color iconColor;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.r),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48.dm, color: iconColor),
            SizedBox(height: 12.h),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (action != null) ...[
              SizedBox(height: 16.h),
              SizedBox(width: 160.w, child: action),
            ],
          ],
        ),
      ),
    );
  }
}
