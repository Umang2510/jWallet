import 'package:flutter/widgets.dart';
import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';

/// Keep phone proportions without stretching controls across tablets or in landscape.
class ResponsiveApp extends StatelessWidget {
  const ResponsiveApp({super.key, required this.builder});
  final Widget Function(BuildContext, Widget?) builder;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final wide = size.width > 480;
    return ScreenUtilPlusInit(
      designSize: wide ? size : const Size(375, 812),
      splitScreenMode: true,
      fontSizeResolver: (fontSize, instance) =>
          fontSize * instance.scaleWidth.clamp(0.9, 1.15),
      builder: builder,
    );
  }
}
