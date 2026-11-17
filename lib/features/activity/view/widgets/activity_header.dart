import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../data/activity_models.dart';

/// "Statement ledger / Activity" card: export, search and the four tabs.
class ActivityHeader extends StatelessWidget {
  const ActivityHeader({
    super.key,
    required this.controller,
    required this.tab,
    required this.total,
    required this.showCount,
    required this.onQuery,
    required this.onTab,
    required this.onExport,
  });

  final TextEditingController controller;
  final ActivityTab tab;

  /// Number of matches for the current filters, from the server.
  final int total;
  final bool showCount;
  final ValueChanged<String> onQuery;
  final ValueChanged<ActivityTab> onTab;
  final VoidCallback onExport;

  static const _ink = AppColors.surface;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(8.r),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(18.r, 18.r, 18.r, 14.r),
        decoration: const BoxDecoration(gradient: AppGradients.hero),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'STATEMENT LEDGER',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: _ink.withValues(alpha: 0.7),
                          fontSize: 11.sp,
                          letterSpacing: 1.4,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        'ACTIVITY',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: _ink,
                          fontSize: 26.sp,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                _ExportButton(onTap: onExport),
              ],
            ),
            SizedBox(height: 14.h),
            _buildSearch(theme),
            SizedBox(height: 12.h),
            _buildTabs(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildSearch(ThemeData theme) => Container(
    padding: EdgeInsets.symmetric(horizontal: 12.w),
    decoration: BoxDecoration(
      color: AppColors.surface.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(6.r),
    ),
    child: Row(
      children: [
        Icon(Icons.search, color: AppColors.textSecondary, size: 22.r),
        SizedBox(width: 10.w),
        Expanded(
          child: TextField(
            controller: controller,
            onChanged: onQuery,
            maxLength: 50,
            maxLines: 1,
            textInputAction: TextInputAction.search,
            style: theme.textTheme.bodyMedium,
            decoration: InputDecoration(
              hintText: 'Search recipient or ref ID…',
              counterText: '',
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 13.h),
            ),
          ),
        ),
        ListenableBuilder(
          listenable: controller,
          builder: (context, _) => controller.text.isEmpty
              ? const SizedBox.shrink()
              : Semantics(
                  button: true,
                  label: 'Clear search',
                  excludeSemantics: true,
                  child: InkResponse(
                    radius: 20.r,
                    onTap: () {
                      controller.clear();
                      onQuery('');
                    },
                    child: Padding(
                      padding: EdgeInsets.all(6.r),
                      child: Icon(
                        Icons.close,
                        size: 18.r,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
        ),
      ],
    ),
  );

  Widget _buildTabs(ThemeData theme) {
    const labels = {
      ActivityTab.all: 'All',
      ActivityTab.debit: 'Debit (-)',
      ActivityTab.credit: 'Credit (+)',
      ActivityTab.pending: 'Pending',
    };
    // Scales down instead of overflowing on narrow phones.
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          for (final entry in labels.entries) ...[
            _Tab(
              label: entry.value,
              selected: tab == entry.key,
              count: tab == entry.key && showCount ? total : null,
              onTap: () => onTab(entry.key),
            ),
            SizedBox(width: 22.w),
          ],
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
  });

  final String label;
  final bool selected;
  final int? count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: count == null ? label : '$label, $count',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.only(bottom: 6.h),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? AppColors.secondary : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 15.sp,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: ActivityHeader._ink.withValues(
                    alpha: selected ? 1 : 0.65,
                  ),
                ),
              ),
              if (count != null) ...[
                SizedBox(width: 6.w),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.h),
                  decoration: BoxDecoration(
                    color: AppColors.tertiary,
                    borderRadius: BorderRadius.circular(3.r),
                  ),
                  child: Text(
                    '$count',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.primary,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ExportButton extends StatelessWidget {
  const _ExportButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Export statement, demo only',
    excludeSemantics: true,
    child: Material(
      color: AppColors.tertiary,
      borderRadius: BorderRadius.circular(4.r),
      child: InkWell(
        borderRadius: BorderRadius.circular(4.r),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.download, size: 16.r, color: AppColors.primary),
              SizedBox(width: 6.w),
              Text(
                'CSV / PDF',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.primary,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
