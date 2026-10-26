// Account directory filtering for the Users page. It mirrors web/src/user-directory.js: every word typed must appear in the
// account, and office, role and status narrow the list together.

class AccountFilters {
  const AccountFilters({
    this.query = '',
    this.office = '',
    this.role = '',
    this.status = '',
  });

  final String query;

  /// An office code such as `ACC`; empty means every office.
  final String office;

  /// `staff`, `head` or `admin`; empty means every role.
  final String role;

  /// `active` or `inactive`; empty means any status.
  final String status;

  /// True only when something is chosen (typing only spaces is not).
  bool get active =>
      query.trim().isNotEmpty ||
      office.isNotEmpty ||
      role.isNotEmpty ||
      status.isNotEmpty;

  AccountFilters copyWith({
    String? query,
    String? office,
    String? role,
    String? status,
  }) => AccountFilters(
    query: query ?? this.query,
    office: office ?? this.office,
    role: role ?? this.role,
    status: status ?? this.status,
  );
}

const emptyAccountFilters = AccountFilters();

String _text(Object? value) => '${value ?? ''}'.toLowerCase();

/// Whether [row] passes [filters]. A sign-up request names its role `requested_role`, so pass that as [roleKey];
/// [status] is only checked when the row has an `is_active` value to check.
bool matchesAccountFilters(
  Map row,
  AccountFilters filters, {
  String roleKey = 'role',
  bool checkStatus = true,
}) {
  if (filters.office.isNotEmpty && row['office_code'] != filters.office) {
    return false;
  }
  if (filters.role.isNotEmpty && row[roleKey] != filters.role) return false;
  if (checkStatus) {
    // An account is active unless the server says it is not.
    if (filters.status == 'active' && row['is_active'] == false) return false;
    if (filters.status == 'inactive' && row['is_active'] != false) {
      return false;
    }
  }
  final words = _text(
    filters.query,
  ).split(RegExp(r'\s+')).where((word) => word.isNotEmpty);
  if (words.isEmpty) return true;
  final haystack = [
    row['name'],
    row['full_name'],
    row['username'],
    row['email'],
    row['office_code'],
    row['office_name'],
  ].map(_text).join(' ');
  return words.every(haystack.contains);
}

List<Map<String, dynamic>> filterAccounts(
  Iterable<Map<String, dynamic>> users, [
  AccountFilters filters = emptyAccountFilters,
]) => [
  for (final row in users)
    if (matchesAccountFilters(row, filters)) row,
];

/// Office choices come from the accounts: sorted, without repeats.
List<String> officeCodes(Iterable<Map>? users) => {
  for (final row in users ?? const <Map>[])
    if ('${row['office_code'] ?? ''}'.isNotEmpty) '${row['office_code']}',
}.toList()..sort();
