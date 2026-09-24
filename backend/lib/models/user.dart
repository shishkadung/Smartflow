class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.username,
    required this.role,
    required this.officeId,
    required this.officeName,
    required this.officeCode,
  });

  final int id;
  final String name;
  final String username;
  final String role;
  final int officeId;
  final String officeName;
  final String officeCode;

  bool get isStaff => role == 'staff';
  bool get isHead => role == 'head';
  bool get isAdmin => role == 'admin';

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: j['id'] as int,
        name: j['name'] as String,
        username: j['username'] as String,
        role: j['role'] as String,
        officeId: j['office_id'] as int,
        officeName: j['office_name'] as String,
        officeCode: j['office_code'] as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'username': username,
        'role': role,
        'office_id': officeId,
        'office_name': officeName,
        'office_code': officeCode,
      };
}
