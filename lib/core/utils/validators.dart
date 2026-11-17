/// Form validators. Each returns an error message, or null when valid, so
/// they plug straight into TextFormField(validator: ...).
///
/// They mirror the backend rules so users see problems before submitting;
/// the backend still validates everything again.
abstract final class Validators {
  static final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
  static final _mobile = RegExp(r'^[6-9]\d{9}$');
  static final _name = RegExp(r"^[\p{L}][\p{L} .'-]*$", unicode: true);
  static final _amount = RegExp(r'^\d+(\.\d{1,2})?$');

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Email is required';
    if (v.length > 254) return 'Email must be 254 characters or fewer';
    if (!_email.hasMatch(v)) return 'Enter a valid email address';
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length > 128) return 'Password must be 128 characters or fewer';
    return null;
  }

  static String? beneficiaryName(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Beneficiary name is required';
    if (v.length > 100) return 'Name is too long';
    if (!_name.hasMatch(v)) return 'Use letters and spaces only';
    return null;
  }

  static String? mobile(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Mobile number is required';
    if (!_mobile.hasMatch(v)) return 'Enter a valid 10-digit mobile number';
    return null;
  }

  /// [max] = per-transfer limit in rupees.
  static String? amount(String? value, {num max = 100000}) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Amount is required';
    if (!_amount.hasMatch(v)) return 'Enter a valid amount (max 2 decimals)';
    final n = num.parse(v);
    if (n <= 0) return 'Amount must be greater than zero';
    if (n > max) return 'Maximum per transfer is ₹$max';
    return null;
  }

  static String? remarks(String? value) {
    if ((value?.trim().length ?? 0) > 100) return 'Max 100 characters';
    return null;
  }

  /// UPI-style PIN: 4 or 6 digits, not trivially guessable.
  static String? newPin(String? value) {
    final v = value ?? '';
    if (!RegExp(r'^(\d{4}|\d{6})$').hasMatch(v)) {
      return 'PIN must be 4 or 6 digits';
    }
    if (isWeakPin(v)) {
      return 'Too easy to guess. Avoid repeated or sequential digits.';
    }
    return null;
  }

  /// Same rules as the backend: 0000, 1234, 4321, 1212, 121212 ...
  static bool isWeakPin(String pin) {
    if (RegExp(r'^(\d)\1+$').hasMatch(pin)) return true;
    final d = pin.split('').map(int.parse).toList();
    final steps = [for (var i = 1; i < d.length; i++) d[i] - d[i - 1]];
    if (steps.every((s) => s == 1) || steps.every((s) => s == -1)) return true;
    if (pin.length == 4 && pin.substring(0, 2) == pin.substring(2)) return true;
    if (pin.length == 6 && RegExp(r'^(\d\d)\1\1$').hasMatch(pin)) return true;
    return false;
  }
}
