class LocationPoint {
  final double lat;
  final double lng;

  LocationPoint({required this.lat, required this.lng});

  factory LocationPoint.fromJson(Map<String, dynamic> json) =>
      LocationPoint(lat: (json['lat'] as num).toDouble(),
                    lng: (json['lng'] as num).toDouble());

  Map<String, dynamic> toJson() => {'lat': lat, 'lng': lng};
}


class NearestStop {
  final int stopId;
  final String? stopName;
  final double distanceMeters;
  final double latitude;
  final double longitude;

  NearestStop({
    required this.stopId,
    this.stopName,
    required this.distanceMeters,
    required this.latitude,
    required this.longitude,
  });

  factory NearestStop.fromJson(Map<String, dynamic> json) => NearestStop(
        stopId: json['stop_id'] as int,
        stopName: json['stop_name'] as String?,
        distanceMeters: (json['distance_meters'] as num).toDouble(),
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
      );

  // ── Helper getters used in MapScreen ──────────────────────────────────────
  String get displayName => stopName ?? 'Stop #$stopId';

  String get formattedDistance => distanceMeters < 1000
      ? '${distanceMeters.toStringAsFixed(0)}m'
      : '${(distanceMeters / 1000).toStringAsFixed(1)}km';
}


class BusRoute {
  final int routeId;
  final String routeName;
  final String routeType;
  final bool isDirect;
  final int? startSequence;
  final int? endSequence;
  final double? distanceMeters;

  BusRoute({
    required this.routeId,
    required this.routeName,
    required this.routeType,
    required this.isDirect,
    this.startSequence,
    this.endSequence,
    this.distanceMeters,
  });

  factory BusRoute.fromJson(Map<String, dynamic> json) => BusRoute(
        routeId: json['route_id'] as int,
        routeName: json['route_name'] as String,
        routeType: json['route_type'] as String,
        isDirect: json['is_direct'] as bool,
        startSequence: json['start_sequence'] as int?,
        endSequence: json['end_sequence'] as int?,
        distanceMeters: (json['distance_meters'] as num?)?.toDouble(),
      );

  String get formattedDistance {
    if (distanceMeters == null) return '';
    return distanceMeters! < 1000
        ? '${distanceMeters!.toStringAsFixed(0)}m'
        : '${(distanceMeters! / 1000).toStringAsFixed(1)}km';
  }
}


class RouteStop {
  final int sequence;
  final int stopId;
  final String stopName;
  final double latitude;
  final double longitude;

  RouteStop({
    required this.sequence,
    required this.stopId,
    required this.stopName,
    required this.latitude,
    required this.longitude,
  });

  factory RouteStop.fromJson(Map<String, dynamic> json) => RouteStop(
        sequence: json['sequence'] as int,
        stopId: json['stop_id'] as int,
        stopName: json['stop_name'] as String,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
      );
}


class RouteDetails {
  final int routeId;
  final String routeName;
  final String routeType;
  final double totalDistanceMeters;
  final double estimatedTimeSeconds;
  final Map<String, dynamic> geometry;
  final List<RouteStop> stops;

  RouteDetails({
    required this.routeId,
    required this.routeName,
    required this.routeType,
    required this.totalDistanceMeters,
    required this.estimatedTimeSeconds,
    required this.geometry,
    required this.stops,
  });

  factory RouteDetails.fromJson(Map<String, dynamic> json) => RouteDetails(
        routeId: json['route_id'] as int,
        routeName: json['route_name'] as String,
        routeType: json['route_type'] as String,
        totalDistanceMeters:
            (json['total_distance_meters'] as num).toDouble(),
        estimatedTimeSeconds:
            (json['estimated_time_seconds'] as num).toDouble(),
        geometry: json['geometry'] as Map<String, dynamic>,
        stops: (json['stops'] as List)
            .map((s) => RouteStop.fromJson(s as Map<String, dynamic>))
            .toList(),
      );

  // Flatten GeoJSON coordinates for drawing on map
  List<List<double>> get flatCoordinates {
    try {
      final type = geometry['type'] as String?;
      final coords = geometry['coordinates'];
      if (type == 'LineString' && coords is List) {
        return coords.map<List<double>>((c) =>
            [(c[1] as num).toDouble(), (c[0] as num).toDouble()]).toList();
      }
      if (type == 'MultiLineString' && coords is List) {
        return coords
            .expand((line) => (line as List))
            .map<List<double>>((c) =>
                [(c[1] as num).toDouble(), (c[0] as num).toDouble()])
            .toList();
      }
    } catch (_) {}
    return [];
  }
}


