import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';
import 'package:material_ui/material_ui.dart';

import '../extensions/spacing_extension.dart';

enum AppButtonVariant { primary, secondary, outlined }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.variant = AppButtonVariant.primary,
    this.style,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final AppButtonVariant variant;
  final ButtonStyle? style;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final action = isLoading ? null : onPressed;
    final child = _buildContent(context);
    final base = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(
        Size(expand ? double.infinity : 0, 54.h.clamp(48, 64)),
      ),
    );
    return switch (variant) {
      AppButtonVariant.primary => FilledButton(
        onPressed: action,
        style: base.merge(style),
        child: child,
      ),
      AppButtonVariant.secondary => FilledButton.tonal(
        onPressed: action,
        style: base.merge(style),
        child: child,
      ),
      AppButtonVariant.outlined => OutlinedButton(
        onPressed: action,
        style: base.merge(style),
        child: child,
      ),
    };
  }

  Widget _buildContent(BuildContext context) {
    if (isLoading) {
      return Semantics(
        label: '$label in progress',
        liveRegion: true,
        child: SizedBox.square(
          dimension: 22.r,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(child: Text(label, textAlign: TextAlign.center)),
        if (icon != null) ...[12.sizedBoxWidth(), Icon(icon, size: 20.r)],
      ],
    );
  }
}
