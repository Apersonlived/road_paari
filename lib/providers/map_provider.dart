import 'package:flutter/material.dart';
import '../data/api/api_client.dart';
import '../data/repositories/routing_repository.dart';
import '../data/models/routing_models.dart';

class MapProvider extends ChangeNotifier {
  final RoutingRepository _routingRepository;

  CompleteJourney? _currentJourney;
  RouteDetails? _selectedRouteDetails;
  bool _isLoading = false;
  String? _error;
  List<NearestStop> _nearbyStops = [];

  MapProvider({required ApiClient apiClient})
      : _routingRepository = RoutingRepository(apiClient.dio);

  // ── Getters ────────────────────────────────────────────────────────────────
  CompleteJourney? get currentJourney => _currentJourney;
  RouteDetails? get selectedRouteDetails => _selectedRouteDetails;
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<NearestStop> get nearbyStops => _nearbyStops;

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

  // ── Plan Journey ───────────────────────────────────────────────────────────
  Future<CompleteJourney?> planJourney({
  required double startLat,
  required double startLng,
  required double endLat,
  required double endLng,
  int maxWalkDistance = 500,
}) async {
  if (startLat < -90 || startLat > 90 ||
        endLat < -90 || endLat > 90 ||
        startLng < -180 || startLng > 180 ||
        endLng < -180 || endLng > 180) {
      setError('Invalid coordinates');
      return null;
    }
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
    _currentJourney = journey;
    if (journey == null) setError('No routes found');
    setLoading(false);
    notifyListeners();
    return journey;
  } catch (e) {
    setError('Error planning trip: $e');
    _currentJourney = null;
    setLoading(false);
    notifyListeners();
    return null;
  }
}

  // ── Route Details ──────────────────────────────────────────────────────────
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

  // ── Nearest Stops ──────────────────────────────────────────────────────────
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