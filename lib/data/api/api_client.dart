import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  static const String baseUrl = 'http://localhost:8000/api';
  
  late final Dio _dio;
  String? _accessToken;
  String? _refreshToken;

  ApiClient() {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'Content-Type': 'application/json',
      },
    ));

    // Add interceptors
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: _onRequest,
        onError: _onError,
        onResponse: _onResponse,
      ),
    );

    // Load saved tokens
    _loadTokens();
  }

  // Load tokens from SharedPreferences
  Future<void> _loadTokens() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString('access_token');
    _refreshToken = prefs.getString('refresh_token');
  }

  // Save tokens to SharedPreferences
  Future<void> _saveTokens(String accessToken, String refreshToken) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', accessToken);
    await prefs.setString('refresh_token', refreshToken);
  }

  // Clear tokens
  Future<void> clearTokens() async {
    _accessToken = null;
    _refreshToken = null;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
  }

  // Request interceptor - Add auth token
  void _onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (_accessToken != null) {
      options.headers['Authorization'] = 'Bearer $_accessToken';
    }
    
    print('request: ${options.method} ${options.path}');
    print('Headers: ${options.headers}');
    
    handler.next(options);
  }

  // Response interceptor
  void _onResponse(Response response, ResponseInterceptorHandler handler) {
    print('response: ${response.statusCode} ${response.requestOptions.path}');
    handler.next(response);
  }

  // Error interceptor - Handle 401 and refresh token
  Future<void> _onError(
    DioException error,
    ErrorInterceptorHandler handler,
  ) async {
    print('Error: ${error.response?.statusCode} ${error.message}');

    // Handle 401 Unauthorized - Try to refresh token
    if (error.response?.statusCode == 401 && _refreshToken != null) {
      try {
        // Try to refresh the token
        final response = await _dio.post(
          '/auth/refresh',
          data: {'refresh_token': _refreshToken},
        );

        if (response.statusCode == 200) {
          final newAccessToken = response.data['access_token'];
          final newRefreshToken = response.data['refresh_token'];
          
          await _saveTokens(newAccessToken, newRefreshToken);

          // Retry the failed request
          final opts = error.requestOptions;
          opts.headers['Authorization'] = 'Bearer $newAccessToken';
          
          final retryResponse = await _dio.fetch(opts);
          return handler.resolve(retryResponse);
        }
      } catch (e) {
        // Refresh failed, clear tokens
        await clearTokens();
      }
    }

    handler.next(error);
  }

  // Getters
  Dio get dio => _dio;
  bool get isAuthenticated => _accessToken != null;
  String? get accessToken => _accessToken;

  // Update base URL (for production)
  void setBaseUrl(String url) {
    _dio.options.baseUrl = url;
  }

  // Manual token setter (after login)
  Future<void> setTokens(String accessToken, String refreshToken) async {
    await _saveTokens(accessToken, refreshToken);
  }
}