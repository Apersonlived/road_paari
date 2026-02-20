import 'package:dio/dio.dart';
import '../api/api_client.dart';
import '../api/api_exception.dart';
import '../models/user_model.dart';
import '../models/token_model.dart';

class AuthRepository {
  final ApiClient _apiClient;

  AuthRepository(this._apiClient);

  /// Register new user
  Future<User> register({
    required String email,
    required String password,
    String? fullName,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '/auth/register',
        data: {
          'email': email,
          'password': password,
          'full_name': fullName,
        },
      );

      return User.fromJson(response.data);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// Login user
  Future<Token> login({
    required String email,
    required String password,
  }) async {
    try {
      // FastAPI OAuth2PasswordRequestForm uses form data, not JSON
      final response = await _apiClient.dio.post(
        '/auth/login',
        data: FormData.fromMap({
          'username': email,  // OAuth2 uses 'username' field
          'password': password,
        }),
      );

      final token = Token.fromJson(response.data);
      
      // Save tokens to API client
      await _apiClient.setTokens(
        token.accessToken,
        token.refreshToken,
      );

      return token;
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// Get current user
  Future<User> getCurrentUser() async {
    try {
      final response = await _apiClient.dio.get('/auth/me');
      return User.fromJson(response.data);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// Logout
  Future<void> logout() async {
    await _apiClient.clearTokens();
  }

  /// Check if user is authenticated
  bool isAuthenticated() {
    return _apiClient.isAuthenticated;
  }
}