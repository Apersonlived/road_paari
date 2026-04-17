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
  final double? distanceMeters;
  final double? fareNrs;
  final double? estimatedTimeSeconds;

  BusRoute({
    required this.routeId,
    required this.routeName,
    required this.routeType,
    required this.isDirect,
    this.distanceMeters,
    this.fareNrs,
    this.estimatedTimeSeconds,
  });

  factory BusRoute.fromJson(Map<String, dynamic> json) => BusRoute(
        routeId: json['route_id'] as int,
        routeName: json['route_name'] as String,
        routeType: json['route_type'] as String,
        isDirect: json['is_direct'] as bool,
        distanceMeters: (json['distance_meters'] as num?)?.toDouble(),
        fareNrs: (json['fare_nrs'] as num?)?.toDouble(),
        estimatedTimeSeconds: (json['estimated_time_seconds'] as num?)?.toDouble(),
      );

  String get formattedDistance {
    if (distanceMeters == null) return '';
    return distanceMeters! < 1000
        ? '${distanceMeters!.toStringAsFixed(0)}m'
        : '${(distanceMeters! / 1000).toStringAsFixed(1)}km';
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

  double get effectiveLengthMeters {
    if (lengthMeters != null && lengthMeters! > 0) return lengthMeters!;
    // Fall back to cost * walking speed (1.4 m/s)
    if (cost > 0) return cost * 1.4;
    return 0;
  }

  List<List<double>> get coordinates {
    try {
      final type = geometry['type'] as String?;
      final coords = geometry['coordinates'];
      if (type == 'LineString' && coords is List) {
        return coords
            .map<List<double>>((c) => [(c[1] as num).toDouble(), (c[0] as num).toDouble()])
            .toList();
      }
    } catch (_) {}
    return [];
  }
}

// Add to routing_models.dart
class StopInfo {
  final int stopId;
  final String? stopName;
  final double latitude;
  final double longitude;

  StopInfo({
    required this.stopId,
    this.stopName,
    required this.latitude,
    required this.longitude,
  });

  factory StopInfo.fromJson(Map<String, dynamic> json) => StopInfo(
        stopId: json['stop_id'] as int,
        stopName: json['stop_name'] as String?,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
      );

  String get displayName => stopName ?? 'Stop #$stopId';
}

class JourneyLeg {
  final String legType;
  final String description;
  final List<WalkingSegment>? segments;
  final BusRoute? route;
  final double? fareNrs;
  final double? distanceMeters;
  final StopInfo? boardStop;
  final StopInfo? alightStop;
  final StopInfo? transferStop;

  JourneyLeg({
    required this.legType,
    required this.description,
    this.segments,
    this.route,
    this.fareNrs,
    this.distanceMeters,
    this.boardStop,
    this.alightStop,
    this.transferStop,
  });

  factory JourneyLeg.fromJson(Map<String, dynamic> json) => JourneyLeg(
        legType: json['leg_type'] as String,
        description: json['description'] as String,
        segments: (json['segments'] as List?)
            ?.map((s) => WalkingSegment.fromJson(s as Map<String, dynamic>))
            .toList(),
        route: json['route'] != null
            ? BusRoute.fromJson(json['route'] as Map<String, dynamic>)
            : null,
        fareNrs: (json['fare_nrs'] as num?)?.toDouble(),
        distanceMeters: (json['distance_meters'] as num?)?.toDouble(),
        boardStop: json['board_stop'] != null
            ? StopInfo.fromJson(json['board_stop'] as Map<String, dynamic>)
            : null,
        alightStop: json['alight_stop'] != null
            ? StopInfo.fromJson(json['alight_stop'] as Map<String, dynamic>)
            : null,
        transferStop: json['transfer_stop'] != null
            ? StopInfo.fromJson(json['transfer_stop'] as Map<String, dynamic>)
            : null,
      );

  double get effectiveDistance {
    if (distanceMeters != null && distanceMeters! > 0) return distanceMeters!;
    if (segments != null) {
      return segments!.fold(0.0, (sum, s) {
        if (s.lengthMeters != null && s.lengthMeters! > 0) return sum + s.lengthMeters!;
        return sum + s.cost * 1.4;
      });
    }
    return 0;
  }
}

