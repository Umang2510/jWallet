import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/app_colors.dart';
import 'app_button.dart';
import 'pin_dots.dart';
import 'pin_keypad.dart';

/// Why a PIN is being asked for. Every PIN-style screen uses [PinScreenLayout];
/// the purpose changes its title, icon, caption and accent colour so the user
/// can always tell the two apart.
enum PinPurpose {
  /// Opens the app. Used only when the phone has no screen lock of its own.
  appLock(
    label: 'APP LOCK',
    caption: 'OPENS THE APP',
    icon: Icons.phonelink_lock_outlined,
    accent: AppColors.credit,
  ),

  /// Approves money transfers. Checked by the server.
  transaction(
    label: 'TRANSACTION PIN',
    caption: 'APPROVES TRANSFERS',
    icon: Icons.currency_rupee,
    accent: AppColors.secondary,
  );

  const PinPurpose({
    required this.label,
    required this.caption,
    required this.icon,
    required this.accent,
  });

  final String label;
  final String caption;
  final IconData icon;
  final Color accent;
}

/// One layout for every PIN screen (app lock and transaction PIN, setup and
/// entry). It fills the screen without scrolling: the keypad takes whatever
/// height is left, and it only scrolls as a last resort (tiny screens).
///
/// Must not use tooltips: the app lock screens are shown above the router's
/// Navigator, which means there is no Overlay for a Tooltip.
class PinScreenLayout extends StatelessWidget {
  const PinScreenLayout({
    super.key,
    required this.purpose,
    required this.title,
    required this.subtitle,
    required this.primaryLabel,
    required this.onPrimary,
    this.step,
    this.onBack,
    this.entered = 0,
    this.dotLength,
    this.message,
    this.onDigit,
    this.onDelete,
    this.keypadEnabled = true,
    this.panel,
    this.busy = false,
    this.primaryIcon = Icons.arrow_forward,
    this.hintLabel,
    this.onHint,
    this.secondaryLabel,
    this.onSecondary,
  });

  final PinPurpose purpose;
  final String title;
  final String subtitle;

  /// Small caps line at the top-left of the card, e.g. "STEP 1 OF 2 · CREATE".
  final String? step;
  final VoidCallback? onBack;

  /// Dots + keypad state. Ignored when a [panel] is given.
  final int entered;

  /// Number of dots; null grows from 4 to 6 as digits are typed.
  final int? dotLength;

  /// Inline validation or status text under the dots (static, client-side).
  final String? message;
  final ValueChanged<String>? onDigit;
  final VoidCallback? onDelete;
  final bool keypadEnabled;

  /// Replaces the dots and keypad (for example the fingerprint step).
  final Widget? panel;

  final String primaryLabel;
  final IconData? primaryIcon;
  final VoidCallback? onPrimary;
  final bool busy;

  /// Small text action under the card (for example "Use a 6-digit PIN").
  final String? hintLabel;
  final VoidCallback? onHint;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  static const _minKeypadHeight = 4 * 40.0 + 3 * 5.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.2,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: onBack == null
              ? null
              : Semantics(
                  label: 'Back',
                  button: true,
                  excludeSemantics: true,
                  child: IconButton(
                    onPressed: busy ? null : onBack,
                    icon: const Icon(Icons.arrow_back),
                  ),
                ),
          title: Text(purpose.label, style: theme.textTheme.labelLarge),
          actions: [
            Padding(
              padding: EdgeInsets.only(right: 20.w),
              child: Icon(purpose.icon, color: purpose.accent),
            ),
          ],
        ),
        body: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        20.w.clamp(16, 36),
                        6.h,
                        20.w.clamp(16, 36),
                        12.h,
                      ),
                      child: _buildColumn(theme),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildColumn(ThemeData theme) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _buildCard(theme),
      if (hintLabel != null)
        Align(
          child: TextButton(
            onPressed: busy ? null : onHint,
            style: TextButton.styleFrom(
              minimumSize: Size(0, 36.h.clamp(32, 40)),
              padding: EdgeInsets.symmetric(horizontal: 12.w),
            ),
            child: Text(hintLabel!),
          ),
        )
      else
        SizedBox(height: 10.h),
      Expanded(
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: _minKeypadHeight),
          child:
              panel ??
              PinKeypad(
                enabled: keypadEnabled && !busy,
                onDigit: onDigit ?? (_) {},
                onDelete: onDelete ?? () {},
              ),
        ),
      ),
      SizedBox(height: 12.h),
      AppButton(
        label: primaryLabel,
        icon: primaryIcon,
        isLoading: busy,
        onPressed: onPrimary,
      ),
      if (secondaryLabel != null)
        TextButton(
          onPressed: busy ? null : onSecondary,
          style: TextButton.styleFrom(
            minimumSize: Size.fromHeight(40.h.clamp(36, 44)),
          ),
          child: Text(secondaryLabel!),
        ),
    ],
  );

  Widget _buildCard(ThemeData theme) => Container(
    padding: EdgeInsets.all(18.r),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(16.r),
      border: Border.all(color: AppColors.border),
      gradient: LinearGradient(
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
        colors: [AppColors.surface, purpose.accent.withValues(alpha: 0.16)],
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                step ?? '',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 10.sp,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            _buildChip(theme),
          ],
        ),
        SizedBox(height: 12.h),
        Text(
          title,
          style: theme.textTheme.headlineMedium?.copyWith(fontSize: 24.sp),
        ),
        SizedBox(height: 6.h),
        Text(subtitle, style: theme.textTheme.bodySmall),
        if (panel == null) ...[
          SizedBox(height: 16.h),
          Center(
            child: PinDots(
              entered: entered,
              length: dotLength,
              color: purpose.accent,
            ),
          ),
          SizedBox(height: 8.h),
          Semantics(
            liveRegion: true,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: 16.h),
              child: Text(
                message ?? '',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.error,
                ),
              ),
            ),
          ),
        ],
      ],
    ),
  );

  Widget _buildChip(ThemeData theme) => Container(
    padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 4.h),
    decoration: BoxDecoration(
      color: purpose.accent.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(20.r),
      border: Border.all(color: purpose.accent.withValues(alpha: 0.5)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6.r,
          height: 6.r,
          decoration: BoxDecoration(
            color: purpose.accent,
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: 6.w),
        Text(
          purpose.caption,
          style: theme.textTheme.bodySmall?.copyWith(
            color: purpose.accent,
            fontSize: 9.sp,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
        ),
      ],
    ),
  );
}

/// Replaces the keypad on steps that need no digits (fingerprint offer, phone
/// screen-lock unlock). Scales down instead of overflowing on short screens.
class PinPanel extends StatelessWidget {
  const PinPanel({
    super.key,
    required this.purpose,
    required this.icon,
    required this.text,
  });

  final PinPurpose purpose;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: SizedBox(
        width: 280.w.clamp(240, 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96.r,
              height: 96.r,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: purpose.accent.withValues(alpha: 0.1),
                border: Border.all(
                  color: purpose.accent.withValues(alpha: 0.5),
                ),
              ),
              child: Icon(icon, size: 44.r, color: purpose.accent),
            ),
            SizedBox(height: 16.h),
            Text(
              text,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    ),
  );
}
