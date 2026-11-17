import 'package:material_ui/material_ui.dart';

import 'app_colors.dart';

abstract final class AppGradients {
  /// The brand gradient from the login hero, reused on the home balance card.
  static const hero = RadialGradient(
    center: Alignment(1, -0.85),
    radius: 1.25,
    colors: [
      AppColors.tertiary,
      AppColors.secondary,
      Color(0xFFFFBD98),
      AppColors.primary,
    ],
    stops: [0.06, 0.35, 0.58, 1],
  );
}
