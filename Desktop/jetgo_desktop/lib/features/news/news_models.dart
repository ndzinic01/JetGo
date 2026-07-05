class NewsArticleItem {
  NewsArticleItem({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.isPublished,
    required this.publishedAtUtc,
  });

  final int id;
  final String title;
  final String imageUrl;
  final bool isPublished;
  final DateTime publishedAtUtc;

  factory NewsArticleItem.fromJson(Map<String, dynamic> json) {
    return NewsArticleItem(
      id: json['id'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      imageUrl: json['imageUrl'] as String? ?? '',
      isPublished: json['isPublished'] as bool? ?? false,
      publishedAtUtc: DateTime.parse(json['publishedAtUtc'] as String),
    );
  }
}

class NewsArticleDetails {
  NewsArticleDetails({
    required this.id,
    required this.title,
    required this.content,
    required this.imageUrl,
    required this.isPublished,
    required this.publishedAtUtc,
    required this.createdAtUtc,
  });

  final int id;
  final String title;
  final String content;
  final String imageUrl;
  final bool isPublished;
  final DateTime publishedAtUtc;
  final DateTime createdAtUtc;

  factory NewsArticleDetails.fromJson(Map<String, dynamic> json) {
    return NewsArticleDetails(
      id: json['id'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      imageUrl: json['imageUrl'] as String? ?? '',
      isPublished: json['isPublished'] as bool? ?? false,
      publishedAtUtc: DateTime.parse(json['publishedAtUtc'] as String),
      createdAtUtc: DateTime.parse(json['createdAtUtc'] as String),
    );
  }
}
