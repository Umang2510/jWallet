import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_exception.dart';
import '../data/auth_repository.dart';

enum LoginStatus { initial, submitting, success, failure }

class LoginState extends Equatable {
  const LoginState({
    this.status = LoginStatus.initial,
    this.message,
    this.pinSet = false,
    this.biometricEnrolled = false,
    this.offerBiometricSetup = false,
  });
  final LoginStatus status;

  /// Failure text: the API's `meta.message`, shown in a snackbar.
  final String? message;
  final bool pinSet;
  final bool biometricEnrolled;
  final bool offerBiometricSetup;
  bool get isSubmitting => status == LoginStatus.submitting;
  @override
  List<Object?> get props => [
    status,
    message,
    pinSet,
    biometricEnrolled,
    offerBiometricSetup,
  ];
}

class LoginCubit extends Cubit<LoginState> {
  LoginCubit(this._repository) : super(const LoginState());
  final AuthRepository _repository;

  Future<void> submit({required String email, required String password}) async {
    if (state.isSubmitting || state.status == LoginStatus.success) return;
    emit(const LoginState(status: LoginStatus.submitting));
    try {
      final result = await _repository.login(email: email, password: password);
      if (!isClosed) {
        emit(
          LoginState(
            status: LoginStatus.success,
            pinSet: result.pinSet,
            biometricEnrolled: result.biometricEnrolled,
            offerBiometricSetup: result.offerBiometricSetup,
          ),
        );
      }
    } on ApiException catch (error) {
      if (!isClosed) {
        emit(LoginState(status: LoginStatus.failure, message: error.message));
      }
    } catch (_) {
      if (!isClosed) {
        emit(
          const LoginState(
            status: LoginStatus.failure,
            message: 'Unable to sign in securely. Please try again.',
          ),
        );
      }
    }
  }
}
