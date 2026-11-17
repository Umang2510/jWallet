import 'package:equatable/equatable.dart';

import 'recipient.dart';

/// What the user has asked to send. Immutable once they tap Review.
class TransferDraft extends Equatable {
  const TransferDraft({
    required this.recipient,
    required this.amount,
    this.remarks,
  });

  final Recipient recipient;

  /// Rupees, at most 2 decimals.
  final double amount;
  final String? remarks;

  /// The money-relevant fields, exactly as the server hashes them. The same
  /// map goes to both the challenge and the transfer call.
  Map<String, dynamic> toBody() => {
    'beneficiaryName': recipient.name,
    'mobileNumber': recipient.mobile,
    'amount': amount,
    if (remarks != null && remarks!.trim().isNotEmpty)
      'remarks': remarks!.trim(),
  };

  @override
  List<Object?> get props => [recipient, amount, remarks];
}

/// Server challenge: proof the user approved exactly this transfer.
class TransferChallenge extends Equatable {
  const TransferChallenge({
    required this.challengeId,
    required this.expiresAt,
    required this.signingPayload,
    required this.biometricOffered,
    required this.maskedMobile,
  });

  factory TransferChallenge.fromJson(Map<String, dynamic> json) =>
      TransferChallenge(
        challengeId: json['challengeId'] as String,
        expiresAt: DateTime.parse(json['expiresAt'] as String),
        signingPayload: json['signingPayload'] as String,
        biometricOffered: (json['approvalMethods'] as List<dynamic>).contains(
          'BIOMETRIC',
        ),
        maskedMobile:
            (json['summary'] as Map<String, dynamic>)['mobileNumber'] as String,
      );

  final String challengeId;
  final DateTime expiresAt;

  /// The exact text the biometric key signs.
  final String signingPayload;

  /// The server has a biometric key for this device (the phone may still have
  /// lost it; the repository checks that too).
  final bool biometricOffered;
  final String maskedMobile;

  /// Fresh enough to use. Challenges live 2 minutes on the server.
  bool isUsable([DateTime? now]) => expiresAt
      .subtract(const Duration(seconds: 15))
      .isAfter((now ?? DateTime.now()).toUtc());

  @override
  List<Object?> get props => [challengeId, expiresAt, signingPayload];
}

sealed class TransferApproval {
  const TransferApproval();
  Map<String, dynamic> toJson();
}

class PinApproval extends TransferApproval {
  const PinApproval(this.pin);
  final String pin;

  @override
  Map<String, dynamic> toJson() => {'method': 'PIN', 'pin': pin};
}

class BiometricApproval extends TransferApproval {
  const BiometricApproval(this.signature);
  final String signature;

  @override
  Map<String, dynamic> toJson() => {
    'method': 'BIOMETRIC',
    'signature': signature,
  };
}

/// The server's answer to a successful transfer.
class TransferReceipt extends Equatable {
  const TransferReceipt({
    required this.transactionId,
    required this.amount,
    required this.currency,
    required this.beneficiaryName,
    required this.maskedMobile,
    required this.remarks,
    required this.createdAt,
    required this.availableBalance,
  });

  factory TransferReceipt.fromJson(Map<String, dynamic> json) =>
      TransferReceipt(
        transactionId: json['transactionId'] as String,
        amount: json['amount'] as num,
        currency: json['currency'] as String,
        beneficiaryName: json['beneficiaryName'] as String,
        maskedMobile: json['mobileNumber'] as String?,
        remarks: json['remarks'] as String?,
        createdAt: json['createdAt'] as String,
        availableBalance: json['availableBalance'] as num,
      );

  final String transactionId;
  final num amount;
  final String currency;
  final String beneficiaryName;
  final String? maskedMobile;
  final String? remarks;
  final String createdAt;
  final num availableBalance;

  @override
  List<Object?> get props => [transactionId, amount, createdAt];
}
