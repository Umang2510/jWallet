import 'package:equatable/equatable.dart';

class UserProfile extends Equatable {
  const UserProfile({required this.name, required this.initials});

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    name: json['name'] as String,
    initials: json['initials'] as String,
  );

  final String name;
  final String initials;

  @override
  List<Object?> get props => [name, initials];
}

class WalletBalance extends Equatable {
  const WalletBalance({
    required this.walletId,
    required this.availableBalance,
    required this.currency,
    required this.maskedAccountNumber,
  });

  factory WalletBalance.fromJson(Map<String, dynamic> json) => WalletBalance(
    walletId: json['walletId'] as String,
    availableBalance: json['availableBalance'] as num,
    currency: json['currency'] as String,
    maskedAccountNumber: json['maskedAccountNumber'] as String,
  );

  final String walletId;

  /// Rupees, as sent by the server. Display only.
  final num availableBalance;
  final String currency;

  /// "XXXX XXXX 4589" from the server; only the last 4 digits are real.
  final String maskedAccountNumber;

  /// "•••• 4589" for the card.
  String get cardMask {
    final tail = maskedAccountNumber.length >= 4
        ? maskedAccountNumber.substring(maskedAccountNumber.length - 4)
        : maskedAccountNumber;
    return '•••• $tail';
  }

  @override
  List<Object?> get props => [
    walletId,
    availableBalance,
    currency,
    maskedAccountNumber,
  ];
}

enum TransactionType { credit, debit }

enum TransactionStatus { success, pending, failed }

class TransactionItem extends Equatable {
  const TransactionItem({
    required this.id,
    required this.type,
    required this.amount,
    required this.counterparty,
    required this.status,
    required this.createdAt,
  });

  factory TransactionItem.fromJson(Map<String, dynamic> json) =>
      TransactionItem(
        id: json['id'] as String,
        type: json['type'] == 'CREDIT'
            ? TransactionType.credit
            : TransactionType.debit,
        amount: json['amount'] as num,
        counterparty: json['beneficiaryName'] as String,
        status: switch (json['status']) {
          'SUCCESS' => TransactionStatus.success,
          'FAILED' => TransactionStatus.failed,
          _ => TransactionStatus.pending,
        },
        createdAt: json['createdAt'] as String,
      );

  final String id;
  final TransactionType type;
  final num amount;
  final String counterparty;
  final TransactionStatus status;

  /// Server ISO time (UTC).
  final String createdAt;

  bool get isCredit => type == TransactionType.credit;

  @override
  List<Object?> get props => [
    id,
    type,
    amount,
    counterparty,
    status,
    createdAt,
  ];
}

/// Everything the home screen shows, fetched together.
class HomeData extends Equatable {
  const HomeData({
    required this.profile,
    required this.wallet,
    required this.recent,
  });

  final UserProfile profile;
  final WalletBalance wallet;
  final List<TransactionItem> recent;

  @override
  List<Object?> get props => [profile, wallet, recent];
}
