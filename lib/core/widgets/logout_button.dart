import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/session/session_cubit.dart';
import '../theme/app_colors.dart';

/// The top-bar Log out button (Home and Activity).
///
/// Logging out calls the logout API, wipes everything the app saved on the
/// phone, and sends the user to the login screen. It asks first, because the
/// wipe includes the app lock PIN and device settings.
class LogoutButton extends StatelessWidget {
  const LogoutButton({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Log out',
    excludeSemantics: true,
    child: InkResponse(
      onTap: () => _logout(context),
      radius: 24.r,
      child: Padding(
        padding: EdgeInsets.all(8.r),
        child: Icon(Icons.logout, color: AppColors.textSecondary, size: 24.r),
      ),
    ),
  );

  Future<void> _logout(BuildContext context) async {
    final session = context.read<SessionCubit>();
    final navigator = Navigator.of(context, rootNavigator: true);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const _ConfirmDialog(),
    );
    if (confirmed != true) return;

    // Keep a spinner up while the server is told; it can be slow to answer.
    DialogRoute<void>? busy;
    if (context.mounted) {
      busy = DialogRoute<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const _BusyDialog(),
      );
      navigator.push(busy);
    }
    try {
      await session.logout();
    } finally {
      // Logging out sends the app to the login screen, which can remove this
      // dialog already; only close it if it is still there.
      if (busy != null && busy.isActive) navigator.removeRoute(busy);
    }
  }
}

class _ConfirmDialog extends StatelessWidget {
  const _ConfirmDialog();

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: AppColors.surfaceRaised,
    title: const Text('Log out?'),
    content: Text(
      'You will be signed out and the data jWallet saved on this phone '
      '(including your app lock PIN) will be cleared. Your money and history '
      'stay safe in your account.',
      style: Theme.of(context).textTheme.bodyMedium,
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(false),
        child: const Text('CANCEL'),
      ),
      FilledButton(
        onPressed: () => Navigator.of(context).pop(true),
        style: FilledButton.styleFrom(
          minimumSize: Size(0, 44.h.clamp(40, 48)),
        ),
        child: const Text('LOG OUT'),
      ),
    ],
  );
}

class _BusyDialog extends StatelessWidget {
  const _BusyDialog();

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    child: Dialog(
      backgroundColor: AppColors.surfaceRaised,
      child: Padding(
        padding: EdgeInsets.all(22.r),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: 24.r,
              child: const CircularProgressIndicator(strokeWidth: 2.5),
            ),
            SizedBox(width: 18.w),
            Flexible(
              child: Semantics(
                liveRegion: true,
                child: Text(
                  'Logging out…',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
