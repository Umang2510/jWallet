import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_exception.dart';
import '../data/home_models.dart';
import '../data/home_repository.dart';

enum HomeStatus { loading, loaded, failure }

class HomeState extends Equatable {
  const HomeState({
    this.status = HomeStatus.loading,
    this.data,
    this.message,
    this.failureId = 0,
  });

  final HomeStatus status;
  final HomeData? data;

  /// Failure text: the API's `meta.message`, shown in a snackbar. A refresh
  /// that fails keeps the data already on screen and only sets this.
  final String? message;

  /// Changes on every failure so the same message can be shown again.
  final int failureId;

  @override
  List<Object?> get props => [status, data, message, failureId];
}

class HomeCubit extends Cubit<HomeState> {
  /// [walletChanges] (a transfer was made) triggers a quiet refresh.
  HomeCubit(this._repository, {Stream<void>? walletChanges})
    : super(const HomeState()) {
    _changes = walletChanges?.listen((_) => refresh());
  }

  final HomeRepository _repository;
  StreamSubscription<void>? _changes;
  bool _loading = false;
  int _failures = 0;

  /// First load, and "Retry" after a failed first load.
  Future<void> load() async {
    if (_loading) return;
    if (state.data == null) emit(const HomeState());
    await _fetch();
  }

  /// Pull to refresh: the old numbers stay visible until new ones arrive.
  Future<void> refresh() async {
    if (_loading) return;
    await _fetch();
  }

  Future<void> _fetch() async {
    _loading = true;
    try {
      final data = await _repository.load();
      if (!isClosed) emit(HomeState(status: HomeStatus.loaded, data: data));
    } on ApiException catch (error) {
      _failed(error.message);
    } catch (_) {
      _failed('Something went wrong. Please try again.');
    } finally {
      _loading = false;
    }
  }

  void _failed(String message) {
    if (isClosed) return;
    final data = state.data;
    emit(
      HomeState(
        status: data == null ? HomeStatus.failure : HomeStatus.loaded,
        data: data,
        message: message,
        failureId: ++_failures,
      ),
    );
  }

  @override
  Future<void> close() {
    _changes?.cancel();
    return super.close();
  }
}
