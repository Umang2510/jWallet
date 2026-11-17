import 'package:j_wallet/features/activity/data/activity_models.dart';
import 'package:j_wallet/features/home/data/home_models.dart';

/// A local-time moment as the server's ISO UTC string.
String at(DateTime local) => local.toUtc().toIso8601String();

TransactionItem txn(
  String id, {
  String name = 'Rahul Sharma',
  TransactionType type = TransactionType.debit,
  TransactionStatus status = TransactionStatus.success,
  num amount = 1500,
  DateTime? when,
}) => TransactionItem(
  id: id,
  type: type,
  amount: amount,
  counterparty: name,
  status: status,
  createdAt: at(when ?? DateTime.now()),
);

TransactionPage page(
  List<TransactionItem> items, {
  int page = 1,
  int? total,
  bool hasNext = false,
}) => TransactionPage(
  items: items,
  page: page,
  totalItems: total ?? items.length,
  hasNextPage: hasNext,
);

/// Rows across three days, newest first: 2 today, 2 yesterday, 1 older.
List<TransactionItem> sampleItems() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return [
    txn('TXN-A1', when: today.add(const Duration(hours: 1, minutes: 5))),
    txn(
      'TXN-A2',
      name: 'Deepa Nair',
      type: TransactionType.credit,
      amount: 2400,
      when: today.add(const Duration(hours: 1)),
    ),
    txn(
      'TXN-B1',
      name: 'Tech Corp Payroll',
      type: TransactionType.credit,
      amount: 45000,
      when: today.subtract(const Duration(hours: 5)),
    ),
    txn(
      'TXN-B2',
      name: 'Swiggy Food Delivery',
      amount: 420.5,
      status: TransactionStatus.pending,
      when: today.subtract(const Duration(hours: 9)),
    ),
    txn(
      'TXN-C1',
      name: 'Metro Card Recharge',
      amount: 200,
      status: TransactionStatus.failed,
      when: today.subtract(const Duration(days: 4)),
    ),
  ];
}

Map<String, dynamic> pageJson(
  List<Map<String, dynamic>> items, {
  int page = 1,
  int? total,
  bool hasNext = false,
}) => {
  'items': items,
  'pagination': {
    'page': page,
    'limit': 20,
    'totalItems': total ?? items.length,
    'totalPages': hasNext ? page + 1 : page,
    'hasNextPage': hasNext,
  },
};
