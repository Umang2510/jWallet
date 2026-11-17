import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';
import 'package:material_ui/material_ui.dart';

import '../session/session_cubit.dart';

/// Temporary screen used while the real screens are being built.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({
    super.key,
    required this.title,
    this.showLogout = false,
  });

  final String title;
  final bool showLogout;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24.r),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.construction, size: 48.dm),
              SizedBox(height: 12.h),
              Text('$title — coming next', style: TextStyle(fontSize: 16.sp)),
              if (showLogout) ...[
                SizedBox(height: 24.h),
                OutlinedButton(
                  onPressed: () => context.read<SessionCubit>().logout(),
                  child: const Text('Logout'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
