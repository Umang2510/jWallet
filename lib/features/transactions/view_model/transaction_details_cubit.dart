import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_exception.dart';
import '../data/transaction_details.dart';
import '../data/transaction_repository.dart';

enum DetailsStatus { loading, loaded, failure }

class TransactionDetailsState extends Equatable {
  const TransactionDetailsState({
    this.status = DetailsStatus.loading,
    this.details,
    this.message,
    this.failureId = 0,
  });

  final DetailsStatus status;
  final TransactionDetails? details;

  /// Failure text: the API's `meta.message`, shown in a snackbar.
  final String? message;
  final int failureId;

  @override
  List<Object?> get props => [status, details, message, failureId];
}

class TransactionDetailsCubit extends Cubit<TransactionDetailsState> {
  /// [initial] (the receipt of a transfer just made) shows instantly; the real
  /// record is always fetched from the API as well.
  TransactionDetailsCubit(
    this._repository,
    this.id, {
    TransactionDetails? initial,
  }) : super(
         initial == null
             ? const TransactionDetailsState()
             : TransactionDetailsState(
                 status: DetailsStatus.loaded,
                 details: initial,
               ),
       );

  final TransactionRepository _repository;
  final String id;
  int _failures = 0;

  Future<void> load() async {
    try {
      final details = await _repository.details(id);
      if (!isClosed) {
        emit(TransactionDetailsState(status: DetailsStatus.loaded, details: details));
      }
    } on ApiException catch (error) {
      _failed(error.message);
    } catch (_) {
      _failed('Something went wrong. Please try again.');
    }
  }

  void _failed(String message) {
    if (isClosed) return;
    final details = state.details;
    emit(
      TransactionDetailsState(
        status: details == null ? DetailsStatus.failure : DetailsStatus.loaded,
        details: details,
        message: message,
        failureId: ++_failures,
      ),
    );
  }
}
