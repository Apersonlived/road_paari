class OSMNode {
  final int osmId;
  final String? name;
  final bool isStop;
  final double? latitude;
  final double? longitude;

  OSMNode({
    required this.osmId,
    this.name,
    this.isStop = false,
    this.latitude,
    this.longitude,
  });

  factory OSMNode.fromJson(Map<String, dynamic> json) => OSMNode(
        osmId: json['osm_id'] as int,
        name: json['name'] as String?,
        isStop: json['is_stop'] as bool? ?? false,
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
      );
}

class OSMWay {
  final int osmId;
  final String? name;
  final String? highwayType;
  final int? source;
  final int? target;
  final double? cost;
  final double? reverseCost;
  final double? lengthMeters;
  final Map<String, dynamic>? geometry;

  OSMWay({
    required this.osmId,
    this.name,
    this.highwayType,
    this.source,
    this.target,
    this.cost,
    this.reverseCost,
    this.lengthMeters,
    this.geometry,
  });

  factory OSMWay.fromJson(Map<String, dynamic> json) => OSMWay(
        osmId: json['osm_id'] as int,
        name: json['name'] as String?,
        highwayType: json['highway_type'] as String?,
        source: json['source'] as int?,
        target: json['target'] as int?,
        cost: (json['cost'] as num?)?.toDouble(),
        reverseCost: (json['reverse_cost'] as num?)?.toDouble(),
        lengthMeters: (json['length_meters'] as num?)?.toDouble(),
        geometry: json['geometry'] as Map<String, dynamic>?,
      );

  String get formattedLength {
    if (lengthMeters == null) return '';
    return lengthMeters! >= 1000
        ? '${(lengthMeters! / 1000).toStringAsFixed(2)} km'
        : '${lengthMeters!.toStringAsFixed(0)} m';
  }
}

class BusStop {
  final int stopId;
  final String? name;
  final double? latitude;
  final double? longitude;

  BusStop({required this.stopId, this.name, this.latitude, this.longitude});

  factory BusStop.fromJson(Map<String, dynamic> json) => BusStop(
        stopId: json['stop_id'] as int,
        name: json['name'] as String?,
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
      );
}

class Route {
  final int routeId;
  final String? routeName;
  final String? routeType;
  final Map<String, dynamic>? geometry;

  Route({required this.routeId, this.routeName, this.routeType, this.geometry});

  factory Route.fromJson(Map<String, dynamic> json) => Route(
        routeId: json['route_id'] as int,
        routeName: json['route_name'] as String?,
        routeType: json['route_type'] as String?,
        geometry: json['geometry'] as Map<String, dynamic>?,
      );

  /// Extracts lat,long points from MultiLineString geometry
  List<List<double>> get flatCoordinates {
    if (geometry == null || geometry!['type'] != 'MultiLineString') return [];
    final lines = geometry!['coordinates'] as List;
    return lines
        .expand((line) => (line as List).map((coord) => [
              (coord[1] as num).toDouble(),
              (coord[0] as num).toDouble(),
            ]))
        .toList();
  }
}

class RouteWithStops extends Route {
  final List<BusStop> stops;

  RouteWithStops({
    required super.routeId,
    super.routeName,
    super.routeType,
    super.geometry,
    required this.stops,
  });

  factory RouteWithStops.fromJson(Map<String, dynamic> json) {
    final base = Route.fromJson(json);
    return RouteWithStops(
      routeId: base.routeId,
      routeName: base.routeName,
      routeType: base.routeType,
      geometry: base.geometry,
      stops: (json['stops'] as List<dynamic>? ?? [])
          .map((s) => BusStop.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }
}

// API response models 

/// Matches backend NearestStop pydantic model
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

  String get displayName => stopName ?? 'Stop $stopId';

  String get formattedDistance => distanceMeters >= 1000
      ? '${(distanceMeters / 1000).toStringAsFixed(2)} km'
      : '${distanceMeters.toStringAsFixed(0)} m';
}

/// To match with backend BusRoute pydantic model
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
    return distanceMeters! >= 1000
        ? '${(distanceMeters! / 1000).toStringAsFixed(2)} km'
        : '${distanceMeters!.toStringAsFixed(0)} m';
  }
}

