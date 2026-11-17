import 'dart:math' as math;

import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_colors.dart';
import 'transfer_hero_coin.dart';

/// Full-screen "money is moving" scene: the brand gradient breathes around a
/// coin, growing and shrinking. Ends on a tick ([success]) just before the
/// coin flies to the transaction details screen.
class TransferProcessingView extends StatefulWidget {
  const TransferProcessingView({
    super.key,
    required this.amountLabel,
    required this.recipientName,
    this.success = false,
  });

  final String amountLabel;
  final String recipientName;
  final bool success;

  @override
  State<TransferProcessingView> createState() => _TransferProcessingViewState();
}

class _TransferProcessingViewState extends State<TransferProcessingView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  );
  late final _LightPainter _painter = _LightPainter(_controller);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Honour "remove animations": a still glow instead of moving light.
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller
        ..stop()
        ..value = 0.125;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      liveRegion: true,
      label: widget.success
          ? 'Transfer sent'
          : 'Processing your transfer of ${widget.amountLabel}',
      child: ColoredBox(
        color: AppColors.background,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ExcludeSemantics(
              child: RepaintBoundary(
                child: CustomPaint(painter: _painter),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  const Spacer(flex: 5),
                  TransferHeroCoin(size: 124.r, success: widget.success),
                  SizedBox(height: 36.h),
                  Text(
                    widget.amountLabel,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontSize: 34.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    widget.success
                        ? 'sent to ${widget.recipientName}'
                        : 'to ${widget.recipientName}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  SizedBox(height: 22.h),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      widget.success
                          ? 'TRANSFER COMPLETE'
                          : 'SECURING YOUR TRANSFER',
                      key: ValueKey(widget.success),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.secondary,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Spacer(flex: 6),
                  Padding(
                    padding: EdgeInsets.only(bottom: 20.h),
                    child: Text(
                      'Please keep the app open',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Two layers of the brand gradient that breathe in and out around the coin:
/// a wide glow and a tighter, brighter core, moving in opposite phase.
///
/// Built for smoothness: the shaders are created once per screen size and the
/// canvas is scaled to change their size, so each frame is just two circles.
class _LightPainter extends CustomPainter {
  _LightPainter(this.animation) : super(repaint: animation);
  final Animation<double> animation;

  static const _warm = Color(0xFFFFBD98);

  Size? _size;
  late Paint _glow;
  late Paint _core;
  late double _glowRadius;
  late double _coreRadius;

  void _prepare(Size size) {
    if (_size == size) return;
    _size = size;
    _glowRadius = size.longestSide * 0.62;
    _coreRadius = size.shortestSide * 0.62;
    // Shaders are centred on the origin; the canvas is moved and scaled.
    _glow = Paint()
      ..shader = RadialGradient(
        colors: [
          _warm.withValues(alpha: 0.50),
          AppColors.secondary.withValues(alpha: 0.30),
          AppColors.tertiary.withValues(alpha: 0.20),
          Colors.transparent,
        ],
        stops: const [0.0, 0.3, 0.62, 1.0],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: _glowRadius));
    _core = Paint()
      ..shader = RadialGradient(
        colors: [
          _warm.withValues(alpha: 0.65),
          AppColors.secondary.withValues(alpha: 0.28),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: _coreRadius));
  }

  @override
  void paint(Canvas canvas, Size size) {
    _prepare(size);
    // The coin sits a little above the middle (flex 5 : 6 in the layout).
    final center = Offset(size.width / 2, size.height * 0.355);
    // 0 → 1 → 0 smoothly, once every 3 seconds.
    final wave = (1 - math.cos(animation.value * 2 * math.pi * 2)) / 2;

    _layer(canvas, center, _glow, _glowRadius, scale: 0.45 + 0.65 * wave);
    _layer(canvas, center, _core, _coreRadius, scale: 1.2 - 0.6 * wave);
  }

  void _layer(
    Canvas canvas,
    Offset center,
    Paint paint,
    double radius, {
    required double scale,
  }) {
    canvas
      ..save()
      ..translate(center.dx, center.dy)
      ..scale(scale)
      ..drawCircle(Offset.zero, radius, paint)
      ..restore();
  }

  @override
  bool shouldRepaint(_LightPainter oldDelegate) => false;
}
