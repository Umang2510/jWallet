import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';

/// "+₹500", "₹1,500", "+₹2,000", "Max".
class QuickAmounts extends StatelessWidget {
  const QuickAmounts({
    super.key,
    required this.currentValue,
    required this.maxValue,
    required this.onAdd,
    required this.onSet,
    required this.onMax,
  });

  final double currentValue;
  final double maxValue;
  final ValueChanged<num> onAdd;
  final ValueChanged<num> onSet;
  final VoidCallback onMax;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.all(4.r),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(4.r),
    ),
    child: Row(
      children: [
        _Chip(label: '+${_rupees(500)}', onTap: () => onAdd(500)),
        SizedBox(width: 4.w),
        _Chip(
          label: _rupees(1500),
          selected: currentValue == 1500,
          onTap: () => onSet(1500),
        ),
        SizedBox(width: 4.w),
        _Chip(label: '+${_rupees(2000)}', onTap: () => onAdd(2000)),
        SizedBox(width: 4.w),
        _Chip(
          label: 'Max',
          selected: maxValue > 0 && currentValue == maxValue,
          onTap: onMax,
        ),
      ],
    ),
  );

  static String _rupees(num value) =>
      Formatters.inr(value).replaceAll('.00', '');
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.onTap, this.selected = false});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Semantics(
      button: true,
      selected: selected,
      label: label.replaceAll('+', 'add '),
      excludeSemantics: true,
      child: Material(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(2.r),
        child: InkWell(
          borderRadius: BorderRadius.circular(2.r),
          onTap: onTap,
          child: Container(
            height: 38.h.clamp(34, 44),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: selected ? AppColors.secondary : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
            child: Text(
              label,
              maxLines: 1,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 13.sp,
                fontWeight: FontWeight.w500,
                color: selected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
