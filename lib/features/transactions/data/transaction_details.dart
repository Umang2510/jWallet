import 'package:equatable/equatable.dart';

import '../../home/data/home_models.dart';
import '../../transfer/data/transfer_models.dart';

/// One transaction in full, from GET /transactions/:id.
class TransactionDetails extends Equatable {
  const TransactionDetails({
    required this.id,
    required this.type,
    required this.amount,
    required this.currency,
    required this.counterparty,
    required this.status,
    required this.createdAt,
    this.maskedMobile,
    this.remarks,
  });

  factory TransactionDetails.fromJson(Map<String, dynamic> json) {
    final item = TransactionItem.fromJson(json);
    return TransactionDetails(
      id: item.id,
      type: item.type,
      amount: item.amount,
      currency: json['currency'] as String,
      counterparty: item.counterparty,
      status: item.status,
      createdAt: item.createdAt,
      maskedMobile: json['mobileNumber'] as String?,
      remarks: json['remarks'] as String?,
    );
  }

  /// The receipt of a transfer that just succeeded, so the details screen can
  /// appear instantly (it still reloads the real record).
  factory TransactionDetails.fromReceipt(TransferReceipt receipt) =>
      TransactionDetails(
        id: receipt.transactionId,
        type: TransactionType.debit,
        amount: receipt.amount,
        currency: receipt.currency,
        counterparty: receipt.beneficiaryName,
        status: TransactionStatus.success,
        createdAt: receipt.createdAt,
        maskedMobile: receipt.maskedMobile,
        remarks: receipt.remarks,
      );

  final String id;
  final TransactionType type;
  final num amount;
  final String currency;
  final String counterparty;
  final TransactionStatus status;
  final String createdAt;
  final String? maskedMobile;
  final String? remarks;

  bool get isCredit => type == TransactionType.credit;

  @override
  List<Object?> get props => [
    id,
    type,
    amount,
    currency,
    counterparty,
    status,
    createdAt,
    maskedMobile,
    remarks,
  ];
}

/// What the details route is given: the receipt to show instantly, and whether
/// the user just came from a transfer (then "back" goes Home).
class TransactionDetailsArgs {
  const TransactionDetailsArgs({this.initial, this.fromTransfer = false});
  final TransactionDetails? initial;
  final bool fromTransfer;
}
