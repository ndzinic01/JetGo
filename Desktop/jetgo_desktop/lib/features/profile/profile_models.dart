class AdminProfile {
  AdminProfile({
    required this.userId,
    required this.username,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.roles,
    this.phoneNumber,
    this.imageUrl,
  });

  final String userId;
  final String username;
  final String firstName;
  final String lastName;
  final String email;
  final String? phoneNumber;
  final String? imageUrl;
  final List<String> roles;

  String get fullName {
    final value = '$firstName $lastName'.trim();
    return value.isEmpty ? username : value;
  }

  factory AdminProfile.fromJson(Map<String, dynamic> json) {
    return AdminProfile(
      userId: json['userId'] as String? ?? '',
      username: json['username'] as String? ?? '',
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phoneNumber: json['phoneNumber'] as String?,
      imageUrl: json['imageUrl'] as String?,
      roles: ((json['roles'] as List<dynamic>?) ?? const [])
          .map((item) => item.toString())
          .toList(),
    );
  }
}
