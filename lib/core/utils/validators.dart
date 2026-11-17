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

  /// A PIN being checked, not created: 4 or 6 digits.
  static String? existingPin(String? value) {
    if (!RegExp(r'^(\d{4}|\d{6})$').hasMatch(value ?? '')) return 'Enter your 4 or 6 digit transaction PIN';
    return null;
  }

  static String? confirmPin(String? value, String first) {
    if (value != first) return 'PINs do not match. Please try again.';
    return null;
  }

  /// A new PIN: exactly 4 or 6 digits. No pattern rules, so 1234 is allowed.
  static String? newPin(String? value) {
    if (!RegExp(r'^(\d{4}|\d{6})$').hasMatch(value ?? '')) {
      return 'PIN must be 4 or 6 digits';
    }
    return null;
  }
}
