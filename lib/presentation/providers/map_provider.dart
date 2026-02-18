import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
import '../../data/repositories/routing_repository.dart';
import '../../data/models/routing_models.dart';

class MapProvider extends ChangeNotifier {
  // Dio instance for API calls
  late Dio _dio;
  late RoutingRepository _routingRepository;
  
  // State
  RoadInfo? _currentRoute;
  RouteData? _backendRouteData;
  bool _isLoading = false;
  String? _error;
  
  // Nearest stops
  NearestStop? _nearestStartStop;
  NearestStop? _nearestEndStop;
  List<NearestStop> _nearbyStops = [];

  MapProvider() {
    _initializeDio();
  }

  void _initializeDio() {
    _dio = Dio(BaseOptions(
      baseUrl: 'http://localhost:8000/api', // Change for production
      connectTimeout: Duration(seconds: 10),
      receiveTimeout: Duration(seconds: 10),
      headers: {
        'Content-Type': 'application/json',
      },
    ));

    // Add interceptors for logging
    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      error: true,
    ));

    _routingRepository = RoutingRepository(_dio);
  }

  // Getters
  RoadInfo? get currentRoute => _currentRoute;
  RouteData? get backendRouteData => _backendRouteData;
  bool get isLoading => _isLoading;
  String? get error => _error;
  NearestStop? get nearestStartStop => _nearestStartStop;
  NearestStop? get nearestEndStop => _nearestEndStop;
  List<NearestStop> get nearbyStops => _nearbyStops;
  RoutingRepository get routingRepository => _routingRepository;

  // Set base URL for production
  void setBaseUrl(String url) {
    _dio.options.baseUrl = url;
  }

  // Set loading state
  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  // Set error
  void setError(String? error) {
    _error = error;
    notifyListeners();
  }

  // Set current route (OSM Plugin route)
  void setCurrentRoute(RoadInfo? route) {
    _currentRoute = route;
    notifyListeners();
  }

  // Set backend route data
  void setBackendRouteData(RouteData? routeData) {
    _backendRouteData = routeData;
    notifyListeners();
  }

  // Set nearest stops
  void setNearestStops(NearestStop? start, NearestStop? end) {
    _nearestStartStop = start;
    _nearestEndStop = end;
    notifyListeners();
  }

  // Set nearby stops
  void setNearbyStops(List<NearestStop> stops) {
    _nearbyStops = stops;
    notifyListeners();
  }

  // Clear route
  void clearRoute() {
    _currentRoute = null;
    _backendRouteData = null;
    _nearestStartStop = null;
    _nearestEndStop = null;
    _error = null;
    notifyListeners();
  }

  // Find nearest stop
  Future<NearestStop?> findNearestStop({
    required double lat,
    required double lng,
    int maxDistance = 1000,
  }) async {
    try {
      setLoading(true);
      setError(null);

      final stop = await _routingRepository.getNearestStop(
        lat: lat,
        lng: lng,
        maxDistance: maxDistance,
      );

      setLoading(false);
      return stop;
    } catch (e) {
      setError('Error finding nearest stop: $e');
      setLoading(false);
      return null;
    }
  }

  // Find K nearest stops
  Future<List<NearestStop>> findNearestStops({
    required double lat,
    required double lng,
    int k = 5,
    int maxDistance = 2000,
  }) async {
    try {
      setLoading(true);
      setError(null);

      final stops = await _routingRepository.getNearestStops(
        lat: lat,
        lng: lng,
        k: k,
        maxDistance: maxDistance,
      );

      setNearbyStops(stops);
      setLoading(false);
      return stops;
    } catch (e) {
      setError('Error finding nearest stops: $e');
      setLoading(false);
      return [];
    }
  }

  // Calculate route
  Future<RouteData?> calculateRoute({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) async {
    try {
      setLoading(true);
      setError(null);

      final routeData = await _routingRepository.calculateRoute(
        startLat: startLat,
        startLng: startLng,
        endLat: endLat,
        endLng: endLng,
      );

      if (routeData != null) {
        setBackendRouteData(routeData);
      } else {
        setError('No route found');
      }

      setLoading(false);
      return routeData;
    } catch (e) {
      setError('Error calculating route: $e');
      setLoading(false);
      return null;
    }
  }

  // Get route between stops
  Future<RouteData?> getRouteBetweenStops({
    required int startStopId,
    required int endStopId,
  }) async {
    try {
      setLoading(true);
      setError(null);

      final routeData = await _routingRepository.getRouteBetweenStops(
        startStopId: startStopId,
        endStopId: endStopId,
      );

      if (routeData != null) {
        setBackendRouteData(routeData);
      } else {
        setError('No route found between stops');
      }

      setLoading(false);
      return routeData;
    } catch (e) {
      setError('Error getting route between stops: $e');
      setLoading(false);
      return null;
    }
  }

  // Get transfer route
  Future<RouteData?> getTransferRoute({
    required List<int> stopIds,
  }) async {
    try {
      setLoading(true);
      setError(null);

      final routeData = await _routingRepository.getTransferRoute(
        stopIds: stopIds,
      );

      if (routeData != null) {
        setBackendRouteData(routeData);
      } else {
        setError('No transfer route found');
      }

      setLoading(false);
      return routeData;
    } catch (e) {
      setError('Error getting transfer route: $e');
      setLoading(false);
      return null;
    }
  }
}