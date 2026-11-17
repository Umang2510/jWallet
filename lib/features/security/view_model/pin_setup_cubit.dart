import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/crypto/device_keys.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/validators.dart';
import '../data/security_repository.dart';

/// create -> confirm (the only two PIN entries) -> optional fingerprint -> done.
enum PinStep { create, confirm, biometric, complete }

class PinSetupState extends Equatable {
  const PinSetupState({
    this.step = PinStep.create,
    this.length = 4,
    this.entered = 0,
    this.busy = false,
    this.validation,
    this.message,
    this.code,
    this.biometricEnrolled = false,
  });

  final PinStep step;
  final int length;
  final int entered;
  final bool busy;

  /// Client-side check text, shown inline under the dots.
  final String? validation;

  /// Failure text from the API's `meta.message`, shown in a snackbar.
  final String? message;
  final String? code;
  final bool biometricEnrolled;

  @override
  List<Object?> get props => [
    step,
    length,
    entered,
    busy,
    validation,
    message,
    code,
    biometricEnrolled,
  ];
}

class PinSetupCubit extends Cubit<PinSetupState> {
  PinSetupCubit(this._repository) : super(const PinSetupState());
  final SecurityRepository _repository;
  String _input = '';
  String _first = '';

  /// The just-confirmed PIN, kept in memory only for the fingerprint step so
  /// the user is not asked for it a third time. Wiped as soon as the step ends.
  String _saved = '';

  void digit(String value) {
    final entering =
        state.step == PinStep.create || state.step == PinStep.confirm;
    if (state.busy ||
        !entering ||
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
    if (state.busy || state.step != PinStep.create) return;
    if (length != 4 && length != 6) return;
    _input = _first = '';
    emit(PinSetupState(length: length));
  }

  /// Back to the first entry (back arrow, or the app leaving the foreground).
  void restart() {
    if (state.busy) return;
    if (state.step != PinStep.create && state.step != PinStep.confirm) return;
    _input = _first = '';
    emit(PinSetupState(length: state.length));
  }

  void _emit({String? validation, bool busy = false}) => emit(
    PinSetupState(
      step: state.step,
      length: state.length,
      entered: _input.length,
      validation: validation,
      busy: busy,
    ),
  );

  Future<void> next() async {
    if (state.busy) return;
    if (state.step == PinStep.create) {
      final error = Validators.newPin(_input);
      if (error != null) {
        _emit(validation: error);
        return;
      }
      _first = _input;
      _input = '';
      emit(PinSetupState(step: PinStep.confirm, length: state.length));
      return;
    }
    if (state.step != PinStep.confirm) return;
    final mismatch = Validators.confirmPin(_input, _first);
    if (mismatch != null) {
      _input = '';
      _emit(validation: mismatch);
      return;
    }
    final pin = _input;
    _emit(busy: true);
    try {
      await _repository.setPin(pin);
      final canUseBiometrics = await _repository.biometricAvailable();
      if (isClosed) return;
      if (canUseBiometrics) {
        _saved = pin;
        emit(PinSetupState(step: PinStep.biometric, length: state.length));
      } else {
        emit(PinSetupState(step: PinStep.complete, length: state.length));
      }
    } on ApiException catch (error) {
      if (isClosed) return;
      // A PIN that already exists on the server is not a dead end.
      final exists = error.code == 'PIN_ALREADY_SET';
      emit(
        PinSetupState(
          step: exists ? PinStep.complete : PinStep.create,
          length: state.length,
          message: error.message,
          code: error.code,
        ),
      );
    } catch (_) {
      if (isClosed) return;
      emit(
        PinSetupState(
          length: state.length,
          message: 'Unable to set your PIN. Please try again.',
        ),
      );
    } finally {
      _input = _first = '';
    }
  }

  /// Fingerprint step: enroll using the PIN from this same flow.
  Future<void> enableBiometrics() async {
    if (state.busy || state.step != PinStep.biometric || _saved.isEmpty) return;
    emit(PinSetupState(step: PinStep.biometric, length: state.length, busy: true));
    try {
      await _repository.enrollBiometrics(_saved);
      _saved = '';
      if (!isClosed) {
        emit(
          PinSetupState(
            step: PinStep.complete,
            length: state.length,
            biometricEnrolled: true,
          ),
        );
      }
    } on ApiException catch (error) {
      if (!isClosed) {
        emit(
          PinSetupState(
            step: PinStep.biometric,
            length: state.length,
            message: error.message,
            code: error.code,
          ),
        );
      }
    } on DeviceSecurityException catch (error) {
      if (!isClosed) {
        emit(
          PinSetupState(
            step: PinStep.biometric,
            length: state.length,
            message: error.cancelled
                ? 'Biometric setup was cancelled. You can try again.'
                : error.message,
          ),
        );
      }
    } catch (_) {
      if (!isClosed) {
        emit(
          PinSetupState(
            step: PinStep.biometric,
            length: state.length,
            message: 'Unable to enable biometrics. Please try again.',
          ),
        );
      }
    }
  }

  /// Finish without biometrics. Also used when the app is backgrounded so the
  /// PIN never lingers in memory.
  void skipBiometrics() {
    if (state.busy || state.step != PinStep.biometric) return;
    _saved = '';
    emit(PinSetupState(step: PinStep.complete, length: state.length));
  }

  @override
  Future<void> close() {
    _input = _first = _saved = '';
    return super.close();
  }
}
