import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/network/api_exception.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../features/auth/data/auth_repository.dart';
import 'session_state.dart';

class SessionCubit extends Cubit<SessionState> {
  SessionCubit(this._repository)
    : super(const SessionState(status: SessionStatus.unknown)) {
    // The token refresh layer reports sessions it could not keep alive
    // (expired, revoked, device changed). Send the user back to login.
    _expiredSub = _repository.expired.listen(
      (error) => _signedOut(error.message),
    );
  }

  final AuthRepository _repository;
  late final StreamSubscription<ApiException> _expiredSub;
  bool _loggingOut = false;

  Future<void> start() async {
    try {
      final session = await _repository.restoreSession();
      if (isClosed) return;
      if (session != null) {
        loggedIn(
          pinSet: session.pinSet,
          biometricEnrolled: session.biometricEnrolled,
          restored: true,
        );
        return;
      }
    } on ApiException catch (error) {
      // Saved credentials stay intact for the next launch; tell the user why
      // they are looking at the login screen.
      _signedOut(error.message);
      return;
    } catch (_) {
      // A failed restore must not strand the app on the splash screen.
    }
    if (!isClosed) {
      emit(const SessionState(status: SessionStatus.unauthenticated));
    }
  }

  void loggedIn({
    required bool pinSet,
    bool biometricEnrolled = false,
    bool offerBiometricSetup = false,
    bool restored = false,
  }) => emit(
    SessionState(
      status: SessionStatus.authenticated,
      pinSet: pinSet,
      biometricEnrolled: biometricEnrolled,
      // Only meaningful once a PIN exists; the PIN screen comes first.
      biometricSetupPending: pinSet && offerBiometricSetup,
      restored: restored,
    ),
  );

  /// Transaction PIN saved. The PIN screen has already offered biometrics
  /// (and enrolled them, if the user agreed), so nothing else is pending.
  void pinCreated({bool biometricEnrolled = false}) => emit(
    SessionState(
      status: SessionStatus.authenticated,
      pinSet: true,
      biometricEnrolled: biometricEnrolled,
    ),
  );

  void biometricSetupFinished({required bool enrolled}) => emit(
    SessionState(
      status: SessionStatus.authenticated,
      pinSet: true,
      biometricEnrolled: enrolled,
    ),
  );

  /// A screen found the session unusable (for example the password login is
  /// too old to set a PIN). Drop the saved tokens and return to login.
  Future<void> requireSignIn(String message) async {
    try {
      await _repository.clearSession();
    } catch (_) {
      // Leaving the screen matters more than the storage cleanup.
    }
    _signedOut(message);
  }

  Future<void> logout() async {
    _loggingOut = true;
    try {
      await _repository.logout();
    } catch (_) {
      // Local logout still succeeds if the server is unreachable.
    } finally {
      _loggingOut = false;
    }
    if (!isClosed) {
      emit(const SessionState(status: SessionStatus.unauthenticated));
    }
  }

  void _signedOut(String message) {
    if (isClosed) return;
    emit(const SessionState(status: SessionStatus.unauthenticated));
    // A deliberate logout needs no "your session ended" notice.
    if (!_loggingOut) AppSnackbar.showGlobal(message);
  }

  @override
  Future<void> close() {
    _expiredSub.cancel();
    return super.close();
  }
}
