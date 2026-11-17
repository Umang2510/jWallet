import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/quick_contacts.dart';

class QuickSendRow extends StatelessWidget {
  const QuickSendRow({
    super.key,
    required this.contacts,
    required this.onSelect,
    required this.onNew,
  });

  final List<QuickContact> contacts;
  final ValueChanged<QuickContact> onSelect;
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final caption = theme.textTheme.bodySmall?.copyWith(
      fontSize: 11.sp,
      letterSpacing: 1.2,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 2.w),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('QUICK SEND', style: caption),
              Text(
                'Frequent',
                style: caption?.copyWith(
                  color: AppColors.debit,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 10.h),
        Row(
          children: [
            for (final contact in contacts) ...[
              Expanded(
                child: _Tile(
                  label: contact.label,
                  semantics: 'Send to ${contact.name}',
                  onTap: () => onSelect(contact),
                  avatar: Text(
                    contact.initials,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: contact.isBusiness
                          ? AppColors.secondary
                          : AppColors.primary,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 5.w),
            ],
            Expanded(
              child: _Tile(
                label: 'New',
                semantics: 'Send to a new recipient',
                dimmed: true,
                onTap: onNew,
                avatar: Icon(
                  Icons.add,
                  size: 20.r,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.label,
    required this.avatar,
    required this.onTap,
    required this.semantics,
    this.dimmed = false,
  });

  final String label;
  final String semantics;
  final Widget avatar;
  final bool dimmed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: semantics,
    excludeSemantics: true,
    child: Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(4.r),
      child: InkWell(
        borderRadius: BorderRadius.circular(4.r),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 4.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40.r,
                height: 40.r,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.surfaceRaised,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: avatar,
              ),
              SizedBox(height: 8.h),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                  color: dimmed
                      ? AppColors.textSecondary
                      : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