class CompleteJourney {
  final LocationPoint? startLocation;
  final LocationPoint? endLocation;
  final List<NearestStop> nearestStartStops;
  final List<NearestStop> nearestEndStops;
  final NearestStop? closestStartStop;
  final NearestStop? closestEndStop;
  final List<BusRoute> directRoutes;
  final List<TransferRoute> transferRoutes;
  final bool hasDirectRoute;
  final List<WalkingSegment>? walkingToStart;
  final List<WalkingSegment>? walkingFromEnd;
  final List<JourneyLeg> journeyLegs;
  final double totalFareNrs;
  final double totalDistanceMeters;
  final double totalEstimatedTimeSeconds;
  final String? errorMessage;

  CompleteJourney({
    this.startLocation,
    this.endLocation,
    this.nearestStartStops = const [],
    this.nearestEndStops = const [],
    this.closestStartStop,
    this.closestEndStop,
    this.directRoutes = const [],
    this.transferRoutes = const [],
    this.hasDirectRoute = false,
    this.walkingToStart,
    this.walkingFromEnd,
    this.journeyLegs = const [],
    this.totalFareNrs = 0.0,
    this.totalDistanceMeters = 0.0,
    this.totalEstimatedTimeSeconds = 0.0,
    this.errorMessage,
  });

  factory CompleteJourney.fromJson(Map<String, dynamic> json) => CompleteJourney(
        startLocation: json['start_location'] != null
            ? LocationPoint.fromJson(json['start_location'])
            : null,
        endLocation: json['end_location'] != null
            ? LocationPoint.fromJson(json['end_location'])
            : null,
        nearestStartStops: (json['nearest_start_stops'] as List? ?? [])
            .map((s) => NearestStop.fromJson(s as Map<String, dynamic>))
            .toList(),
        nearestEndStops: (json['nearest_end_stops'] as List? ?? [])
            .map((s) => NearestStop.fromJson(s as Map<String, dynamic>))
            .toList(),
        closestStartStop: json['closest_start_stop'] != null
            ? NearestStop.fromJson(json['closest_start_stop'])
            : null,
        closestEndStop: json['closest_end_stop'] != null
            ? NearestStop.fromJson(json['closest_end_stop'])
            : null,
        directRoutes: (json['direct_routes'] as List? ?? [])
            .map((r) => BusRoute.fromJson(r as Map<String, dynamic>))
            .toList(),
        transferRoutes: (json['transfer_routes'] as List? ?? [])
            .map((r) => TransferRoute.fromJson(r as Map<String, dynamic>))
            .toList(),
        hasDirectRoute: json['has_direct_route'] as bool? ?? false,
        walkingToStart: (json['walking_to_start'] as List?)
            ?.map((w) => WalkingSegment.fromJson(w as Map<String, dynamic>))
            .toList(),
        walkingFromEnd: (json['walking_from_end'] as List?)
            ?.map((w) => WalkingSegment.fromJson(w as Map<String, dynamic>))
            .toList(),
        journeyLegs: (json['journey_legs'] as List? ?? [])
            .map((j) => JourneyLeg.fromJson(j as Map<String, dynamic>))
            .toList(),
        totalFareNrs: (json['total_fare_nrs'] as num? ?? 0).toDouble(),
        totalDistanceMeters: (json['total_distance_meters'] as num? ?? 0).toDouble(),
        totalEstimatedTimeSeconds: (json['total_estimated_time_seconds'] as num? ?? 0).toDouble(),
        errorMessage: json['error_message'] as String?,
      );

  bool get hasWalkingSegments =>
      (walkingToStart?.isNotEmpty ?? false) ||
      (walkingFromEnd?.isNotEmpty ?? false);

  double get totalWalkingMeters {
    double total = 0;
    walkingToStart?.forEach((w) => total += w.lengthMeters ?? 0);
    walkingFromEnd?.forEach((w) => total += w.lengthMeters ?? 0);
    return total;
  }

