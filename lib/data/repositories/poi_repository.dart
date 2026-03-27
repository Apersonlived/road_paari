import 'package:dio/dio.dart';
import '../api/api_client.dart';
import '../api/api_exception.dart';
import '../models/poi_model.dart';

class POIRepository {
  final ApiClient _apiClient;

  POIRepository(this._apiClient);

  /// Get all POIs
  Future<List<POI>> getAllPOIs({
    int skip = 0,
    int limit = 100,
    int? categoryId,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'skip': skip,
        'limit': limit,
        if (categoryId != null) 'category_id': categoryId,
      };

      final response = await _apiClient.dio.get(
        '/poi/',
        queryParameters: queryParams,
      );

      return (response.data as List)
          .map((json) => POI.fromJson(json))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// Get POI by ID
  Future<POI> getPOIById(int poiId) async {
    try {
      final response = await _apiClient.dio.get('/poi/$poiId');
      return POI.fromJson(response.data);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// Create POI (admin only)
  Future<POI> createPOI({
    required String name,
    String? description,
    int? categoryId,
    required double latitude,
    required double longitude, String? imageUrl,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '/poi/',
        data: {
          'name': name,
          if (description != null) 'description': description,
          if (categoryId != null) 'category_id': categoryId,
          'latitude': latitude,
          'longitude': longitude,
          'image_url': imageUrl
        },
      );
      return POI.fromJson(response.data);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// Update POI (admin only) 
  Future<POI> updatePOI({
    required int poiId,
    String? name,
    String? description,
    int? categoryId,
    double? latitude,
    double? longitude, String? imageUrl,
  }) async {
    try {
      final data = <String, dynamic>{
        if (name != null) 'name': name,
        if (description != null) 'description': description,
        if (categoryId != null) 'category_id': categoryId,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (imageUrl != null) 'image_url' : imageUrl
      };

      final response = await _apiClient.dio.patch( // ← PATCH not PUT
        '/poi/$poiId',
        data: data,
      );
      return POI.fromJson(response.data);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// Delete POI (admin only)
  Future<void> deletePOI(int poiId) async {
    try {
      await _apiClient.dio.delete('/poi/$poiId');
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// Upload POI image
  Future<POI> uploadPOIImage(int poiId, String filePath) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath),
      });
      final response = await _apiClient.dio.patch(
        '/poi/$poiId/image',
        data: formData,
      );
      return POI.fromJson(response.data);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// Get nearby POIs
  Future<List<POI>> getNearbyPOIs({
    required double lat,
    required double lng,
    double radius = 1000,
    int? categoryId,
    int limit = 20,
  }) async {
    try {
      final response = await _apiClient.dio.get(
        '/poi/nearby',
        queryParameters: {
          'lat': lat,
          'lng': lng,
          'radius': radius,
          if (categoryId != null) 'category_id': categoryId,
          'limit': limit,
        },
      );
      return (response.data as List)
          .map((json) => POI.fromJson(json))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// Get POI categories
  Future<List<POICategory>> getCategories() async {
    try {
      final response = await _apiClient.dio.get('/poi/categories');
      return (response.data as List)
          .map((json) => POICategory.fromJson(json))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// Search POIs
  Future<List<POI>> searchPOIs(String query) async {
    try {
      final response = await _apiClient.dio.get(
        '/poi/search',
        queryParameters: {'name': query}, 
      );
      return (response.data as List)
          .map((json) => POI.fromJson(json))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}