class WalkingSegment {
  final int seq;
  final int? wayId;
  final String? wayName;
  final double? lengthMeters;
  final double cost;
  final Map<String, dynamic> geometry;

  WalkingSegment({
    required this.seq,
    this.wayId,
    this.wayName,
    this.lengthMeters,
    required this.cost,
    required this.geometry,
  });

  factory WalkingSegment.fromJson(Map<String, dynamic> json) => WalkingSegment(
        seq: json['seq'] as int,
        wayId: json['way_id'] as int?,
        wayName: json['way_name'] as String?,
        lengthMeters: (json['length_meters'] as num?)?.toDouble(),
        cost: (json['cost'] as num).toDouble(),
        geometry: json['geometry'] as Map<String, dynamic>? ?? {},
      );

  // Extract [lat, lng] pairs from GeoJSON geometry
  List<List<double>> get coordinates {
    try {
      final type = geometry['type'] as String?;
      final coords = geometry['coordinates'];
      if (type == 'LineString' && coords is List) {
        return coords.map<List<double>>((c) =>
            [(c[1] as num).toDouble(), (c[0] as num).toDouble()]).toList();
      }
    } catch (_) {}
    return [];
  }
}


class CompleteJourney {
  final LocationPoint startLocation;
  final LocationPoint endLocation;
  final List<NearestStop> nearestStartStops;
  final List<NearestStop> nearestEndStops;
  final List<BusRoute> directRoutes;
  final bool hasDirectRoute;
  final List<WalkingSegment>? walkingToStart;
  final List<WalkingSegment>? walkingFromEnd;

  CompleteJourney({
    required this.startLocation,
    required this.endLocation,
    required this.nearestStartStops,
    required this.nearestEndStops,
    required this.directRoutes,
    required this.hasDirectRoute,
    this.walkingToStart,
    this.walkingFromEnd,
  });

  factory CompleteJourney.fromJson(Map<String, dynamic> json) =>
      CompleteJourney(
        startLocation:
            LocationPoint.fromJson(json['start_location'] as Map<String, dynamic>),
        endLocation:
            LocationPoint.fromJson(json['end_location'] as Map<String, dynamic>),
        nearestStartStops: (json['nearest_start_stops'] as List)
            .map((s) => NearestStop.fromJson(s as Map<String, dynamic>))
            .toList(),
        nearestEndStops: (json['nearest_end_stops'] as List)
            .map((s) => NearestStop.fromJson(s as Map<String, dynamic>))
            .toList(),
        directRoutes: (json['direct_routes'] as List)
            .map((r) => BusRoute.fromJson(r as Map<String, dynamic>))
            .toList(),
        hasDirectRoute: json['has_direct_route'] as bool,
        walkingToStart: (json['walking_to_start'] as List?)
            ?.map((w) => WalkingSegment.fromJson(w as Map<String, dynamic>))
            .toList(),
        walkingFromEnd: (json['walking_from_end'] as List?)
            ?.map((w) => WalkingSegment.fromJson(w as Map<String, dynamic>))
            .toList(),
      );

  // ── Helper getters used in MapScreen ──────────────────────────────────────

  NearestStop? get closestStartStop =>
      nearestStartStops.isNotEmpty ? nearestStartStops.first : null;

  NearestStop? get closestEndStop =>
      nearestEndStops.isNotEmpty ? nearestEndStops.first : null;

  bool get hasWalkingSegments =>
      (walkingToStart?.isNotEmpty ?? false) ||
      (walkingFromEnd?.isNotEmpty ?? false);

  double get totalWalkingMeters {
    double total = 0;
    walkingToStart?.forEach((w) => total += w.lengthMeters ?? 0);
    walkingFromEnd?.forEach((w) => total += w.lengthMeters ?? 0);
    return total;
  }

  String get formattedWalkingDistance {
    final meters = totalWalkingMeters;
    return meters < 1000
        ? '${meters.toStringAsFixed(0)}m'
        : '${(meters / 1000).toStringAsFixed(1)}km';
  }
}