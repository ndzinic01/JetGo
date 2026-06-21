class AdminUserItem {
  AdminUserItem({
    required this.userId,
    required this.username,
    required this.firstName,
    required this.lastName,
    required this.fullName,
    required this.email,
    required this.phoneNumber,
    required this.isActive,
    required this.roles,
    required this.reservationsCount,
    required this.paymentsCount,
    required this.createdAtUtc,
  });

  final String userId;
  final String username;
  final String firstName;
  final String lastName;
  final String fullName;
  final String email;
  final String? phoneNumber;
  final bool isActive;
  final List<String> roles;
  final int reservationsCount;
  final int paymentsCount;
  final DateTime? createdAtUtc;

  factory AdminUserItem.fromJson(Map<String, dynamic> json) {
    return AdminUserItem(
      userId: json['userId'] as String? ?? '',
      username: json['username'] as String? ?? '',
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
      fullName: json['fullName'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phoneNumber: json['phoneNumber'] as String?,
      isActive: json['isActive'] as bool? ?? false,
      roles: ((json['roles'] as List<dynamic>?) ?? const [])
          .map((item) => item.toString())
          .toList(),
      reservationsCount: json['reservationsCount'] as int? ?? 0,
      paymentsCount: json['paymentsCount'] as int? ?? 0,
      createdAtUtc: json['createdAtUtc'] == null
          ? null
          : DateTime.parse(json['createdAtUtc'] as String),
    );
  }
}

class AdminUserDetails {
  AdminUserDetails({
    required this.userId,
    required this.username,
    required this.firstName,
    required this.lastName,
    required this.fullName,
    required this.email,
    required this.phoneNumber,
    required this.imageUrl,
    required this.isActive,
    required this.lockoutEndUtc,
    required this.roles,
    required this.reservationsCount,
    required this.paymentsCount,
    required this.supportMessagesCount,
    required this.searchHistoryCount,
    required this.unreadNotificationsCount,
    required this.createdAtUtc,
    required this.updatedAtUtc,
  });

  final String userId;
  final String username;
  final String firstName;
  final String lastName;
  final String fullName;
  final String email;
  final String? phoneNumber;
  final String? imageUrl;
  final bool isActive;
  final DateTime? lockoutEndUtc;
  final List<String> roles;
  final int reservationsCount;
  final int paymentsCount;
  final int supportMessagesCount;
  final int searchHistoryCount;
  final int unreadNotificationsCount;
  final DateTime? createdAtUtc;
  final DateTime? updatedAtUtc;

  factory AdminUserDetails.fromJson(Map<String, dynamic> json) {
    return AdminUserDetails(
      userId: json['userId'] as String? ?? '',
      username: json['username'] as String? ?? '',
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
      fullName: json['fullName'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phoneNumber: json['phoneNumber'] as String?,
      imageUrl: json['imageUrl'] as String?,
      isActive: json['isActive'] as bool? ?? false,
      lockoutEndUtc: json['lockoutEndUtc'] == null
          ? null
          : DateTime.parse(json['lockoutEndUtc'] as String),
      roles: ((json['roles'] as List<dynamic>?) ?? const [])
          .map((item) => item.toString())
          .toList(),
      reservationsCount: json['reservationsCount'] as int? ?? 0,
      paymentsCount: json['paymentsCount'] as int? ?? 0,
      supportMessagesCount: json['supportMessagesCount'] as int? ?? 0,
      searchHistoryCount: json['searchHistoryCount'] as int? ?? 0,
      unreadNotificationsCount: json['unreadNotificationsCount'] as int? ?? 0,
      createdAtUtc: json['createdAtUtc'] == null
          ? null
          : DateTime.parse(json['createdAtUtc'] as String),
      updatedAtUtc: json['updatedAtUtc'] == null
          ? null
          : DateTime.parse(json['updatedAtUtc'] as String),
    );
  }
}
