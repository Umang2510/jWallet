import 'package:flutter/services.dart';
import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/app_colors.dart';

/// 3x4 keypad that stretches to whatever height it is given, so the PIN
/// screens fit every phone without scrolling. It never owns or shows the PIN.
class PinKeypad extends StatelessWidget {
  const PinKeypad({
    super.key,
    required this.onDigit,
    required this.onDelete,
    this.enabled = true,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onDelete;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final gap = 5.r;
    Widget row(List<Widget> keys) => Expanded(
      child: Row(
        children: [
          for (var i = 0; i < keys.length; i++) ...[
            if (i > 0) SizedBox(width: gap),
            Expanded(child: keys[i]),
          ],
        ],
      ),
    );
    final rows = [
      row([for (final d in ['1', '2', '3']) _digit(context, d)]),
      row([for (final d in ['4', '5', '6']) _digit(context, d)]),
      row([for (final d in ['7', '8', '9']) _digit(context, d)]),
      row([
        _key(
          context,
          label: 'Secure keypad',
          child: Icon(
            Icons.lock_outline,
            size: 20.r,
            color: AppColors.textSecondary,
          ),
        ),
        _digit(context, '0'),
        _key(
          context,
          label: 'Delete digit',
          action: onDelete,
          child: Icon(Icons.backspace_outlined, size: 22.r),
        ),
      ]),
    ];
    return Column(
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) SizedBox(height: gap),
          rows[i],
        ],
      ],
    );
  }

  Widget _digit(BuildContext context, String digit) => _key(
    context,
    label: digit,
    action: () => onDigit(digit),
    child: Text(
      digit,
      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
        fontSize: 25.sp,
        fontWeight: FontWeight.w300,
      ),
    ),
  );

  Widget _key(
    BuildContext context, {
    required String label,
    required Widget child,
    VoidCallback? action,
  }) => Semantics(
    label: label,
    button: action != null,
    enabled: enabled && action != null,
    excludeSemantics: true,
    child: Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(4.r),
      child: InkWell(
        borderRadius: BorderRadius.circular(4.r),
        onTap: enabled && action != null
            ? () {
                HapticFeedback.selectionClick();
                action();
              }
            : null,
        child: Center(child: child),
      ),
    ),
  );
}
