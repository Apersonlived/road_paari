import 'package:dio/dio.dart';
import '../models/routing_models.dart';

class RoutingRepository {
  final Dio _dio;

  RoutingRepository(this._dio);

  /// GET /nearest-stops
  Future<List<NearestStop>> getNearestStops({
    required double lat,
    required double lng,
    int maxDistance = 500,
    int limit = 5,
  }) async {
    try {
      final response = await _dio.get(
        '/routing/nearest-stops',
        queryParameters: {
          'lat': lat,
          'lng': lng,
          'max_distance': maxDistance,
          'limit': limit,
        },
      );
      if (response.statusCode == 200 && response.data != null) {
        return (response.data as List)
            .map((j) => NearestStop.fromJson(j as Map<String, dynamic>))
            .toList();
      }
      return [];
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return [];
      rethrow;
    }
  }

  /// GET /routes-between-stops?start_stop_id=&end_stop_id=
  Future<List<BusRoute>> getRoutesBetweenStops({
    required int startStopId,
    required int endStopId,
  }) async {
    try {
      final response = await _dio.get(
        '/routing/routes-between-stops',
        queryParameters: {
          'start_stop_id': startStopId,
          'end_stop_id': endStopId,
        },
      );
      if (response.statusCode == 200 && response.data != null) {
        return (response.data as List)
            .map((j) => BusRoute.fromJson(j as Map<String, dynamic>))
            .toList();
      }
      return [];
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return [];
      rethrow;
    }
  }

  /// GET /route-details/{route_id}?start_stop_id=&end_stop_id=
  Future<RouteDetails?> getRouteDetails({
    required int routeId,
    int? startStopId,
    int? endStopId,
  }) async {
    try {
      final response = await _dio.get(
        '/routing/route-details/$routeId',
        queryParameters: {
          if (startStopId != null) 'start_stop_id': startStopId,
          if (endStopId != null) 'end_stop_id': endStopId,
        },
      );
      if (response.statusCode == 200 && response.data != null) {
        return RouteDetails.fromJson(response.data as Map<String, dynamic>);
      }
      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  /// POST /plan-journey — main journey planning endpoint
  Future<CompleteJourney?> planJourney({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
    int maxWalkDistance = 1200,
  }) async {
    try {
      final response = await _dio.post(
        '/routing/plan-journey',
        data: {
          'start': {'lat': startLat, 'lng': startLng},
          'end': {'lat': endLat, 'lng': endLng},
        },
        queryParameters: {'max_walk_distance': maxWalkDistance},
      );
      if (response.statusCode == 200 && response.data != null) {
        return CompleteJourney.fromJson(response.data as Map<String, dynamic>);
      }
      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  /// GET /routes-at-stop/{stop_id}
  Future<List<Map<String, dynamic>>> getRoutesAtStop(int stopId) async {
    try {
      final response = await _dio.get('/routing/routes-at-stop/$stopId');
      if (response.statusCode == 200 && response.data != null) {
        return List<Map<String, dynamic>>.from(response.data as List);
      }
      return [];
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return [];
      rethrow;
    }
  }
}