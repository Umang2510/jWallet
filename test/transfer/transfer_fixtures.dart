import 'package:j_wallet/features/home/data/quick_contacts.dart';
import 'package:j_wallet/features/transfer/data/recipient.dart';
import 'package:j_wallet/features/transfer/data/transfer_models.dart';

final rahul = Recipient.fromContact(quickContacts.first);

final draft = TransferDraft(
  recipient: rahul,
  amount: 1500,
  remarks: 'Dinner split & groceries',
);

TransferChallenge challenge({
  bool biometric = false,
  DateTime? expiresAt,
  String id = 'challenge-1',
}) => TransferChallenge(
  challengeId: id,
  expiresAt: expiresAt ?? DateTime.now().toUtc().add(const Duration(minutes: 2)),
  signingPayload: 'JWALLET-TRANSFER\n$id\nnonce\nhash',
  biometricOffered: biometric,
  maskedMobile: 'XXXXXX3210',
);

const receipt = TransferReceipt(
  transactionId: 'TXN20261117K7Q2MX',
  amount: 1500,
  currency: 'INR',
  beneficiaryName: 'Rahul Sharma',
  maskedMobile: 'XXXXXX3210',
  remarks: 'Dinner split & groceries',
  createdAt: '2026-11-17T04:00:00.000Z',
  availableBalance: 23950.75,
);

Map<String, dynamic> challengeJson({bool biometric = false}) => {
  'challengeId': 'c-1',
  'nonce': 'n',
  'expiresAt': DateTime.now().toUtc().add(const Duration(minutes: 2)).toIso8601String(),
  'approvalMethods': biometric ? ['BIOMETRIC', 'PIN'] : ['PIN'],
  'signingPayload': 'JWALLET-TRANSFER\nc-1\nn\nh',
  'summary': {
    'beneficiaryName': 'Rahul Sharma',
    'mobileNumber': 'XXXXXX3210',
    'amount': 1500,
    'currency': 'INR',
    'remarks': 'Dinner split & groceries',
  },
};

Map<String, dynamic> transferJson() => {
  'transactionId': 'TXN20261117K7Q2MX',
  'status': 'SUCCESS',
  'amount': 1500,
  'currency': 'INR',
  'availableBalance': 23950.75,
  'beneficiaryName': 'Rahul Sharma',
  'mobileNumber': 'XXXXXX3210',
  'remarks': 'Dinner split & groceries',
  'approvalMethod': 'PIN',
  'createdAt': '2026-11-17T04:00:00.000Z',
};
