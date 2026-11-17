import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../core/crypto/device_keys.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/validators.dart';
import '../data/transfer_models.dart';
import '../data/transfer_repository.dart';

enum TransferPhase {
  /// Asking the server to check the transfer and issue a challenge.
  preparing,

  /// Summary on screen; approve with biometrics or choose PIN.
  review,

  /// Entering the transaction PIN.
  pin,

  /// Money is moving (the light animation).
  processing,
  success,

  /// The server refused before anything was approved (balance, limit, ...).
  unavailable,
}

class TransferState extends Equatable {
  const TransferState({
    this.phase = TransferPhase.preparing,
    this.challenge,
    this.biometricAvailable = false,
    this.busy = false,
    this.pinEntered = 0,
    this.pinLocked = false,
    this.validation,
    this.message,
    this.failureId = 0,
    this.receipt,
  });

  final TransferPhase phase;
  final TransferChallenge? challenge;
  final bool biometricAvailable;

  /// The system fingerprint prompt is open.
  final bool busy;
  final int pinEntered;
  final bool pinLocked;

  /// Inline PIN hint (static, client side).
  final String? validation;

  /// Failure text: the API's `meta.message`, shown in a snackbar.
  final String? message;
  final int failureId;
  final TransferReceipt? receipt;

  TransferState copyWith({
    TransferPhase? phase,
    TransferChallenge? challenge,
    bool clearChallenge = false,
    bool? biometricAvailable,
    bool? busy,
    int? pinEntered,
    bool? pinLocked,
    String? validation,
    String? message,
    int? failureId,
    TransferReceipt? receipt,
  }) => TransferState(
    phase: phase ?? this.phase,
    challenge: clearChallenge ? null : challenge ?? this.challenge,
    biometricAvailable: biometricAvailable ?? this.biometricAvailable,
    busy: busy ?? this.busy,
    pinEntered: pinEntered ?? this.pinEntered,
    pinLocked: pinLocked ?? this.pinLocked,
    validation: validation,
    message: message,
    failureId: failureId ?? this.failureId,
    receipt: receipt ?? this.receipt,
  );

  @override
  List<Object?> get props => [
    phase,
    challenge,
    biometricAvailable,
    busy,
    pinEntered,
    pinLocked,
    validation,
    message,
    failureId,
    receipt,
  ];
}

/// Approve and send one transfer.
///
/// One idempotency key lives as long as this screen, so if the answer to
/// "send" is lost (bad network) and the user taps again, the server returns
/// the original result instead of paying twice.
class TransferCubit extends Cubit<TransferState> {
  TransferCubit(
    this._repository,
    this.draft, {
    this.minProcessing = const Duration(milliseconds: 2200),
    String Function()? newKey,
  }) : _key = (newKey ?? () => const Uuid().v4())(),
       super(const TransferState());

  final TransferRepository _repository;
  final TransferDraft draft;

  /// Keeps the processing animation on screen long enough to be seen.
  final Duration minProcessing;
  final String _key;
  String _pin = '';
  int _failures = 0;

  static const _challengeErrors = {
    'CHALLENGE_EXPIRED',
    'CHALLENGE_USED',
    'INVALID_CHALLENGE',
    'CHALLENGE_MISMATCH',
  };

  Future<void> prepare() async {
    emit(const TransferState());
    try {
      final challenge = await _repository.createChallenge(draft);
      final biometric = await _repository.canApproveWithBiometrics(challenge);
      if (isClosed) return;
      emit(
        TransferState(
          phase: TransferPhase.review,
          challenge: challenge,
          biometricAvailable: biometric,
        ),
      );
    } on ApiException catch (error) {
      _unavailable(error.message);
    } catch (_) {
      _unavailable('Something went wrong. Please try again.');
    }
  }

  void _unavailable(String message) {
    if (isClosed) return;
    emit(
      TransferState(
        phase: TransferPhase.unavailable,
        message: message,
        failureId: ++_failures,
      ),
    );
  }

  // ---- fingerprint ----

