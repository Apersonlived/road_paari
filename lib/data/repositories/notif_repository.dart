import 'package:dio/dio.dart';
import '../api/api_client.dart';
import '../api/api_exception.dart';
import '../models/notif_model.dart';

class NotificationRepository {
  final ApiClient _apiClient;
  NotificationRepository(this._apiClient);

  /// POST /notifications/proximity-check
  Future<Map<String, dynamic>> proximityCheck({
    required double latitude,
    required double longitude,
    required double radiusMeters,
    required String fcmToken,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '/notifications/proximity-check',
        data: {
          'latitude': latitude,
          'longitude': longitude,
          'radius_meters': radiusMeters,
          'fcm_token': fcmToken,
        },
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// GET /notifications/
  Future<List<AppNotification>> getNotifications({
    int skip = 0,
    int limit = 50,
  }) async {
    try {
      final response = await _apiClient.dio.get(
        '/notifications/',
        queryParameters: {'skip': skip, 'limit': limit},
      );
      return (response.data as List)
          .map((j) => AppNotification.fromJson(j))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// PATCH /notifications/{id}/read
  Future<AppNotification> markAsRead(int notificationId) async {
    try {
      final response = await _apiClient.dio.patch(
        '/notifications/$notificationId/read',
      );
      return AppNotification.fromJson(response.data);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// PATCH /notifications/read-all
  Future<void> markAllRead() async {
    try {
      await _apiClient.dio.patch('/notifications/read-all');
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}
