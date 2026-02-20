import 'package:dio/dio.dart';
import '../api/api_client.dart';
import '../api/api_exception.dart';
import '../models/user_model.dart';

class UserRepository {
  final ApiClient _apiClient;

  UserRepository(this._apiClient);

  /// Get all users (admin only)
  Future<List<User>> getAllUsers({int skip = 0, int limit = 100}) async {
    try {
      final response = await _apiClient.dio.get(
        '/users/',
        queryParameters: {'skip': skip, 'limit': limit},
      );

      return (response.data as List)
          .map((json) => User.fromJson(json))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// Get user by ID
  Future<User> getUserById(int userId) async {
    try {
      final response = await _apiClient.dio.get('/users/$userId');
      return User.fromJson(response.data);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// Update user
  Future<User> updateUser({
    required int userId,
    String? email,
    String? fullName,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (email != null) data['email'] = email;
      if (fullName != null) data['full_name'] = fullName;

      final response = await _apiClient.dio.put(
        '/users/$userId',
        data: data,
      );

      return User.fromJson(response.data);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// Delete user (admin only)
  Future<void> deleteUser(int userId) async {
    try {
      await _apiClient.dio.delete('/users/$userId');
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// Change password
  Future<void> changePassword({
    required int userId,
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      await _apiClient.dio.put(
        '/users/$userId/password',
        data: {
          'old_password': oldPassword,
          'new_password': newPassword,
        },
      );
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}