import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_exception.dart';
import '../data/amount_input.dart';
import '../data/recipient.dart';
import '../data/transfer_models.dart';
import '../data/transfer_repository.dart';

enum BalanceStatus { loading, ready, failed }

class SendMoneyState extends Equatable {
  const SendMoneyState({
    this.recipient,
    this.amount = const AmountInput(),
    this.remarks = '',
    this.balance,
    this.balanceStatus = BalanceStatus.loading,
    this.message,
    this.failureId = 0,
  });

  final Recipient? recipient;
  final AmountInput amount;
  final String remarks;

  /// Rupees, from the API. Null until loaded (or if it could not be).
  final num? balance;
  final BalanceStatus balanceStatus;

  /// Failure text: the API's `meta.message`, shown in a snackbar.
  final String? message;
  final int failureId;

  /// Short inline hint under the balance, or null when the amount is fine.
  String? get validation {
    final available = balance;
    if (available != null && amount.value > available) {
      return 'Exceeds your balance';
    }
    return null;
  }

  bool get canReview =>
      recipient != null &&
      amount.value > 0 &&
      validation == null &&
      balanceStatus != BalanceStatus.loading;

  /// The most that can be sent now: the balance, capped at the per-transfer limit.
  double get maxSendable {
    final cap = AmountInput.maxAmount.toDouble();
    final available = balance?.toDouble() ?? cap;
    final limit = available < cap ? available : cap;
    // Whole paise only.
    return (limit * 100).floorToDouble() / 100;
  }

  TransferDraft? get draft => canReview
      ? TransferDraft(
          recipient: recipient!,
          amount: amount.value,
          remarks: remarks.trim().isEmpty ? null : remarks.trim(),
        )
      : null;

  SendMoneyState copyWith({
    Recipient? recipient,
    AmountInput? amount,
    String? remarks,
    num? balance,
    BalanceStatus? balanceStatus,
    String? message,
    int? failureId,
    bool clearMessage = false,
  }) => SendMoneyState(
    recipient: recipient ?? this.recipient,
    amount: amount ?? this.amount,
    remarks: remarks ?? this.remarks,
    balance: balance ?? this.balance,
    balanceStatus: balanceStatus ?? this.balanceStatus,
    message: clearMessage ? null : message ?? this.message,
    failureId: failureId ?? this.failureId,
  );

  @override
  List<Object?> get props => [
    recipient,
    amount,
    remarks,
    balance,
    balanceStatus,
    message,
    failureId,
  ];
}

class SendMoneyCubit extends Cubit<SendMoneyState> {
  SendMoneyCubit(this._repository, {Recipient? recipient})
    : super(SendMoneyState(recipient: recipient));
  final TransferRepository _repository;
  int _failures = 0;

  /// Reads the real balance from the API.
  Future<void> load() async {
    try {
      final balance = await _repository.availableBalance();
      if (!isClosed) {
        emit(
          state.copyWith(
            balance: balance,
            balanceStatus: BalanceStatus.ready,
            clearMessage: true,
          ),
        );
      }
    } on ApiException catch (error) {
      _balanceFailed(error.message);
    } catch (_) {
      _balanceFailed('Could not load your balance. Please try again.');
    }
  }

  void _balanceFailed(String message) {
    if (isClosed) return;
    emit(
      state.copyWith(
        balanceStatus: BalanceStatus.failed,
        message: message,
        failureId: ++_failures,
      ),
    );
  }

  void press(String key) =>
      emit(state.copyWith(amount: state.amount.press(key), clearMessage: true));

  void backspace() => emit(
    state.copyWith(amount: state.amount.backspace(), clearMessage: true),
  );

  /// "+₹500" chips.
  void add(num rupees) =>
      emit(state.copyWith(amount: state.amount.plus(rupees), clearMessage: true));

  /// The "₹1,500" chip.
  void set(num rupees) => emit(
    state.copyWith(amount: AmountInput.of(rupees), clearMessage: true),
  );

  void max() => emit(
    state.copyWith(
      amount: AmountInput.of(state.maxSendable),
      clearMessage: true,
    ),
  );

  void setRecipient(Recipient recipient) =>
      emit(state.copyWith(recipient: recipient, clearMessage: true));

  void setRemarks(String value) =>
      emit(state.copyWith(remarks: value, clearMessage: true));
}
