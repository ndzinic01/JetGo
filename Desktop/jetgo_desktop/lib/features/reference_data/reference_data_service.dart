import '../../core/network/api_client.dart';
import 'reference_data_models.dart';

class ReferenceDataService {
  ReferenceDataService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<PagedResult<CountryItem>> fetchCountries({
    required String token,
    String? searchText,
    int pageSize = 100,
  }) async {
    final response = await _apiClient.getJson(
      '/api/admin/countries',
      token: token,
      queryParameters: <String, String>{
        'page': '1',
        'pageSize': pageSize.toString(),
        if (searchText != null && searchText.trim().isNotEmpty)
          'searchText': searchText.trim(),
      },
    );

    return _mapPagedResult(response, CountryItem.fromJson);
  }

  Future<CountryDetails> getCountry({
    required String token,
    required int id,
  }) async {
    final response = await _apiClient.getJson(
      '/api/admin/countries/$id',
      token: token,
    );

    return CountryDetails.fromJson(response);
  }

  Future<CountryDetails> createCountry({
    required String token,
    required String name,
    required String isoCode,
  }) async {
    final response = await _apiClient.postJson(
      '/api/admin/countries',
      token: token,
      body: <String, dynamic>{
        'name': name.trim(),
        'isoCode': isoCode.trim().toUpperCase(),
      },
    );

    return CountryDetails.fromJson(response);
  }

  Future<CountryDetails> updateCountry({
    required String token,
    required int id,
    required String name,
    required String isoCode,
  }) async {
    final response = await _apiClient.putJson(
      '/api/admin/countries/$id',
      token: token,
      body: <String, dynamic>{
        'name': name.trim(),
        'isoCode': isoCode.trim().toUpperCase(),
      },
    );

    return CountryDetails.fromJson(response);
  }

  Future<void> deleteCountry({
    required String token,
    required int id,
  }) async {
    await _apiClient.delete(
      '/api/admin/countries/$id',
      token: token,
    );
  }

  Future<PagedResult<CityItem>> fetchCities({
    required String token,
    String? searchText,
    int? countryId,
    int pageSize = 100,
  }) async {
    final response = await _apiClient.getJson(
      '/api/admin/cities',
      token: token,
      queryParameters: <String, String>{
        'page': '1',
        'pageSize': pageSize.toString(),
        if (countryId != null) 'countryId': countryId.toString(),
        if (searchText != null && searchText.trim().isNotEmpty)
          'searchText': searchText.trim(),
      },
    );

    return _mapPagedResult(response, CityItem.fromJson);
  }

  Future<CityDetails> getCity({
    required String token,
    required int id,
  }) async {
    final response = await _apiClient.getJson(
      '/api/admin/cities/$id',
      token: token,
    );

    return CityDetails.fromJson(response);
  }

  Future<CityDetails> createCity({
    required String token,
    required int countryId,
    required String name,
  }) async {
    final response = await _apiClient.postJson(
      '/api/admin/cities',
      token: token,
      body: <String, dynamic>{
        'countryId': countryId,
        'name': name.trim(),
      },
    );

    return CityDetails.fromJson(response);
  }

  Future<CityDetails> updateCity({
    required String token,
    required int id,
    required int countryId,
    required String name,
  }) async {
    final response = await _apiClient.putJson(
      '/api/admin/cities/$id',
      token: token,
      body: <String, dynamic>{
        'countryId': countryId,
        'name': name.trim(),
      },
    );

    return CityDetails.fromJson(response);
  }

  Future<void> deleteCity({
    required String token,
    required int id,
  }) async {
    await _apiClient.delete(
      '/api/admin/cities/$id',
      token: token,
    );
  }

