import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_colors.dart';

/// Shared by the processing screen and the transaction details screen, so the
/// coin flies from one to the other when the transfer finishes.
const transferHeroTag = 'transfer-hero';

/// The round gold-ish coin: a rupee sign while money is moving, a tick once
/// it has arrived.
class TransferHeroCoin extends StatelessWidget {
  const TransferHeroCoin({super.key, required this.size, this.success = false});

  final double size;
  final bool success;

  @override
  Widget build(BuildContext context) => Hero(
    tag: transferHeroTag,
    child: SizedBox.square(
      dimension: size,
      child: _Coin(success: success),
    ),
  );
}

class _Coin extends StatelessWidget {
  const _Coin({required this.success});
  final bool success;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: const RadialGradient(
        center: Alignment(-0.35, -0.45),
        radius: 1.05,
        colors: [AppColors.primary, Color(0xFFFFBD98), AppColors.secondary],
        stops: [0.0, 0.5, 1.0],
      ),
      border: Border.all(color: AppColors.primary.withValues(alpha: 0.75), width: 2),
      boxShadow: [
        BoxShadow(
          color: AppColors.secondary.withValues(alpha: 0.55),
          blurRadius: 36.r,
          spreadRadius: 4.r,
        ),
      ],
    ),
    // Sized from the available space so it stays right mid-flight.
    child: LayoutBuilder(
      builder: (context, box) {
        final glyph = box.maxWidth * 0.52;
        return Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            transitionBuilder: (child, animation) =>
                ScaleTransition(scale: animation, child: child),
            child: success
                ? Icon(
                    Icons.check_rounded,
                    key: const ValueKey('done'),
                    size: glyph,
                    color: AppColors.tertiary,
                  )
                : Text(
                    '₹',
                    key: const ValueKey('rupee'),
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontSize: glyph,
                      height: 1,
                      letterSpacing: 0,
                      color: AppColors.tertiary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        );
      },
    ),
  );
}
