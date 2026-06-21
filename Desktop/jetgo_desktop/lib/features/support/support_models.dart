class SupportMessageItem {
  SupportMessageItem({
    required this.id,
    required this.subject,
    required this.messagePreview,
    required this.isReplied,
    required this.createdAtUtc,
    required this.repliedAtUtc,
    required this.customerName,
    required this.customerEmail,
  });

  final int id;
  final String subject;
  final String messagePreview;
  final bool isReplied;
  final DateTime createdAtUtc;
  final DateTime? repliedAtUtc;
  final String customerName;
  final String customerEmail;

  factory SupportMessageItem.fromJson(Map<String, dynamic> json) {
    return SupportMessageItem(
      id: json['id'] as int? ?? 0,
      subject: json['subject'] as String? ?? '',
      messagePreview: json['messagePreview'] as String? ?? '',
      isReplied: json['isReplied'] as bool? ?? false,
      createdAtUtc: DateTime.parse(json['createdAtUtc'] as String),
      repliedAtUtc: json['repliedAtUtc'] == null
          ? null
          : DateTime.parse(json['repliedAtUtc'] as String),
      customerName: json['customerName'] as String? ?? '',
      customerEmail: json['customerEmail'] as String? ?? '',
    );
  }
}

class SupportMessageDetails {
  SupportMessageDetails({
    required this.id,
    required this.subject,
    required this.message,
    required this.adminReply,
    required this.isReplied,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    required this.repliedAtUtc,
    required this.customer,
  });

  final int id;
  final String subject;
  final String message;
  final String? adminReply;
  final bool isReplied;
  final DateTime createdAtUtc;
  final DateTime? updatedAtUtc;
  final DateTime? repliedAtUtc;
  final SupportMessageCustomer customer;

  factory SupportMessageDetails.fromJson(Map<String, dynamic> json) {
    return SupportMessageDetails(
      id: json['id'] as int? ?? 0,
      subject: json['subject'] as String? ?? '',
      message: json['message'] as String? ?? '',
      adminReply: json['adminReply'] as String?,
      isReplied: json['isReplied'] as bool? ?? false,
      createdAtUtc: DateTime.parse(json['createdAtUtc'] as String),
      updatedAtUtc: json['updatedAtUtc'] == null
          ? null
          : DateTime.parse(json['updatedAtUtc'] as String),
      repliedAtUtc: json['repliedAtUtc'] == null
          ? null
          : DateTime.parse(json['repliedAtUtc'] as String),
      customer: SupportMessageCustomer.fromJson(
        json['customer'] as Map<String, dynamic>? ?? const {},
      ),
    );
  }
}

class SupportMessageCustomer {
  SupportMessageCustomer({
    required this.userId,
    required this.username,
    required this.fullName,
    required this.email,
  });

  final String userId;
  final String username;
  final String fullName;
  final String email;

  factory SupportMessageCustomer.fromJson(Map<String, dynamic> json) {
    return SupportMessageCustomer(
      userId: json['userId'] as String? ?? '',
      username: json['username'] as String? ?? '',
      fullName: json['fullName'] as String? ?? '',
      email: json['email'] as String? ?? '',
    );
  }
}
