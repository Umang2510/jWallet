import '../../../core/crypto/device_keys.dart';
import '../../../core/events/wallet_events.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/authenticated_client.dart';
import 'transfer_models.dart';

/// Balance, then the two-step transfer: ask for a challenge, then send the
/// approved transfer with an Idempotency-Key so a retry can never pay twice.
class TransferRepository {
  TransferRepository(this._client, this._keys, this._events);
  final AuthenticatedClient _client;
  final DeviceKeys _keys;
  final WalletEvents _events;

  Future<num> availableBalance() async {
    final body = await _client.request('GET', '/api/v1/wallet/balance');
    try {
      return body['availableBalance'] as num;
    } on TypeError {
      throw const ApiException(
        'Received an unexpected response. Please try again.',
      );
    }
  }

  /// Step 1: the server checks balance and limits and issues a challenge.
  Future<TransferChallenge> createChallenge(TransferDraft draft) async {
    final body = await _client.request(
      'POST',
      '/api/v1/transactions/transfer/challenge',
      body: draft.toBody(),
    );
    try {
      return TransferChallenge.fromJson(body);
    } on TypeError {
      throw const ApiException(
        'Received an unexpected response. Please try again.',
      );
    }
  }

  /// The server knows a biometric key for this phone AND the phone still has
  /// it (it is lost when fingerprints change or the phone is reset).
  Future<bool> canApproveWithBiometrics(TransferChallenge challenge) async {
    if (!challenge.biometricOffered) return false;
    final userId = (await _client.session())?['userId'] as String?;
    if (userId == null) return false;
    try {
      return await _keys.hasBiometricKey(userId);
    } on DeviceSecurityException {
      return false;
    }
  }

  /// Shows the system fingerprint/face prompt and signs the challenge.
  /// Throws [DeviceSecurityException] when cancelled or the key is gone.
  Future<BiometricApproval> approveWithBiometrics(
    TransferChallenge challenge,
  ) async {
    final userId = (await _client.session())?['userId'] as String?;
    if (userId == null) {
      throw const ApiException('Please sign in again.', statusCode: 401);
    }
    final signature = await _keys.signBiometric(
      userId,
      challenge.signingPayload,
    );
    return BiometricApproval(signature);
  }

  /// Step 2: move the money. Reusing the same [idempotencyKey] after a lost
  /// response returns the original result instead of paying again.
  Future<TransferReceipt> transfer({
    required TransferDraft draft,
    required TransferChallenge challenge,
    required TransferApproval approval,
    required String idempotencyKey,
  }) async {
    final body = await _client.request(
      'POST',
      '/api/v1/transactions/transfer',
      body: {
        ...draft.toBody(),
        'challengeId': challenge.challengeId,
        'approval': approval.toJson(),
      },
      headers: {'Idempotency-Key': idempotencyKey},
    );
    // The server accepted it: balances everywhere are now out of date.
    _events.notifyChanged();
    try {
      return TransferReceipt.fromJson(body);
    } on TypeError {
      // The money may have moved even though we cannot read the answer.
      throw const ApiException(
        'We could not confirm the result. Check your Activity before trying again.',
      );
    }
  }
}