  Future<PagedResult<AirportItem>> fetchAirports({
    required String token,
    String? searchText,
    int? countryId,
    int? cityId,
    int pageSize = 100,
  }) async {
    final response = await _apiClient.getJson(
      '/api/admin/airports',
      token: token,
      queryParameters: <String, String>{
        'page': '1',
        'pageSize': pageSize.toString(),
        if (countryId != null) 'countryId': countryId.toString(),
        if (cityId != null) 'cityId': cityId.toString(),
        if (searchText != null && searchText.trim().isNotEmpty)
          'searchText': searchText.trim(),
      },
    );

    return _mapPagedResult(response, AirportItem.fromJson);
  }

  Future<AirportDetails> getAirport({
    required String token,
    required int id,
  }) async {
    final response = await _apiClient.getJson(
      '/api/admin/airports/$id',
      token: token,
    );

    return AirportDetails.fromJson(response);
  }

  Future<AirportDetails> createAirport({
    required String token,
    required int cityId,
    required String name,
    required String iataCode,
    double? latitude,
    double? longitude,
  }) async {
    final response = await _apiClient.postJson(
      '/api/admin/airports',
      token: token,
      body: <String, dynamic>{
        'cityId': cityId,
        'name': name.trim(),
        'iataCode': iataCode.trim().toUpperCase(),
        'latitude': latitude,
        'longitude': longitude,
      },
    );

    return AirportDetails.fromJson(response);
  }

  Future<AirportDetails> updateAirport({
    required String token,
    required int id,
    required int cityId,
    required String name,
    required String iataCode,
    double? latitude,
    double? longitude,
  }) async {
    final response = await _apiClient.putJson(
      '/api/admin/airports/$id',
      token: token,
      body: <String, dynamic>{
        'cityId': cityId,
        'name': name.trim(),
        'iataCode': iataCode.trim().toUpperCase(),
        'latitude': latitude,
        'longitude': longitude,
      },
    );

    return AirportDetails.fromJson(response);
  }

  Future<void> deleteAirport({
    required String token,
    required int id,
  }) async {
    await _apiClient.delete(
      '/api/admin/airports/$id',
      token: token,
    );
  }

  Future<PagedResult<AirlineItem>> fetchAirlines({
    required String token,
    String? searchText,
    bool? isActive,
    int pageSize = 100,
  }) async {
    final response = await _apiClient.getJson(
      '/api/admin/airlines',
      token: token,
      queryParameters: <String, String>{
        'page': '1',
        'pageSize': pageSize.toString(),
        if (isActive != null) 'isActive': isActive.toString(),
        if (searchText != null && searchText.trim().isNotEmpty)
          'searchText': searchText.trim(),
      },
    );

    return _mapPagedResult(response, AirlineItem.fromJson);
  }

  Future<AirlineDetails> getAirline({
    required String token,
    required int id,
  }) async {
    final response = await _apiClient.getJson(
      '/api/admin/airlines/$id',
      token: token,
    );

    return AirlineDetails.fromJson(response);
  }

  Future<AirlineDetails> createAirline({
    required String token,
    required String name,
    required String code,
    String? logoUrl,
    required bool isActive,
  }) async {
    final response = await _apiClient.postJson(
      '/api/admin/airlines',
      token: token,
      body: <String, dynamic>{
        'name': name.trim(),
        'code': code.trim().toUpperCase(),
        'logoUrl': logoUrl?.trim(),
        'isActive': isActive,
      },
    );

    return AirlineDetails.fromJson(response);
  }

  Future<AirlineDetails> updateAirline({
    required String token,
    required int id,
    required String name,
    required String code,
    String? logoUrl,
    required bool isActive,
  }) async {
    final response = await _apiClient.putJson(
      '/api/admin/airlines/$id',
      token: token,
      body: <String, dynamic>{
        'name': name.trim(),
        'code': code.trim().toUpperCase(),
        'logoUrl': logoUrl?.trim(),
        'isActive': isActive,
      },
    );

    return AirlineDetails.fromJson(response);
  }

  Future<void> deleteAirline({
    required String token,
    required int id,
  }) async {
    await _apiClient.delete(
      '/api/admin/airlines/$id',
      token: token,
    );
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
