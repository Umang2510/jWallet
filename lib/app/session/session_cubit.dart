import 'package:flutter_bloc/flutter_bloc.dart';

import '../../features/auth/data/auth_repository.dart';
import 'session_state.dart';

class SessionCubit extends Cubit<SessionState> {
  SessionCubit(this._repository)
    : super(const SessionState(status: SessionStatus.unknown));
  final AuthRepository _repository;

  Future<void> start() async {
    try {
      final session = await _repository.restoreSession();
      if (isClosed) return;
      if (session != null) {
        loggedIn(pinSet: session.pinSet);
        return;
      }
    } catch (_) {
      // A failed restore must not strand the app on the splash screen.
      // Network failures leave saved credentials intact for the next launch.
    }
    if (!isClosed) {
      emit(const SessionState(status: SessionStatus.unauthenticated));
    }
  }

  void loggedIn({required bool pinSet}) =>
      emit(SessionState(status: SessionStatus.authenticated, pinSet: pinSet));
  void pinCreated() => emit(
    const SessionState(status: SessionStatus.authenticated, pinSet: true),
  );

  Future<void> logout() async {
    try {
      await _repository.logout();
    } catch (_) {
      // Local logout still succeeds if the server is unreachable.
    }
    if (!isClosed) {
      emit(const SessionState(status: SessionStatus.unauthenticated));
    }
  }
}
