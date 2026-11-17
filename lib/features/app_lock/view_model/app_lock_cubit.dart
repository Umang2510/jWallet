import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/session/session_cubit.dart';
import '../../../app/session/session_state.dart';
import '../data/app_lock_repository.dart';

enum AppLockStatus {
  /// No signed-in session to protect (login, PIN setup, ...).
  idle,

  /// Working out how this phone should be locked.
  checking,

  /// The phone has no screen lock and no app lock PIN exists yet.
  setupRequired,
  locked,
  unlocked,
}

class AppLockState extends Equatable {
  const AppLockState({
    this.status = AppLockStatus.idle,
    this.method = AppLockMethod.deviceLock,
    this.pinLength = 4,
    this.entered = 0,
    this.busy = false,
    this.message,
  });

  final AppLockStatus status;
  final AppLockMethod method;
  final int pinLength;
  final int entered;
  final bool busy;

  /// Client-side status text (wrong PIN, cancelled prompt, lockout).
  final String? message;

  AppLockState copyWith({
    AppLockStatus? status,
    int? entered,
    bool? busy,
    String? message,
    bool clearMessage = false,
  }) => AppLockState(
    status: status ?? this.status,
    method: method,
    pinLength: pinLength,
    entered: entered ?? this.entered,
    busy: busy ?? this.busy,
    message: clearMessage ? null : message ?? this.message,
  );

  @override
  List<Object?> get props => [
    status,
    method,
    pinLength,
    entered,
    busy,
    message,
  ];
}

/// Decides whether the app is locked and unlocks it. The lock engages when a
/// restored session starts, and again when the app comes back after being in
/// the background for [timeout]. A login made just now never prompts again.
class AppLockCubit extends Cubit<AppLockState> {
  AppLockCubit(
    this._repository,
    this._session, {
    this.timeout = const Duration(seconds: 30),
    DateTime Function()? clock,
  }) : _now = clock ?? DateTime.now,
       super(const AppLockState()) {
    _sessionSub = _session.stream.listen(_onSession);
    _onSession(_session.state);
  }

  final AppLockRepository _repository;
  final SessionCubit _session;
  final Duration timeout;
  final DateTime Function() _now;
  late final StreamSubscription<SessionState> _sessionSub;

  bool _ready = false;
  bool _authenticating = false;
  DateTime? _pausedAt;
  DateTime? _unlockedAt;
  String _pin = '';

  void _onSession(SessionState session) {
    if (!session.isReady) {
      _ready = false;
      _pin = '';
      if (state.status != AppLockStatus.idle) emit(const AppLockState());
      return;
    }
    if (_ready) return;
    _ready = true;
    _evaluate(requireUnlock: session.restored);
  }

  Future<void> _evaluate({required bool requireUnlock}) async {
    _pin = '';
    emit(const AppLockState(status: AppLockStatus.checking));
    final method = await _repository.method();
    var length = 4;
    var needsSetup = false;
    if (method == AppLockMethod.pin) {
      needsSetup = !await _repository.hasPin();
      length = await _repository.pinLength() ?? 4;
    }
    if (isClosed || !_ready) return;
    final status = needsSetup
        ? AppLockStatus.setupRequired
        : requireUnlock
        ? AppLockStatus.locked
        : AppLockStatus.unlocked;
    if (status == AppLockStatus.unlocked) _unlockedAt = _now();
    emit(AppLockState(status: status, method: method, pinLength: length));
  }

  // ---- background / foreground ----

  void appPaused() => _pausedAt = _now();

  void appResumed() {
    final pausedAt = _pausedAt;
    _pausedAt = null;
    if (pausedAt == null || !_ready) return;
    if (state.status != AppLockStatus.unlocked || _authenticating) return;
    // The system unlock prompt itself backgrounds the app on some phones.
    final unlockedAt = _unlockedAt;
    if (unlockedAt != null &&
        _now().difference(unlockedAt) < const Duration(seconds: 5)) {
      return;
    }
    if (_now().difference(pausedAt) >= timeout) {
      _evaluate(requireUnlock: true);
    }
  }

  // ---- unlocking ----

  /// Phone screen lock (fingerprint, face, or the phone's PIN/pattern).
  Future<void> unlockWithDevice() async {
    if (state.busy ||
        state.status != AppLockStatus.locked ||
        state.method != AppLockMethod.deviceLock) {
      return;
    }
    _authenticating = true;
    emit(state.copyWith(busy: true, clearMessage: true));
    try {
      final unlocked = await _repository.authenticateWithDevice();
      if (isClosed) return;
      if (unlocked) {
        _markUnlocked();
      } else {
        emit(
          state.copyWith(
            busy: false,
            message: 'Unlock was cancelled. Tap Unlock to try again.',
          ),
        );
      }
    } catch (_) {
      if (!isClosed) {
        emit(
          state.copyWith(
            busy: false,
            message: 'Could not check your screen lock. Please try again.',
          ),
        );
      }
    } finally {
      _authenticating = false;
    }
  }

  void digit(String value) {
    if (state.busy ||
        state.status != AppLockStatus.locked ||
        state.method != AppLockMethod.pin ||
        _pin.length >= state.pinLength ||
        !RegExp(r'^\d$').hasMatch(value)) {
      return;
    }
    _pin += value;
    emit(state.copyWith(entered: _pin.length, clearMessage: true));
  }

  void backspace() {
    if (state.busy || _pin.isEmpty) return;
    _pin = _pin.substring(0, _pin.length - 1);
    emit(state.copyWith(entered: _pin.length));
  }

  Future<void> unlockWithPin() async {
    if (state.busy ||
        state.status != AppLockStatus.locked ||
        state.method != AppLockMethod.pin) {
      return;
    }
    if (_pin.length != state.pinLength) {
      emit(state.copyWith(message: 'Enter your ${state.pinLength}-digit PIN'));
      return;
    }
    final pin = _pin;
    _pin = '';
    emit(state.copyWith(busy: true, entered: 0, clearMessage: true));
    try {
      final check = await _repository.verifyPin(pin);
      if (isClosed) return;
      switch (check.status) {
        case PinCheckStatus.correct:
          _markUnlocked();
        case PinCheckStatus.wrong:
          final left = check.attemptsLeft;
          emit(
            state.copyWith(
              busy: false,
              message:
                  'Incorrect PIN. $left attempt${left == 1 ? '' : 's'} left.',
            ),
          );
        case PinCheckStatus.locked:
          final minutes = ((check.lockedFor?.inSeconds ?? 60) / 60).ceil();
          emit(
            state.copyWith(
              busy: false,
              message:
                  'Too many attempts. Try again in $minutes '
                  'minute${minutes == 1 ? '' : 's'}.',
            ),
          );
        case PinCheckStatus.notSet:
          _evaluate(requireUnlock: true);
      }
    } catch (_) {
      if (!isClosed) {
        emit(
          state.copyWith(
            busy: false,
            message: 'Could not check your PIN. Please try again.',
          ),
        );
      }
    }
  }

  /// The first-time app lock PIN was saved.
  void setupCompleted() {
    if (state.status != AppLockStatus.setupRequired) return;
    _markUnlocked();
  }

  void _markUnlocked() {
    _pin = '';
    _pausedAt = null;
    _unlockedAt = _now();
    emit(
      AppLockState(
        status: AppLockStatus.unlocked,
        method: state.method,
        pinLength: state.pinLength,
      ),
    );
  }

  @override
  Future<void> close() {
    _pin = '';
    _sessionSub.cancel();
    return super.close();
  }
}
