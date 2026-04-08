import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
import '../data/repositories/notif_repository.dart';
import 'notification_service.dart';
import '../providers/location_provider.dart';

class ProximityService {
  final LocationProvider _locationProvider;
  final NotificationRepository _notifRepo;
  final NotificationService _notifService;

  /// How often we ping the backend (in seconds).
  final Duration _interval;

  /// Alert radius sent to the backend (in metres).
  final double alertRadiusMeters;

  /// POI IDs we already alerted about — cleared when user travels
  final Set<int> _alertedPoiIds = {};

  /// Re-alert after this distance moved (in metres).
  static const double _cooldownDistance = 500;

  GeoPoint? _lastAlertedLocation;
  Timer? _timer;

  ProximityService({
    required LocationProvider locationProvider,
    required NotificationRepository notificationRepository,
    NotificationService? notificationService,
    Duration interval = const Duration(seconds: 30),
    this.alertRadiusMeters = 200,
  })  : _locationProvider = locationProvider,
        _notifRepo = notificationRepository,
        _notifService = notificationService ?? NotificationService.instance,
        _interval = interval;

  /// Start periodic proximity polling.
  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(_interval, (_) => _check());
  }

  void stop() => _timer?.cancel();

  Future<void> _check() async {
  debugPrint('ProximityService: _check() called');
  final loc = _locationProvider.currentLocation;
  debugPrint('ProximityService: location = $loc'); 
  if (loc == null) return;

  final token = _notifService.fcmToken ?? 'no-token';

  // Reset dedup set when user has moved far enough away.
  if (_lastAlertedLocation != null) {
    final d = _haversine(loc, _lastAlertedLocation!);
    debugPrint('ProximityService: distance moved = $d meters');
    if (d > _cooldownDistance) _alertedPoiIds.clear();
  }

  try {
    debugPrint('ProximityService: calling proximityCheck API');
    final result = await _notifRepo.proximityCheck(
      latitude: loc.latitude,
      longitude: loc.longitude,
      radiusMeters: alertRadiusMeters,
      fcmToken: token,
    );

    debugPrint('ProximityService: API response = $result');

    if (result['triggered'] == true) {
      final pois = result['nearby_pois'] as List;
      for (final poi in pois) {
        final id = poi['id'] as int;
        if (_alertedPoiIds.contains(id)) continue; // already shown
        _alertedPoiIds.add(id);
        _lastAlertedLocation = loc;

        // Show local notification immediately (covers foreground state)
        await _notifService.showLocal(
          id: id,
          title: "You're near ${poi['name']}!",
          body:
              "${poi['name']} is ${(poi['distance_meters'] as num).toStringAsFixed(0)} m away.",
        );
      }
    }
  } catch (e) {
    debugPrint('ProximityService error: $e');
  }
}

  /// Haversine distance in metres between two GeoPoints.
  double _haversine(GeoPoint a, GeoPoint b) {
    const R = 6371000.0;
    final dLat = _rad(b.latitude - a.latitude);
    final dLon = _rad(b.longitude - a.longitude);
    final sinLat = 0.5 - (_cos(_rad(a.latitude)) *
        _cos(_rad(b.latitude)) *
        (1 - _cos(dLon)) / 2);
    return R * 2 * _asin(sinLat + (1 - _cos(dLat)) / 2);
  }

  static double _rad(double d) => d * 3.141592653589793 / 180;
  static double _cos(double r) => double.parse(
      (r == 0 ? 1.0 : 1 - r * r / 2 + r * r * r * r / 24).toStringAsFixed(10));
  static double _asin(double x) => x; // small angle — accurate enough for dedup
}