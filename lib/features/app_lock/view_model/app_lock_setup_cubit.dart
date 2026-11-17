import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/utils/validators.dart';
import '../data/app_lock_repository.dart';

enum AppLockSetupStep { create, confirm, complete }

class AppLockSetupState extends Equatable {
  const AppLockSetupState({
    this.step = AppLockSetupStep.create,
    this.length = 4,
    this.entered = 0,
    this.busy = false,
    this.message,
  });

  final AppLockSetupStep step;
  final int length;
  final int entered;
  final bool busy;

  /// Inline text under the dots (everything here happens on the phone).
  final String? message;

  @override
  List<Object?> get props => [step, length, entered, busy, message];
}

/// First-time app lock PIN, for phones that have no screen lock of their own.
/// Create + confirm, stored only on this phone.
class AppLockSetupCubit extends Cubit<AppLockSetupState> {
  AppLockSetupCubit(this._repository) : super(const AppLockSetupState());
  final AppLockRepository _repository;
  String _input = '';
  String _first = '';

  void digit(String value) {
    if (state.busy ||
        state.step == AppLockSetupStep.complete ||
        _input.length >= state.length ||
        !RegExp(r'^\d$').hasMatch(value)) {
      return;
    }
    _input += value;
    _emit();
  }

  void backspace() {
    if (state.busy || _input.isEmpty) return;
    _input = _input.substring(0, _input.length - 1);
    _emit();
  }

  void setLength(int length) {
    if (state.busy || state.step != AppLockSetupStep.create) return;
    if (length != 4 && length != 6) return;
    _input = _first = '';
    emit(AppLockSetupState(length: length));
  }

  void restart() {
    if (state.busy || state.step == AppLockSetupStep.complete) return;
    _input = _first = '';
    emit(AppLockSetupState(length: state.length));
  }

  void _emit({String? message, bool busy = false}) => emit(
    AppLockSetupState(
      step: state.step,
      length: state.length,
      entered: _input.length,
      message: message,
      busy: busy,
    ),
  );

  Future<void> next() async {
    if (state.busy || state.step == AppLockSetupStep.complete) return;
    if (state.step == AppLockSetupStep.create) {
      final error = Validators.newPin(_input);
      if (error != null) {
        _emit(message: error);
        return;
      }
      _first = _input;
      _input = '';
      emit(AppLockSetupState(step: AppLockSetupStep.confirm, length: state.length));
      return;
    }
    final mismatch = Validators.confirmPin(_input, _first);
    if (mismatch != null) {
      _input = '';
      _emit(message: mismatch);
      return;
    }
    final pin = _input;
    _emit(busy: true);
    try {
      await _repository.createPin(pin);
      if (!isClosed) {
        emit(
          AppLockSetupState(
            step: AppLockSetupStep.complete,
            length: state.length,
          ),
        );
      }
    } catch (_) {
      if (!isClosed) {
        emit(
          AppLockSetupState(
            length: state.length,
            message: 'Could not save your PIN. Please try again.',
          ),
        );
      }
    } finally {
      _input = _first = '';
    }
  }

  @override
  Future<void> close() {
    _input = _first = '';
    return super.close();
  }
}
