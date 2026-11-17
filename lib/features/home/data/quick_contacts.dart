/// Quick Send shortcuts. The API has no "frequent contacts" endpoint, so these
/// are local demo contacts for now.
class QuickContact {
  const QuickContact({
    required this.name,
    required this.label,
    required this.initials,
    required this.mobile,
    required this.upiId,
    this.isBusiness = false,
  });

  final String name;

  /// Short name under the avatar.
  final String label;
  final String initials;

  /// 10-digit Indian mobile number (what the transfer API takes).
  final String mobile;
  final String upiId;
  final bool isBusiness;
}

const quickContacts = [
  QuickContact(
    name: 'Rahul Sharma',
    label: 'Rahul',
    initials: 'RS',
    mobile: '9876543210',
    upiId: 'rahul@okaxis',
  ),
  QuickContact(
    name: 'Priya Patel',
    label: 'Priya',
    initials: 'PP',
    mobile: '9988776655',
    upiId: 'priya@okhdfc',
  ),
  QuickContact(
    name: 'Tech Corp',
    label: 'TechCorp',
    initials: 'TC',
    mobile: '8123456789',
    upiId: 'techcorp@oksbi',
    isBusiness: true,
  ),
];
