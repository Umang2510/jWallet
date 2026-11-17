/// Quick Send shortcuts. The API has no "frequent contacts" endpoint, so these
/// are local for now.
class QuickContact {
  const QuickContact({
    required this.name,
    required this.label,
    required this.initials,
    this.isBusiness = false,
  });

  final String name;

  /// Short name under the avatar.
  final String label;
  final String initials;
  final bool isBusiness;
}

const quickContacts = [
  QuickContact(name: 'Rahul Sharma', label: 'Rahul', initials: 'RS'),
  QuickContact(name: 'Priya Patel', label: 'Priya', initials: 'PP'),
  QuickContact(
    name: 'Tech Corp',
    label: 'TechCorp',
    initials: 'TC',
    isBusiness: true,
  ),
];
