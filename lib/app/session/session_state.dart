import 'package:equatable/equatable.dart';

enum SessionStatus {
  /// App just started, still checking for a saved session (splash screen).
  unknown,
  unauthenticated,
  authenticated,
}

/// App-wide login state. The router decides which screen to show from it.
class SessionState extends Equatable {
  const SessionState({required this.status, this.pinSet = false});

  final SessionStatus status;
  final bool pinSet;

  bool get isAuthenticated => status == SessionStatus.authenticated;

  @override
  List<Object?> get props => [status, pinSet];
}
