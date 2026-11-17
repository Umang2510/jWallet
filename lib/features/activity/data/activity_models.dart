import 'package:equatable/equatable.dart';
import 'package:intl/intl.dart';

import '../../home/data/home_models.dart';

enum ActivityTab { all, debit, credit, pending }

enum StatusFilter { any, success, pending, failed }

/// Everything the user can narrow the list by. All of it is applied by the
/// server (type, status, search, month), nothing is filtered on the phone.
class ActivityFilters extends Equatable {
  const ActivityFilters({
    this.tab = ActivityTab.all,
    this.status = StatusFilter.any,
    this.month,
    this.query = '',
  });

  final ActivityTab tab;

  /// The status chip. Ignored while the Pending tab is open (it is Pending).
  final StatusFilter status;

  /// First day of the chosen month, or null for all time.
  final DateTime? month;

  /// Search text (recipient name or reference), at most 50 characters.
  final String query;

  StatusFilter get effectiveStatus =>
      tab == ActivityTab.pending ? StatusFilter.pending : status;

  bool get isFiltered =>
      tab != ActivityTab.all ||
      status != StatusFilter.any ||
      month != null ||
      query.isNotEmpty;

  ActivityFilters copyWith({
    ActivityTab? tab,
    StatusFilter? status,
    DateTime? month,
    bool clearMonth = false,
    String? query,
  }) => ActivityFilters(
    tab: tab ?? this.tab,
    status: status ?? this.status,
    month: clearMonth ? null : month ?? this.month,
    query: query ?? this.query,
  );

  static final _day = DateFormat('yyyy-MM-dd');

  /// The request path for one page.
  ///
  /// The query is encoded here, by hand, because the encrypted channel binds
  /// the exact URL: what we sign must be byte for byte what goes on the wire.
  String path({required int page, required int limit}) {
    final params = <String, String>{
      'page': '$page',
      'limit': '$limit',
      if (tab == ActivityTab.debit) 'type': 'DEBIT',
      if (tab == ActivityTab.credit) 'type': 'CREDIT',
      if (effectiveStatus != StatusFilter.any)
        'status': effectiveStatus.name.toUpperCase(),
      if (query.trim().isNotEmpty) 'q': query.trim(),
      if (month != null) ...{
        'from': _day.format(month!),
        'to': _day.format(DateTime(month!.year, month!.month + 1, 0)),
      },
    };
    final query_ = params.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');
    return '/api/v1/transactions?$query_';
  }

  @override
  List<Object?> get props => [tab, status, month, query];
}

/// One page of the history.
class TransactionPage extends Equatable {
  const TransactionPage({
    required this.items,
    required this.page,
    required this.totalItems,
    required this.hasNextPage,
  });

  factory TransactionPage.fromJson(Map<String, dynamic> json) {
    final pagination = json['pagination'] as Map<String, dynamic>;
    return TransactionPage(
      items: [
        for (final item in json['items'] as List<dynamic>)
          TransactionItem.fromJson(item as Map<String, dynamic>),
      ],
      page: pagination['page'] as int,
      totalItems: pagination['totalItems'] as int,
      hasNextPage: pagination['hasNextPage'] as bool,
    );
  }

  final List<TransactionItem> items;
  final int page;
  final int totalItems;
  final bool hasNextPage;

  @override
  List<Object?> get props => [items, page, totalItems, hasNextPage];
}
