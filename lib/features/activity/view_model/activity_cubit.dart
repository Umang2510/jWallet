import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_exception.dart';
import '../../home/data/home_models.dart';
import '../data/activity_models.dart';
import '../data/activity_repository.dart';

enum ActivityStatus { loading, loaded, failure }

class ActivityState extends Equatable {
  const ActivityState({
    this.filters = const ActivityFilters(),
    this.items = const [],
    this.total = 0,
    this.page = 0,
    this.hasNext = false,
    this.status = ActivityStatus.loading,
    this.loadingMore = false,
    this.message,
    this.failureId = 0,
  });

  final ActivityFilters filters;
  final List<TransactionItem> items;

  /// Matches for the current filters (all pages), from the server.
  final int total;
  final int page;
  final bool hasNext;
  final ActivityStatus status;
  final bool loadingMore;

  /// Failure text: the API's `meta.message`, shown in a snackbar.
  final String? message;
  final int failureId;

  ActivityState copyWith({
    ActivityFilters? filters,
    List<TransactionItem>? items,
    int? total,
    int? page,
    bool? hasNext,
    ActivityStatus? status,
    bool? loadingMore,
    String? message,
    int? failureId,
  }) => ActivityState(
    filters: filters ?? this.filters,
    items: items ?? this.items,
    total: total ?? this.total,
    page: page ?? this.page,
    hasNext: hasNext ?? this.hasNext,
    status: status ?? this.status,
    loadingMore: loadingMore ?? this.loadingMore,
    message: message,
    failureId: failureId ?? this.failureId,
  );

  @override
  List<Object?> get props => [
    filters,
    items,
    total,
    page,
    hasNext,
    status,
    loadingMore,
    message,
    failureId,
  ];
}

/// The transaction history. Every filter is sent to the API and the list is
/// loaded a page at a time; nothing is filtered or counted on the phone.
class ActivityCubit extends Cubit<ActivityState> {
  ActivityCubit(
    this._repository, {
    Stream<void>? walletChanges,
    this.searchDelay = const Duration(milliseconds: 400),
  }) : super(const ActivityState()) {
    _changes = walletChanges?.listen((_) => refresh());
  }

  final ActivityRepository _repository;
  final Duration searchDelay;
  StreamSubscription<void>? _changes;
  Timer? _typing;
  int _request = 0;
  int _failures = 0;

  /// First page for the current filters.
  Future<void> load() => _loadFirst(keepItems: false);

  /// Pull to refresh: the old rows stay until the new ones arrive.
  Future<void> refresh() => _loadFirst(keepItems: true);

  Future<void> _loadFirst({required bool keepItems}) async {
    final id = ++_request;
    final filters = state.filters;
    if (!keepItems || state.items.isEmpty) {
      emit(
        state.copyWith(
          items: const [],
          status: ActivityStatus.loading,
          loadingMore: false,
          total: 0,
          page: 0,
          hasNext: false,
        ),
      );
    }
    try {
      final page = await _repository.list(filters);
      if (isClosed || id != _request) return; // filters changed meanwhile
      emit(
        state.copyWith(
          items: page.items,
          total: page.totalItems,
          page: page.page,
          hasNext: page.hasNextPage,
          status: ActivityStatus.loaded,
          loadingMore: false,
        ),
      );
    } on ApiException catch (error) {
      _failed(id, error.message);
    } catch (_) {
      _failed(id, 'Something went wrong. Please try again.');
    }
  }

  /// Next page, when the user nears the end of the list.
  Future<void> loadMore() async {
    if (state.status != ActivityStatus.loaded ||
        !state.hasNext ||
        state.loadingMore) {
      return;
    }
    final id = _request;
    emit(state.copyWith(loadingMore: true));
    try {
      final page = await _repository.list(state.filters, page: state.page + 1);
      if (isClosed || id != _request) return;
      emit(
        state.copyWith(
          items: [...state.items, ...page.items],
          total: page.totalItems,
          page: page.page,
          hasNext: page.hasNextPage,
          loadingMore: false,
        ),
      );
    } on ApiException catch (error) {
      _failed(id, error.message, whileLoadingMore: true);
    } catch (_) {
      _failed(
        id,
        'Something went wrong. Please try again.',
        whileLoadingMore: true,
      );
    }
  }

  void _failed(int id, String message, {bool whileLoadingMore = false}) {
    if (isClosed || id != _request) return;
    emit(
      state.copyWith(
        // A failed refresh or "load more" keeps what is already on screen.
        status: state.items.isEmpty && !whileLoadingMore
            ? ActivityStatus.failure
            : ActivityStatus.loaded,
        loadingMore: false,
        message: message,
        failureId: ++_failures,
      ),
    );
  }

  // ---- filters (each one reloads from the API) ----

  void setTab(ActivityTab tab) => _filter(state.filters.copyWith(tab: tab));

  void setStatus(StatusFilter status) =>
      _filter(state.filters.copyWith(status: status));

  /// First day of a month, or null for all time.
  void setMonth(DateTime? month) => _filter(
    month == null
        ? state.filters.copyWith(clearMonth: true)
        : state.filters.copyWith(month: DateTime(month.year, month.month)),
  );

  /// Waits for a pause in typing before asking the server.
  void setQuery(String query) {
    final text = query.length > 50 ? query.substring(0, 50) : query;
    _typing?.cancel();
    emit(state.copyWith(filters: state.filters.copyWith(query: text)));
    _typing = Timer(searchDelay, load);
  }

  void clearFilters() => _filter(const ActivityFilters());

  void _filter(ActivityFilters next) {
    if (next == state.filters) return;
    _typing?.cancel();
    emit(state.copyWith(filters: next));
    load();
  }

  @override
  Future<void> close() {
    _typing?.cancel();
    _changes?.cancel();
    return super.close();
  }
}