  double get computedTotalDistanceMeters {
  if (totalDistanceMeters > 0) return totalDistanceMeters;
  // Recompute from legs
  double total = 0;
  for (final leg in journeyLegs) {
    if (leg.distanceMeters != null && leg.distanceMeters! > 0) {
      total += leg.distanceMeters!;
    } else if (leg.segments != null) {
      total += leg.segments!.fold(0.0, (sum, s) => sum + s.effectiveLengthMeters);
    }
  }
  return total;
}

  String get formattedTotalDistance {
    return totalDistanceMeters < 1000
        ? '${totalDistanceMeters.toStringAsFixed(0)}m'
        : '${(totalDistanceMeters / 1000).toStringAsFixed(1)}km';
  }

  String get formattedTotalFare => 'Nrs. ${totalFareNrs.toStringAsFixed(0)}';
}

class TransferRoute {
  final int firstRouteId;
  final String firstRouteName;
  final int transferStopId;
  final String? transferStopName;
  final int secondRouteId;
  final String secondRouteName;
  final int? totalStopCount;
  final double? transferWalkMeters;
  final double? totalDistanceMeters;

  TransferRoute({
    required this.firstRouteId,
    required this.firstRouteName,
    required this.transferStopId,
    this.transferStopName,
    required this.secondRouteId,
    required this.secondRouteName,
    this.totalStopCount,
    this.transferWalkMeters,
    this.totalDistanceMeters,
  });

  factory TransferRoute.fromJson(Map<String, dynamic> json) => TransferRoute(
        firstRouteId: json['first_route_id'] as int,
        firstRouteName: json['first_route_name'] as String,
        transferStopId: json['transfer_stop_id'] as int,
        transferStopName: json['transfer_stop_name'] as String?,
        secondRouteId: json['second_route_id'] as int,
        secondRouteName: json['second_route_name'] as String,
        totalStopCount: json['total_stop_count'] as int?,
        transferWalkMeters: (json['transfer_walk_meters'] as num?)?.toDouble(),
        totalDistanceMeters: (json['total_distance_meters'] as num?)?.toDouble(),
      );

  String get formattedTotalDistance {
    if (totalDistanceMeters == null) return '';
    return totalDistanceMeters! < 1000
        ? '${totalDistanceMeters!.toStringAsFixed(0)}m'
        : '${(totalDistanceMeters! / 1000).toStringAsFixed(1)}km';
  }
}

class RouteDetails {
  final int routeId;
  final String routeName;
  final String routeType;
  final double totalDistanceMeters;
  final double estimatedTimeSeconds;
  final double fareNrs;
  final Map<String, dynamic> geometry;
  final List<RouteStop> stops;

  RouteDetails({
    required this.routeId,
    required this.routeName,
    required this.routeType,
    required this.totalDistanceMeters,
    required this.estimatedTimeSeconds,
    required this.fareNrs,
    required this.geometry,
    required this.stops,
  });

  factory RouteDetails.fromJson(Map<String, dynamic> json) {
    return RouteDetails(
      routeId: json['route_id'] as int,
      routeName: json['route_name'] as String? ?? '',
      routeType: json['route_type'] as String? ?? '',
      totalDistanceMeters: (json['total_distance_meters'] as num? ?? 0).toDouble(),
      estimatedTimeSeconds: (json['estimated_time_seconds'] as num? ?? 0).toDouble(),
      fareNrs: (json['fare_nrs'] as num? ?? 0).toDouble(),
      geometry: json['geometry'] as Map<String, dynamic>? ?? {'type': 'LineString', 'coordinates': []},
      stops: (json['stops'] as List? ?? [])
          .map((s) => RouteStop.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }
}

class RouteStop {
  final int sequence;
  final int stopId;
  final String? stopName;
  final double latitude;
  final double longitude;

  RouteStop({
    required this.sequence,
    required this.stopId,
    this.stopName,
    required this.latitude,
    required this.longitude,
  });

  factory RouteStop.fromJson(Map<String, dynamic> json) => RouteStop(
        sequence: json['sequence'] as int,
        stopId: json['stop_id'] as int,
        stopName: json['stop_name'] as String? ?? 'Stop #${json['stop_id']}',
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
      );
}