import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/app_colors.dart';

/// Filled/empty PIN circles. Never shows the digits.
///
/// With a known [length] (creating a PIN, app lock) exactly that many dots are
/// drawn. Without one (entering a PIN of unknown size, 4 or 6) it starts with
/// four dots and grows to six as digits are typed.
class PinDots extends StatelessWidget {
  const PinDots({
    super.key,
    required this.entered,
    this.length,
    this.color = AppColors.secondary,
  });

  final int entered;
  final int? length;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final count = length ?? (entered > 4 ? entered : 4);
    return Semantics(
      label: '$entered PIN digits entered',
      liveRegion: true,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < count; i++)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 7.w),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: 14.r,
                height: 14.r,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < entered ? color : Colors.transparent,
                  border: Border.all(
                    color: i < entered ? color : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
