import 'package:equatable/equatable.dart';

enum SessionStatus {
  /// App just started, still checking for a saved session (splash screen).
  unknown,
  unauthenticated,
  authenticated,
}

/// App-wide login state. The router decides which screen to show from it.
class SessionState extends Equatable {
  const SessionState({
    required this.status,
    this.pinSet = false,
    this.biometricEnrolled = false,
    this.biometricSetupPending = false,
    this.restored = false,
  });

  final SessionStatus status;
  final bool pinSet;

  /// Biometric approval is active on this device.
  final bool biometricEnrolled;

  /// The user should be offered biometric setup before reaching the app.
  final bool biometricSetupPending;

  /// The session came from saved credentials at app launch (not a login just
  /// made), so the app lock must be passed before showing anything.
  final bool restored;

  bool get isAuthenticated => status == SessionStatus.authenticated;

  /// Signed in and through every setup step: the app itself can be shown.
  bool get isReady => isAuthenticated && pinSet && !biometricSetupPending;

  @override
  List<Object?> get props => [
    status,
    pinSet,
    biometricEnrolled,
    biometricSetupPending,
    restored,
  ];
}
