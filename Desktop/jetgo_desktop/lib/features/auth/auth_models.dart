class AuthSession {
  AuthSession({
    required this.accessToken,
    required this.expiresAtUtc,
    required this.user,
  });

  final String accessToken;
  final DateTime expiresAtUtc;
  final AuthUser user;

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      accessToken: json['accessToken'] as String? ?? '',
      expiresAtUtc: DateTime.parse(json['expiresAtUtc'] as String),
      user: AuthUser.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}

class AuthUser {
  AuthUser({
    required this.userId,
    required this.username,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.roles,
    this.phoneNumber,
  });

  final String userId;
  final String username;
  final String email;
  final String firstName;
  final String lastName;
  final String? phoneNumber;
  final List<String> roles;

  String get fullName {
    final value = '$firstName $lastName'.trim();
    return value.isEmpty ? username : value;
  }

  bool get isAdmin => roles.any((role) => role.toLowerCase() == 'admin');

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      userId: json['userId'] as String? ?? '',
      username: json['username'] as String? ?? '',
      email: json['email'] as String? ?? '',
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
      phoneNumber: json['phoneNumber'] as String?,
      roles: ((json['roles'] as List<dynamic>?) ?? const [])
          .map((role) => role.toString())
          .toList(),
    );
  }
}
