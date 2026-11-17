import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/logout_button.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/state_views.dart';
import '../../home/data/home_models.dart';
import '../view_model/activity_cubit.dart';
import 'widgets/activity_filter_bar.dart';
import 'widgets/activity_header.dart';
import 'widgets/activity_tile.dart';

/// The Activity tab: the whole history, filtered and paged by the API.
class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key, required this.onOpen});

  /// A row was tapped: open that transaction.
  final ValueChanged<TransactionItem> onOpen;

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  final _scroll = ScrollController();
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_maybeLoadMore);
  }

  @override
  void dispose() {
    _scroll
      ..removeListener(_maybeLoadMore)
      ..dispose();
    _search.dispose();
    super.dispose();
  }

  /// Ask for the next page a little before the end of the list is reached.
  void _maybeLoadMore() {
    if (_scroll.hasClients && _scroll.position.extentAfter < 500) {
      context.read<ActivityCubit>().loadMore();
    }
  }

  void _demo(String message) => AppSnackbar.show(context, message);

  @override
  Widget build(BuildContext context) => BlocConsumer<ActivityCubit, ActivityState>(
    listenWhen: (previous, current) =>
        (current.message != null && current.failureId != previous.failureId) ||
        // "Clear filters" empties the search box too.
        (previous.filters.query.isNotEmpty && current.filters.query.isEmpty),
    listener: (context, state) {
      if (state.filters.query.isEmpty && _search.text.isNotEmpty) {
        _search.clear();
      }
      if (state.message != null) {
        AppSnackbar.show(context, state.message!, isError: true);
      }
    },
    builder: (context, state) => MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.2,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: RefreshIndicator(
                color: AppColors.secondary,
                backgroundColor: AppColors.surfaceRaised,
                onRefresh: context.read<ActivityCubit>().refresh,
                child: CustomScrollView(
                  controller: _scroll,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        20.w.clamp(16, 32),
                        16.h,
                        20.w.clamp(16, 32),
                        0,
                      ),
                      sliver: SliverToBoxAdapter(child: _buildTop(context, state)),
                    ),
                    ..._buildBody(context, state),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  // ---- top: title, header card, filters ----

  Widget _buildTop(BuildContext context, ActivityState state) {
    final theme = Theme.of(context);
    final cubit = context.read<ActivityCubit>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  'TRANSACTION HISTORY',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
            ),
            SizedBox(width: 12.w),
            // Log out is real; the profile is UI only.
            const LogoutButton(),
            SizedBox(width: 10.w),
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
        ),
        SizedBox(height: 16.h),
        ActivityHeader(
          controller: _search,
          tab: state.filters.tab,
          total: state.total,
          showCount: state.status == ActivityStatus.loaded,
          onQuery: cubit.setQuery,
          onTab: cubit.setTab,
          onExport: () => _demo('Statement export is a demo-only feature.'),
        ),
        SizedBox(height: 12.h),
        ActivityFilterBar(
          filters: state.filters,
          onMonth: cubit.setMonth,
          onStatus: cubit.setStatus,
          onTypes: () =>
              _demo('Transaction categories are not available in the demo.'),
        ),
        SizedBox(height: 16.h),
      ],
    );
  }

  // ---- body: list, or its loading / empty / error state ----

  List<Widget> _buildBody(BuildContext context, ActivityState state) {
    final cubit = context.read<ActivityCubit>();
    if (state.status == ActivityStatus.failure) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: ErrorView(
            message: 'We could not load your transactions.',
            onRetry: cubit.load,
          ),
        ),
      ];
    }
    if (state.status == ActivityStatus.loading) {
      return const [SliverFillRemaining(hasScrollBody: false, child: LoadingView())];
    }
    if (state.items.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _Empty(
            filtered: state.filters.isFiltered,
            onClear: cubit.clearFilters,
          ),
        ),
      ];
    }
    final rows = _rows(state.items);
    return [
      SliverPadding(
        padding: EdgeInsets.symmetric(horizontal: 20.w.clamp(16, 32)),
        sliver: SliverList.builder(
          itemCount: rows.length + 1,
          itemBuilder: (context, i) {
            if (i == rows.length) return _buildFooter(context, state);
            return switch (rows[i]) {
              _DayRow(:final label, :final count) => ActivityDayHeader(
                label: label,
                count: count,
              ),
              _TxnRow(:final item, :final divider) => Column(
                children: [
                  if (divider)
                    Divider(
                      height: 1,
                      color: AppColors.border.withValues(alpha: 0.4),
                    ),
                  ActivityTile(item: item, onTap: () => widget.onOpen(item)),
                ],
              ),
            };
          },
        ),
      ),
    ];
  }

  /// Day headings with their rows, from the loaded (newest first) items.
  List<_Row> _rows(List<TransactionItem> items) {
    final counts = <DateTime, int>{};
    DateTime dayOf(TransactionItem item) {
      final t = DateTime.parse(item.createdAt).toLocal();
      return DateTime(t.year, t.month, t.day);
    }

    for (final item in items) {
      counts.update(dayOf(item), (n) => n + 1, ifAbsent: () => 1);
    }
    final rows = <_Row>[];
    DateTime? current;
    for (final item in items) {
      final day = dayOf(item);
      if (day != current) {
        current = day;
        rows.add(_DayRow(Formatters.dayHeading(day), counts[day]!));
      }
      rows.add(_TxnRow(item, divider: rows.last is _TxnRow));
    }
    return rows;
  }

  Widget _buildFooter(BuildContext context, ActivityState state) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(0, 18.h, 0, 24.h),
      child: Column(
        children: [
          if (state.loadingMore)
            Padding(
              padding: EdgeInsets.only(bottom: 18.h),
              child: SizedBox.square(
                dimension: 22.r,
                child: const CircularProgressIndicator(strokeWidth: 2.5),
              ),
            )
          else if (state.hasNext)
            TextButton(
              onPressed: context.read<ActivityCubit>().loadMore,
              child: const Text('LOAD MORE'),
            ),
          Divider(color: AppColors.border.withValues(alpha: 0.5)),
          SizedBox(height: 10.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 14.r, color: AppColors.textSecondary),
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
            'jWallet Lite  ·  Demo ledger',
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 10.sp,
              color: AppColors.textSecondary.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

sealed class _Row {
  const _Row();
}

class _DayRow extends _Row {
  const _DayRow(this.label, this.count);
  final String label;
  final int count;
}

class _TxnRow extends _Row {
  const _TxnRow(this.item, {required this.divider});
  final TransactionItem item;
  final bool divider;
}

class _Empty extends StatelessWidget {
  const _Empty({required this.filtered, required this.onClear});
  final bool filtered;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      EmptyView(
        icon: Icons.receipt_long_outlined,
        message: filtered
            ? 'No transactions match these filters.'
            : 'No transactions yet.\nSend money to see it here.',
      ),
      if (filtered)
        TextButton(onPressed: onClear, child: const Text('CLEAR FILTERS')),
    ],
  );
}
