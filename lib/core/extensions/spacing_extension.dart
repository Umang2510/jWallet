import 'package:flutter/widgets.dart';
import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';

extension SpacingExtension on num {
  SizedBox sizedBoxHeight() => SizedBox(height: h);
  SizedBox sizedBoxWidth() => SizedBox(width: w);
}
