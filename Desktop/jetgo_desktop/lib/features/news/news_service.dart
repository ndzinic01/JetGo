import '../../core/network/api_client.dart';
import '../reference_data/reference_data_models.dart';
import 'news_models.dart';

class NewsService {
  NewsService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<PagedResult<NewsArticleItem>> fetchArticles({
    required String token,
    String? searchText,
    bool? isPublished,
    int pageSize = 100,
  }) async {
    final response = await _apiClient.getJson(
      '/api/News/admin',
      token: token,
      queryParameters: <String, String>{
        'page': '1',
        'pageSize': pageSize.toString(),
        if (searchText != null && searchText.trim().isNotEmpty)
          'searchText': searchText.trim(),
        if (isPublished != null) 'isPublished': isPublished.toString(),
      },
    );

    return _mapPagedResult(response, NewsArticleItem.fromJson);
  }

  Future<NewsArticleDetails> getArticle({
    required String token,
    required int id,
  }) async {
    final response = await _apiClient.getJson(
      '/api/News/$id',
      token: token,
    );

    return NewsArticleDetails.fromJson(response);
  }

  Future<NewsArticleDetails> createArticle({
    required String token,
    required String title,
    required String content,
    required String imageUrl,
    required bool isPublished,
  }) async {
    final response = await _apiClient.postJson(
      '/api/News',
      token: token,
      body: <String, dynamic>{
        'title': title.trim(),
        'content': content.trim(),
        'imageUrl': imageUrl.trim(),
        'isPublished': isPublished,
      },
    );

    return NewsArticleDetails.fromJson(response);
  }

  Future<NewsArticleDetails> updateArticle({
    required String token,
    required int id,
    required String title,
    required String content,
    required String imageUrl,
    required bool isPublished,
  }) async {
    final response = await _apiClient.putJson(
      '/api/News/$id',
      token: token,
      body: <String, dynamic>{
        'title': title.trim(),
        'content': content.trim(),
        'imageUrl': imageUrl.trim(),
        'isPublished': isPublished,
      },
    );

    return NewsArticleDetails.fromJson(response);
  }

  PagedResult<T> _mapPagedResult<T>(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final rawItems = (json['items'] as List<dynamic>? ?? const []);

    return PagedResult<T>(
      items: rawItems
          .map((item) => fromJson(item as Map<String, dynamic>))
          .toList(),
      page: json['page'] as int? ?? 1,
      pageSize: json['pageSize'] as int? ?? rawItems.length,
      totalCount: json['totalCount'] as int? ?? rawItems.length,
      totalPages: json['totalPages'] as int? ?? 1,
      hasPreviousPage: json['hasPreviousPage'] as bool? ?? false,
      hasNextPage: json['hasNextPage'] as bool? ?? false,
    );
  }
}
