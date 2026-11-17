import 'package:equatable/equatable.dart';

import '../../../core/utils/formatters.dart';
import '../../home/data/quick_contacts.dart';

/// Who the money goes to. The transfer API only needs a name and a mobile
/// number; the UPI id and tick are display details.
class Recipient extends Equatable {
  const Recipient({
    required this.name,
    required this.mobile,
    required this.upiId,
    this.saved = false,
  });

  factory Recipient.fromContact(QuickContact contact) => Recipient(
    name: contact.name,
    mobile: contact.mobile,
    upiId: contact.upiId,
    saved: true,
  );

  /// Typed in by the user. The UPI id is derived, never asked for.
  factory Recipient.custom({required String name, required String mobile}) {
    final cleanName = name.trim().replaceAll(RegExp(r'\s+'), ' ');
    return Recipient(
      name: cleanName,
      mobile: mobile.trim(),
      upiId: '${mobile.trim()}@jwallet',
    );
  }

  final String name;
  final String mobile;
  final String upiId;

  /// A saved contact (shown with a verified tick).
  final bool saved;

  String get initials => Formatters.initials(name);

  /// "+91 98765 43210"
  String get displayMobile =>
      '+91 ${mobile.substring(0, 5)} ${mobile.substring(5)}';

  @override
  List<Object?> get props => [name, mobile, upiId, saved];
}
