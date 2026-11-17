import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/state_views.dart';
import '../data/home_models.dart';
import '../data/quick_contacts.dart';
import '../view_model/home_cubit.dart';
import 'widgets/balance_card.dart';
import 'widgets/demo_qr_sheet.dart';
import 'widgets/quick_send_row.dart';
import 'widgets/recent_activity_card.dart';

/// Home tab: balance, quick send and recent activity, all from the API except
/// the local Quick Send shortcuts.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onSend, required this.onActivity});

  /// Opens Send Money (Send button, Quick Send tiles).
  final VoidCallback onSend;

  /// Switches to the Activity tab (History, View all).
  final VoidCallback onActivity;

  @override
  Widget build(BuildContext context) => BlocConsumer<HomeCubit, HomeState>(
    listenWhen: (previous, current) =>
        current.message != null && current.failureId != previous.failureId,
    listener: (context, state) =>
        AppSnackbar.show(context, state.message!, isError: true),
    builder: (context, state) => Scaffold(
      body: SafeArea(child: _buildBody(context, state)),
    ),
  );

  Widget _buildBody(BuildContext context, HomeState state) {
    final data = state.data;
    if (data != null) return _buildContent(context, data);
    if (state.status == HomeStatus.failure) {
      return ErrorView(
        message: 'We could not load your wallet.',
        onRetry: context.read<HomeCubit>().load,
      );
    }
    return const LoadingView();
  }

  Widget _buildContent(BuildContext context, HomeData data) {
    final theme = Theme.of(context);
    return RefreshIndicator(
      color: AppColors.secondary,
      backgroundColor: AppColors.surfaceRaised,
      onRefresh: context.read<HomeCubit>().refresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(20.w.clamp(16, 36), 16.h, 20.w.clamp(16, 36), 20.h),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTopBar(theme),
                SizedBox(height: 16.h),
                BalanceCard(
                  profile: data.profile,
                  wallet: data.wallet,
                  onScan: () => DemoQrSheet.show(
                    context,
                    profile: data.profile,
                    wallet: data.wallet,
                  ),
                  onSend: onSend,
                  onAddMoney: () => AppSnackbar.show(
                    context,
                    'Add money is a demo-only feature.',
                  ),
                  onHistory: onActivity,
                ),
                SizedBox(height: 22.h),
                QuickSendRow(
                  contacts: quickContacts,
                  onSelect: (_) => onSend(),
                  onNew: onSend,
                ),
                SizedBox(height: 22.h),
                RecentActivityCard(items: data.recent, onViewAll: onActivity),
                SizedBox(height: 22.h),
                _buildFooter(theme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Settings and profile are UI only for now.
  Widget _buildTopBar(ThemeData theme) => Row(
    children: [
      Expanded(
        child: Text(
          'HOME',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
      ),
      Icon(Icons.tune, color: AppColors.textSecondary, size: 24.r),
      SizedBox(width: 18.w),
      Container(
        width: 40.r,
        height: 40.r,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Icon(
          Icons.person_outline,
          color: AppColors.surface,
          size: 22.r,
        ),
      ),
    ],
  );

  Widget _buildFooter(ThemeData theme) => Column(
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shield_outlined, size: 14.r, color: AppColors.textSecondary),
          SizedBox(width: 8.w),
          Flexible(
            child: Text(
              'END-TO-END ENCRYPTED UPI ENCLAVE',
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 10.sp,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
      SizedBox(height: 6.h),
      Text(
        'Pull down to refresh balances',
        style: theme.textTheme.bodySmall?.copyWith(
          fontSize: 10.sp,
          color: AppColors.textSecondary.withValues(alpha: 0.6),
        ),
      ),
    ],
  );
}