/// Matches FastAPI RouteStop pydantic model
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

/// Matches FastAPI RouteDetails pydantic model
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
        totalDistanceMeters: (json['total_distance_meters'] as num).toDouble(),
        estimatedTimeSeconds: (json['estimated_time_seconds'] as num).toDouble(),
        geometry: json['geometry'] as Map<String, dynamic>,
        stops: (json['stops'] as List)
            .map((s) => RouteStop.fromJson(s as Map<String, dynamic>))
            .toList(),
      );

  String get formattedDistance => totalDistanceMeters >= 1000
      ? '${(totalDistanceMeters / 1000).toStringAsFixed(2)} km'
      : '${totalDistanceMeters.toStringAsFixed(0)} m';

  String get formattedTime {
    final minutes = (estimatedTimeSeconds / 60).round();
    if (minutes >= 60) {
      final h = minutes ~/ 60;
      final m = minutes % 60;
      return m > 0 ? '${h}h ${m}m' : '${h}h';
    }
    return '$minutes min';
  }

  /// Flattened [[lat, lng], ...] from geometry for drawing on map
  List<List<double>> get flatCoordinates {
    if (geometry['type'] != 'MultiLineString') return [];
    final lines = geometry['coordinates'] as List;
    return lines
        .expand((line) => (line as List).map((coord) => [
              (coord[1] as num).toDouble(),
              (coord[0] as num).toDouble(),
            ]))
        .toList();
  }
}

/// Matches FastAPI WalkingSegment pydantic model
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
        geometry: json['geometry'] as Map<String, dynamic>,
      );

  /// Extract [[lat, lng], ...] from LineString geometry for map drawing
  List<List<double>> get coordinates {
    if (geometry['type'] != 'LineString') return [];
    return (geometry['coordinates'] as List)
        .map((c) => [
              (c[1] as num).toDouble(),
              (c[0] as num).toDouble(),
            ])
        .toList();
  }
}

/// Matches FastAPI CompleteJourney pydantic model — this is your main "route result"
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

  factory CompleteJourney.fromJson(Map<String, dynamic> json) => CompleteJourney(
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

  //  Convenience helpers for MapScreen 

  bool get hasWalkingSegments =>
      (walkingToStart?.isNotEmpty ?? false) ||
      (walkingFromEnd?.isNotEmpty ?? false);

  /// All walking coords to draw on map: walk-to-stop + walk-from-stop
  List<List<double>> get allWalkingCoordinates => [
        ...?walkingToStart?.expand((w) => w.coordinates),
        ...?walkingFromEnd?.expand((w) => w.coordinates),
      ];

  /// Total walking distance in meters
  double get totalWalkingMeters {
    final toStart =
        walkingToStart?.fold(0.0, (sum, w) => sum + (w.lengthMeters ?? 0)) ?? 0;
    final fromEnd =
        walkingFromEnd?.fold(0.0, (sum, w) => sum + (w.lengthMeters ?? 0)) ?? 0;
    return toStart + fromEnd;
  }

  String get formattedWalkingDistance {
    final m = totalWalkingMeters;
    return m >= 1000
        ? '${(m / 1000).toStringAsFixed(2)} km'
        : '${m.toStringAsFixed(0)} m';
  }

  NearestStop? get closestStartStop =>
      nearestStartStops.isNotEmpty ? nearestStartStops.first : null;

  NearestStop? get closestEndStop =>
      nearestEndStops.isNotEmpty ? nearestEndStops.first : null;
}

class LocationPoint {
  final double lat;
  final double lng;

  LocationPoint({required this.lat, required this.lng});

  factory LocationPoint.fromJson(Map<String, dynamic> json) => LocationPoint(
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {'lat': lat, 'lng': lng};
}