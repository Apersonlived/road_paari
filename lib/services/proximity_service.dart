import 'dart:async';
import 'dart:math';
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

  /// POI IDs users already alerted about — cleared when user travels
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
    this.alertRadiusMeters = 500,
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
  final loc = _locationProvider.currentLocation;
  if (loc == null) return;

final token = _notifService.fcmToken;
if (token == null) {
  debugPrint('ProximityService: no FCM token yet, skipping');
  return;
}
  // Reset dedup set when user has moved far enough away.
  if (_lastAlertedLocation != null) {
    final d = _haversine(loc, _lastAlertedLocation!);
    debugPrint('ProximityService: distance moved = $d meters');
    if (d > _cooldownDistance) _alertedPoiIds.clear();
  }

  try {
    final result = await _notifRepo.proximityCheck(
      latitude: loc.latitude,
      longitude: loc.longitude,
      radiusMeters: alertRadiusMeters
    );

    if (result['triggered'] == true) {
      final pois = result['nearby_pois'] as List;
      for (final poi in pois) {
        final id = poi['id'] as int;
        if (_alertedPoiIds.contains(id)) continue; // already shown POIs
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
  final phi1 = a.latitude  * pi / 180;
  final phi2 = b.latitude  * pi / 180;
  final dPhi = (b.latitude  - a.latitude)  * pi / 180;
  final dLam = (b.longitude - a.longitude) * pi / 180;

  final x = sin(dPhi / 2) * sin(dPhi / 2) +
      cos(phi1) * cos(phi2) * sin(dLam / 2) * sin(dLam / 2);

  return R * 2 * atan2(sqrt(x), sqrt(1 - x));
}
}