  Future<void> approveWithBiometrics() async {
    if (state.busy || state.phase != TransferPhase.review) return;
    emit(state.copyWith(busy: true));
    try {
      final challenge = await _usableChallenge();
      final approval = await _repository.approveWithBiometrics(challenge);
      if (isClosed) return;
      await _submit(approval, challenge, backTo: TransferPhase.review);
    } on DeviceSecurityException catch (error) {
      if (isClosed) return;
      if (error.cancelled) {
        emit(state.copyWith(busy: false));
        return;
      }
      // The phone's key is unusable (fingerprints changed, reset): use the PIN.
      final keyGone = error.code == 'KEY_INVALIDATED' || error.code == 'KEY_MISSING';
      emit(
        state.copyWith(
          busy: false,
          biometricAvailable: keyGone ? false : state.biometricAvailable,
          message: error.message,
          failureId: ++_failures,
        ),
      );
    } on ApiException catch (error) {
      _backTo(TransferPhase.review, error);
    } catch (_) {
      if (isClosed) return;
      emit(
        state.copyWith(
          busy: false,
          message: 'Something went wrong. Please try again.',
          failureId: ++_failures,
        ),
      );
    }
  }

  // ---- PIN ----

  void usePin() {
    if (state.busy || state.phase != TransferPhase.review) return;
    _pin = '';
    emit(state.copyWith(phase: TransferPhase.pin, pinEntered: 0));
  }

  void backToReview() {
    if (state.phase != TransferPhase.pin) return;
    _pin = '';
    emit(state.copyWith(phase: TransferPhase.review, pinEntered: 0));
  }

  void digit(String value) {
    if (state.phase != TransferPhase.pin ||
        state.pinLocked ||
        _pin.length >= 6 ||
        !RegExp(r'^\d$').hasMatch(value)) {
      return;
    }
    _pin += value;
    emit(state.copyWith(pinEntered: _pin.length));
  }

  void backspace() {
    if (state.phase != TransferPhase.pin || _pin.isEmpty) return;
    _pin = _pin.substring(0, _pin.length - 1);
    emit(state.copyWith(pinEntered: _pin.length));
  }

  /// Wipes a half-typed PIN (the app was backgrounded).
  void clearPin() {
    if (state.phase != TransferPhase.pin || _pin.isEmpty) return;
    _pin = '';
    emit(state.copyWith(pinEntered: 0));
  }

  Future<void> submitPin() async {
    if (state.phase != TransferPhase.pin || state.pinLocked) return;
    final invalid = Validators.existingPin(_pin);
    if (invalid != null) {
      emit(state.copyWith(validation: invalid));
      return;
    }
    final pin = _pin;
    _pin = '';
    emit(state.copyWith(pinEntered: 0));
    try {
      final challenge = await _usableChallenge();
      await _submit(PinApproval(pin), challenge, backTo: TransferPhase.pin);
    } on ApiException catch (error) {
      _backTo(TransferPhase.pin, error);
    } catch (_) {
      if (isClosed) return;
      emit(
        state.copyWith(
          message: 'Something went wrong. Please try again.',
          failureId: ++_failures,
        ),
      );
    }
  }

  // ---- sending ----

  /// A challenge that will still be valid when the server checks it (they live
  /// two minutes). Fetches a new one when needed.
  Future<TransferChallenge> _usableChallenge() async {
    final current = state.challenge;
    if (current != null && current.isUsable()) return current;
    final fresh = await _repository.createChallenge(draft);
    if (!isClosed) emit(state.copyWith(challenge: fresh));
    return fresh;
  }

  Future<void> _submit(
    TransferApproval approval,
    TransferChallenge challenge, {
    required TransferPhase backTo,
  }) async {
    emit(state.copyWith(phase: TransferPhase.processing, busy: false));
    final clock = Stopwatch()..start();
    try {
      final receipt = await _repository.transfer(
        draft: draft,
        challenge: challenge,
        approval: approval,
        idempotencyKey: _key,
      );
      final remaining = minProcessing - clock.elapsed;
      if (!remaining.isNegative) await Future<void>.delayed(remaining);
      if (isClosed) return;
      emit(state.copyWith(phase: TransferPhase.success, receipt: receipt));
    } on ApiException catch (error) {
      _backTo(backTo, error);
    } catch (_) {
      if (isClosed) return;
      emit(
        state.copyWith(
          phase: backTo,
          message: 'Something went wrong. Please try again.',
          failureId: ++_failures,
        ),
      );
    }
  }

  /// Back to the step the user was on, with the API's own message.
  void _backTo(TransferPhase phase, ApiException error) {
    if (isClosed) return;
    emit(
      state.copyWith(
        phase: phase,
        busy: false,
        pinEntered: 0,
        pinLocked: error.code == 'PIN_LOCKED',
        clearChallenge: _challengeErrors.contains(error.code),
        message: error.message,
        failureId: ++_failures,
      ),
    );
  }

  @override
  Future<void> close() {
    _pin = '';
    return super.close();
  }
}
