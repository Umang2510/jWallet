import 'package:j_wallet/features/home/data/home_models.dart';

const demoProfile = UserProfile(name: 'Demo User', initials: 'DU');

const demoWallet = WalletBalance(
  walletId: 'WALLET20001',
  availableBalance: 25450.75,
  currency: 'INR',
  maskedAccountNumber: 'XXXX XXXX 4589',
);

final demoRecent = [
  TransactionItem(
    id: 'TXN1',
    type: TransactionType.debit,
    amount: 1500,
    counterparty: 'Rahul Sharma',
    status: TransactionStatus.success,
    createdAt: DateTime.now().toUtc().toIso8601String(),
  ),
  TransactionItem(
    id: 'TXN2',
    type: TransactionType.credit,
    amount: 45000,
    counterparty: 'Tech Corp Payroll',
    status: TransactionStatus.success,
    createdAt: DateTime.now()
        .subtract(const Duration(days: 1))
        .toUtc()
        .toIso8601String(),
  ),
  TransactionItem(
    id: 'TXN3',
    type: TransactionType.debit,
    amount: 420.5,
    counterparty: 'Swiggy Food Delivery',
    status: TransactionStatus.pending,
    createdAt: DateTime.now()
        .subtract(const Duration(days: 9))
        .toUtc()
        .toIso8601String(),
  ),
];

HomeData demoHome({List<TransactionItem>? recent}) =>
    HomeData(profile: demoProfile, wallet: demoWallet, recent: recent ?? demoRecent);

Map<String, dynamic> profileJson() => {
  'id': 'USR10001',
  'name': 'Demo User',
  'email': 'demo@jstack.co',
  'initials': 'DU',
  'memberSince': '2026-01-01T00:00:00.000Z',
  'security': {'pinSet': true, 'biometricEnrolled': false},
};

Map<String, dynamic> balanceJson() => {
  'walletId': 'WALLET20001',
  'currency': 'INR',
  'availableBalance': 25450.75,
  'maskedAccountNumber': 'XXXX XXXX 4589',
  'status': 'ACTIVE',
  'updatedAt': '2026-11-17T08:00:00.000Z',
};

Map<String, dynamic> transactionsJson() => {
  'items': [
    {
      'id': 'TXN20261117AAAAAA',
      'type': 'DEBIT',
      'amount': 1500,
      'currency': 'INR',
      'beneficiaryName': 'Rahul Sharma',
      'status': 'SUCCESS',
      'createdAt': '2026-11-17T04:00:00.000Z',
    },
    {
      'id': 'TXN20261116BBBBBB',
      'type': 'CREDIT',
      'amount': 45000.5,
      'currency': 'INR',
      'beneficiaryName': 'Tech Corp Payroll',
      'status': 'FAILED',
      'createdAt': '2026-11-16T04:00:00.000Z',
    },
  ],
  'pagination': {
    'page': 1,
    'limit': 5,
    'totalItems': 2,
    'totalPages': 1,
    'hasNextPage': false,
  },
};
