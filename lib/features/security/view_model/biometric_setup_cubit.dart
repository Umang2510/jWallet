import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/crypto/device_keys.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/validators.dart';
import '../data/security_repository.dart';

class BiometricSetupState extends Equatable {
  const BiometricSetupState({this.checking = true, this.available = false, this.busy = false, this.complete = false, this.entered = 0, this.validation, this.message, this.code, this.locked = false});
  final bool checking, available, busy, complete, locked;
  final int entered;
  final String? validation, message, code;
  @override
  List<Object?> get props => [checking, available, busy, complete, entered, validation, message, code, locked];
}

class BiometricSetupCubit extends Cubit<BiometricSetupState> {
  BiometricSetupCubit(this._repository) : super(const BiometricSetupState());
  final SecurityRepository _repository;
  String _pin = '';

  Future<void> checkAvailability() async {
    if (state.busy) return;
    final available = await _repository.biometricAvailable();
    if (!isClosed) emit(BiometricSetupState(checking: false, available: available, locked: state.locked));
  }
  void digit(String digit) {
    if (state.busy || state.locked || !state.available || _pin.length == 6 || !RegExp(r'^\d$').hasMatch(digit)) return;
    _pin += digit;
    _emit();
  }
  void backspace() {
    if (state.busy || _pin.isEmpty) return;
    _pin = _pin.substring(0, _pin.length - 1);
    _emit();
  }
  void clearInput() { _pin = ''; if (!state.busy) _emit(); }
  void _emit({bool busy = false, String? validation, String? message, String? code, bool complete = false, bool? locked}) => emit(BiometricSetupState(checking: false, available: state.available, busy: busy, entered: _pin.length, validation: validation, message: message, code: code, complete: complete, locked: locked ?? state.locked));

  Future<void> enroll() async {
    if (state.busy || state.checking || !state.available || state.locked || state.complete) return;
    final validation = Validators.existingPin(_pin);
    if (validation != null) { _emit(validation: validation); return; }
    final pin = _pin;
    _pin = '';
    _emit(busy: true);
    try {
      await _repository.enrollBiometrics(pin);
      if (!isClosed) _emit(complete: true);
    } on ApiException catch (error) {
      if (!isClosed) _emit(message: error.message, code: error.code, locked: error.code == 'PIN_LOCKED');
    } on DeviceSecurityException catch (error) {
      if (!isClosed) _emit(message: error.cancelled ? 'Biometric setup was cancelled. You can try again.' : error.message);
    } catch (_) {
      if (!isClosed) _emit(message: 'Unable to enable biometrics. Please try again.');
    }
  }

  @override
  Future<void> close() { _pin = ''; return super.close(); }
}
