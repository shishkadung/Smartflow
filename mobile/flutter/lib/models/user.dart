class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.username,
    required this.role,
    required this.officeId,
    required this.officeName,
    required this.officeCode,
    this.email,
    this.avatarUrl,
  });

  final int id;
  final String name;
  final String username;
  final String role;
  final int officeId;
  final String officeName;
  final String officeCode;
  final String? email;
  final String? avatarUrl;

  bool get isStaff => role == 'staff';
  bool get isHead => role == 'head';
  bool get isAdmin => role == 'admin';
  bool get hasAvatar => avatarUrl != null && avatarUrl!.trim().isNotEmpty;

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: j['id'] as int,
        name: j['name'] as String,
        username: j['username'] as String,
        role: j['role'] as String,
        officeId: j['office_id'] as int,
        officeName: j['office_name'] as String,
        officeCode: j['office_code'] as String,
        email: j['email']?.toString(),
        avatarUrl: j['avatar_url']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'username': username,
        'role': role,
        'office_id': officeId,
        'office_name': officeName,
        'office_code': officeCode,
        if (email != null) 'email': email,
        if (avatarUrl != null) 'avatar_url': avatarUrl,
      };

  AppUser copyWith({
    String? name,
    String? username,
    String? email,
    String? avatarUrl,
    bool clearAvatar = false,
    bool clearEmail = false,
  }) {
    return AppUser(
      id: id,
      name: name ?? this.name,
      username: username ?? this.username,
      role: role,
      officeId: officeId,
      officeName: officeName,
      officeCode: officeCode,
      email: clearEmail ? null : (email ?? this.email),
      avatarUrl: clearAvatar ? null : (avatarUrl ?? this.avatarUrl),
    );
  }
}
