import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../data/repositories/routing_repository.dart';
import '../../data/models/routing_models.dart';

class MapProvider extends ChangeNotifier {
  late Dio _dio;
  late RoutingRepository _routingRepository;

  CompleteJourney? _currentJourney;
  RouteDetails? _selectedRouteDetails;
  bool _isLoading = false;
  String? _error;
  List<NearestStop> _nearbyStops = [];

  MapProvider() {
    _initializeDio();
  }

  void _initializeDio() {
    _dio = Dio(BaseOptions(
      baseUrl: 'http://http://10.0.2.2:8000/api',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Content-Type': 'application/json'},
    ));
    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      error: true,
    ));
    _routingRepository = RoutingRepository(_dio);
  }

  // Getters
  CompleteJourney? get currentJourney => _currentJourney;
  RouteDetails? get selectedRouteDetails => _selectedRouteDetails;
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<NearestStop> get nearbyStops => _nearbyStops;
  RoutingRepository get routingRepository => _routingRepository;

  void setBaseUrl(String url) => _dio.options.baseUrl = url;

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void setError(String? error) {
    _error = error;
    notifyListeners();
  }

  void clearRoute() {
    _currentJourney = null;
    _selectedRouteDetails = null;
    _error = null;
    notifyListeners();
  }

  /// POST /plan-journey 
  Future<CompleteJourney?> planJourney({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
    int maxWalkDistance = 500,
  }) async {
    try {
      setLoading(true);
      setError(null);
      final journey = await _routingRepository.planJourney(
        startLat: startLat,
        startLng: startLng,
        endLat: endLat,
        endLng: endLng,
        maxWalkDistance: maxWalkDistance,
      );
      if (journey != null) {
        _currentJourney = journey;
        notifyListeners();
      } else {
        setError('No trip found');
      }
      setLoading(false);
      return journey;
    } catch (e) {
      setError('Error planning the trip: $e');
      setLoading(false);
      return null;
    }
  }

  /// Fetch full geometry for a specific bus route in the journey
  Future<RouteDetails?> loadRouteDetails({
    required int routeId,
    int? startStopId,
    int? endStopId,
  }) async {
    try {
      setLoading(true);
      setError(null);
      final details = await _routingRepository.getRouteDetails(
        routeId: routeId,
        startStopId: startStopId,
        endStopId: endStopId,
      );
      _selectedRouteDetails = details;
      setLoading(false);
      notifyListeners();
      return details;
    } catch (e) {
      setError('Error loading route details: $e');
      setLoading(false);
      return null;
    }
  }

  Future<List<NearestStop>> findNearestStops({
    required double lat,
    required double lng,
    int maxDistance = 500,
    int limit = 5,
  }) async {
    try {
      setLoading(true);
      setError(null);
      final stops = await _routingRepository.getNearestStops(
        lat: lat,
        lng: lng,
        maxDistance: maxDistance,
        limit: limit,
      );
      _nearbyStops = stops;
      setLoading(false);
      notifyListeners();
      return stops;
    } catch (e) {
      setError('Error finding stops: $e');
      setLoading(false);
      return [];
    }
  }
}