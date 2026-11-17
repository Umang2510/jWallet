import 'package:intl/intl.dart';

/// The amount being typed on the keypad. Pure logic, no widgets.
///
/// Rules: digits and one "."; at most 2 decimals; no leading zeros; and a digit
/// that would push the amount over [maxAmount] is ignored (like a bank app).
class AmountInput {
  const AmountInput([this.text = '']);

  /// Per-transfer limit in rupees (matches the server's default).
  static const maxAmount = 100000;

  static final _grouped = NumberFormat.decimalPattern('en_IN');

  /// What was typed, e.g. "", "0.", "1500", "25.5".
  final String text;

  bool get isEmpty => text.isEmpty;

  /// The amount in rupees.
  double get value {
    if (text.isEmpty) return 0;
    return double.parse(text.endsWith('.') ? '${text}0' : text);
  }

  AmountInput press(String key) {
    if (key == '.') {
      if (text.contains('.')) return this;
      return AmountInput(text.isEmpty ? '0.' : '$text.');
    }
    if (!RegExp(r'^\d$').hasMatch(key)) return this;
    final dot = text.indexOf('.');
    if (dot != -1 && text.length - dot > 2) return this; // already 2 decimals
    if (text == '0') {
      if (key == '0') return this;
      return _within(key);
    }
    return _within('$text$key');
  }

  AmountInput backspace() =>
      text.isEmpty ? this : AmountInput(text.substring(0, text.length - 1));

  /// "+₹500": adds to what is there, stopping at the limit.
  AmountInput plus(num amount) => AmountInput.of(
    (value + amount) > maxAmount ? maxAmount : value + amount,
  );

  /// Sets an exact amount (a chip, or Max).
  factory AmountInput.of(num amount) {
    final fixed = amount.toStringAsFixed(2);
    final trimmed = fixed.replaceFirst(RegExp(r'\.?0+$'), '');
    return AmountInput(trimmed == '0' ? '' : trimmed);
  }

  AmountInput _within(String candidate) {
    final next = AmountInput(candidate);
    return next.value > maxAmount ? this : next;
  }

  /// "1,500" with Indian digit grouping.
  String get wholePart {
    final whole = text.split('.').first;
    return _grouped.format(whole.isEmpty ? 0 : int.parse(whole));
  }

  /// "00", "50", "5" padded to two digits, e.g. ".50".
  String get fractionPart {
    final parts = text.split('.');
    final typed = parts.length > 1 ? parts[1] : '';
    return typed.padRight(2, '0');
  }

  @override
  bool operator ==(Object other) => other is AmountInput && other.text == text;

  @override
  int get hashCode => text.hashCode;
}
