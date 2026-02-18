import 'package:dio/dio.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic data;

  ApiException({
    required this.message,
    this.statusCode,
    this.data,
  });

  @override
  String toString() => message;

  factory ApiException.fromDioError(DioException error) {
    String message;
    int? statusCode = error.response?.statusCode;

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        message = 'Connection timeout. Please check your internet connection.';
        break;
      case DioExceptionType.badResponse:
        message = _handleBadResponse(error.response);
        break;
      case DioExceptionType.cancel:
        message = 'Request cancelled';
        break;
      default:
        message = 'Network error. Please try again.';
    }

    return ApiException(
      message: message,
      statusCode: statusCode,
      data: error.response?.data,
    );
  }

  static String _handleBadResponse(Response? response) {
    if (response?.data is Map) {
      // FastAPI error format
      final data = response!.data as Map;
      if (data.containsKey('detail')) {
        if (data['detail'] is String) {
          return data['detail'];
        } else if (data['detail'] is List) {
          // Validation errors
          final errors = (data['detail'] as List)
              .map((e) => e['msg'] ?? e.toString())
              .join(', ');
          return errors;
        }
      }
    }
    
    return 'Request failed with status: ${response?.statusCode}';
  }
}