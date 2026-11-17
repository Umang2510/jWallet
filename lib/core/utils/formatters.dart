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

  /// "Today, 9:41 AM" / "Yesterday, 10:00 AM" / "24 Oct, 8:45 PM".
  /// [now] is injectable for tests.
  static String relativeDateTime(String iso, {DateTime? now}) {
    final time = DateTime.parse(iso).toLocal();
    final today = _dayOnly(now ?? DateTime.now());
    final days = today.difference(_dayOnly(time)).inDays;
    final clock = DateFormat('h:mm a').format(time);
    if (days == 0) return 'Today, $clock';
    if (days == 1) return 'Yesterday, $clock';
    return '${DateFormat('d MMM').format(time)}, $clock';
  }

  static DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

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
