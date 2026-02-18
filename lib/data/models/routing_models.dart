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

  factory OSMNode.fromJson(Map<String, dynamic> json) {
    return OSMNode(
      osmId: json['osm_id'] as int,
      name: json['name'] as String?,
      isStop: json['is_stop'] as bool? ?? false,
      latitude: json['latitude'] != null
          ? (json['latitude'] as num).toDouble()
          : null,
      longitude: json['longitude'] != null
          ? (json['longitude'] as num).toDouble()
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'osm_id': osmId,
        if (name != null) 'name': name,
        'is_stop': isStop,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
      };
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

  factory OSMWay.fromJson(Map<String, dynamic> json) {
    return OSMWay(
      osmId: json['osm_id'] as int,
      name: json['name'] as String?,
      highwayType: json['highway_type'] as String?,
      source: json['source'] as int?,
      target: json['target'] as int?,
      cost: json['cost'] != null ? (json['cost'] as num).toDouble() : null,
      reverseCost: json['reverse_cost'] != null
          ? (json['reverse_cost'] as num).toDouble()
          : null,
      lengthMeters: json['length_meters'] != null
          ? (json['length_meters'] as num).toDouble()
          : null,
      geometry: json['geometry'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
        'osm_id': osmId,
        if (name != null) 'name': name,
        if (highwayType != null) 'highway_type': highwayType,
        if (source != null) 'source': source,
        if (target != null) 'target': target,
        if (cost != null) 'cost': cost,
        if (reverseCost != null) 'reverse_cost': reverseCost,
        if (lengthMeters != null) 'length_meters': lengthMeters,
        if (geometry != null) 'geometry': geometry,
      };

  String get formattedLength {
    if (lengthMeters == null) return '';
    if (lengthMeters! >= 1000) {
      return '${(lengthMeters! / 1000).toStringAsFixed(2)} km';
    }
    return '${lengthMeters!.toStringAsFixed(0)} m';
  }
}

class BusStop {
  final int stopId;
  final String? name;
  final double? latitude;
  final double? longitude;

  BusStop({
    required this.stopId,
    this.name,
    this.latitude,
    this.longitude,
  });

  factory BusStop.fromJson(Map<String, dynamic> json) {
    return BusStop(
      stopId: json['stop_id'] as int,
      name: json['name'] as String?,
      latitude: json['latitude'] != null
          ? (json['latitude'] as num).toDouble()
          : null,
      longitude: json['longitude'] != null
          ? (json['longitude'] as num).toDouble()
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'stop_id': stopId,
        if (name != null) 'name': name,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
      };
}

class Route {
  final int routeId;
  final String? routeName;
  final String? routeType;
  final Map<String, dynamic>? geometry;

  Route({
    required this.routeId,
    this.routeName,
    this.routeType,
    this.geometry,
  });

  factory Route.fromJson(Map<String, dynamic> json) {
    return Route(
      routeId: json['route_id'] as int,
      routeName: json['route_name'] as String?,
      routeType: json['route_type'] as String?,
      geometry: json['geometry'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
        'route_id': routeId,
        if (routeName != null) 'route_name': routeName,
        if (routeType != null) 'route_type': routeType,
        if (geometry != null) 'geometry': geometry,
      };

  List<List<List<double>>> get coordinates {
    if (geometry == null || geometry!['type'] != 'MultiLineString') return [];
    return (geometry!['coordinates'] as List)
        .map((line) => (line as List)
            .map((coord) => [
                  (coord[1] as num).toDouble(), // lat
                  (coord[0] as num).toDouble(), // lng
                ])
            .toList())
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
          .map((s) => BusStop.fromJson(s))
          .toList(),
    );
  }
}