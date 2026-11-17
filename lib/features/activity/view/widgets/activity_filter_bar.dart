import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/activity_models.dart';

/// Month, type and status chips. Month and status are applied by the server.
/// "All Types" is demo only: the API has no transaction categories.
class ActivityFilterBar extends StatelessWidget {
  const ActivityFilterBar({
    super.key,
    required this.filters,
    required this.onMonth,
    required this.onStatus,
    required this.onTypes,
    this.now,
  });

  final ActivityFilters filters;
  final ValueChanged<DateTime?> onMonth;
  final ValueChanged<StatusFilter> onStatus;
  final VoidCallback onTypes;

  /// Injectable for tests; defaults to the current time.
  final DateTime? now;

  static final _monthLabel = DateFormat('MMMM yyyy');

  @override
  Widget build(BuildContext context) {
    final today = now ?? DateTime.now();
    final months = [
      for (var i = 0; i < 12; i++) DateTime(today.year, today.month - i),
    ];
    final pendingTab = filters.tab == ActivityTab.pending;
    // Wraps onto a second line on narrow phones, so no filter is ever hidden.
    return Wrap(
      spacing: 8.w,
      runSpacing: 8.h,
      children: [
        PopupMenuButton<DateTime?>(
          tooltip: '',
          color: AppColors.surfaceRaised,
          onSelected: onMonth,
          itemBuilder: (_) => [
            const PopupMenuItem(value: null, child: Text('All time')),
            for (final month in months)
              PopupMenuItem(
                value: month,
                child: Text(_monthLabel.format(month)),
              ),
          ],
          child: _Chip(
            icon: Icons.calendar_today_outlined,
            label: filters.month == null
                ? 'All time'
                : _monthLabel.format(filters.month!),
            semantics: 'Month filter',
          ),
        ),
        _Chip(
          label: 'All Types',
          semantics: 'Transaction type, demo only',
          onTap: onTypes,
        ),
        PopupMenuButton<StatusFilter>(
          tooltip: '',
          enabled: !pendingTab,
          color: AppColors.surfaceRaised,
          onSelected: onStatus,
          itemBuilder: (_) => const [
            PopupMenuItem(value: StatusFilter.any, child: Text('Any status')),
            PopupMenuItem(value: StatusFilter.success, child: Text('Success')),
            PopupMenuItem(value: StatusFilter.pending, child: Text('Pending')),
            PopupMenuItem(value: StatusFilter.failed, child: Text('Failed')),
          ],
          child: _Chip(
            label: 'Status: ${_statusName(filters.effectiveStatus)}',
            dot: filters.effectiveStatus != StatusFilter.any,
            dimmed: pendingTab,
            semantics: 'Status filter',
          ),
        ),
      ],
    );
  }

  static String _statusName(StatusFilter status) => switch (status) {
    StatusFilter.any => 'Any',
    StatusFilter.success => 'Success',
    StatusFilter.pending => 'Pending',
    StatusFilter.failed => 'Failed',
  };
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.semantics,
    this.icon,
    this.dot = false,
    this.dimmed = false,
    this.onTap,
  });

  final String label;
  final String semantics;
  final IconData? icon;
  final bool dot;
  final bool dimmed;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = dimmed ? AppColors.textSecondary : AppColors.textPrimary;
    final content = Padding(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 11.h),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16.r, color: color),
            SizedBox(width: 8.w),
          ],
          if (dot) ...[
            Container(
              width: 6.r,
              height: 6.r,
              decoration: const BoxDecoration(
                color: AppColors.secondary,
                shape: BoxShape.circle,
              ),
            ),
            SizedBox(width: 8.w),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontSize: 13.sp,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
          SizedBox(width: 6.w),
          Icon(Icons.keyboard_arrow_down, size: 18.r, color: color),
        ],
      ),
    );
    return Semantics(
      button: true,
      label: semantics,
      excludeSemantics: true,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(4.r),
        child: onTap == null
            ? content
            : InkWell(
                borderRadius: BorderRadius.circular(4.r),
                onTap: onTap,
                child: content,
              ),
      ),
    );
  }
}
