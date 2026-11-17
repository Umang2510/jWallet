import 'package:intl/intl.dart';

/// Display helpers. Formatting only — never used for money maths.
abstract final class Formatters {
  static final _inr = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );
  static final _date = DateFormat('d MMM yyyy');
  static final _dateTime = DateFormat('d MMM yyyy, h:mm a');

  /// 25450.75 -> ₹25,450.75 (Indian digit grouping).
  static String inr(num amount) => _inr.format(amount);

  /// Server ISO time (UTC) shown in the phone's local time zone.
  static String date(String iso) => _date.format(DateTime.parse(iso).toLocal());

  static String dateTime(String iso) =>
      _dateTime.format(DateTime.parse(iso).toLocal());

  /// "Demo User" -> "DU"
  static String initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '';
    final letters = parts.length > 1
        ? [parts.first[0], parts.last[0]]
        : [parts.first[0]];
    return letters.join().toUpperCase();
  }
}
