class POICategory {
  final int id;
  final String name;
  final String? description;

  POICategory({
    required this.id,
    required this.name,
    this.description,
  });

  factory POICategory.fromJson(Map<String, dynamic> json) {
    return POICategory(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (description != null) 'description': description,
      };
}

class POICategoryCreateRequest {
  final String name;
  final String? description;

  POICategoryCreateRequest({required this.name, this.description});

  Map<String, dynamic> toJson() => {
        'name': name,
        if (description != null) 'description': description,
      };
}

class POI {
  final int id;
  final String name;
  final String? description;
  final int? categoryId;
  final double? latitude;
  final double? longitude;
  final DateTime createdAt;
  final int? createdBy;
  final String? image;

  POI({
    required this.id,
    required this.name,
    this.description,
    this.categoryId,
    this.latitude,
    this.longitude,
    required this.createdAt,
    this.createdBy,
    this.image
  });

  factory POI.fromJson(Map<String, dynamic> json) {
    return POI(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String?,
      categoryId: json['category_id'] as int?,
      latitude: json['latitude'] != null
          ? (json['latitude'] as num).toDouble()
          : null,
      longitude: json['longitude'] != null
          ? (json['longitude'] as num).toDouble()
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      createdBy: json['created_by'] as int?,
      image: json['image_url'] as String?
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (description != null) 'description': description,
        if (categoryId != null) 'category_id': categoryId,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        'created_at': createdAt.toIso8601String(),
        if (createdBy != null) 'created_by': createdBy,
        if (image !=null) 'image_url': image
      };

  POI copyWith({
    int? id,
    String? name,
    String? description,
    int? categoryId,
    double? latitude,
    double? longitude,
    DateTime? createdAt,
    int? createdBy,
    String? image
  }) {
    return POI(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      categoryId: categoryId ?? this.categoryId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      image: image ?? this.image
    );
  }
}

class POIWithDistance extends POI {
  final double? distanceMeters;

  POIWithDistance({
    required super.id,
    required super.name,
    super.description,
    super.categoryId,
    super.latitude,
    super.longitude,
    required super.createdAt,
    super.createdBy,
    super.image,
    this.distanceMeters,
  });

  factory POIWithDistance.fromJson(Map<String, dynamic> json) {
    final base = POI.fromJson(json);
    return POIWithDistance(
      id: base.id,
      name: base.name,
      description: base.description,
      categoryId: base.categoryId,
      latitude: base.latitude,
      longitude: base.longitude,
      createdAt: base.createdAt,
      createdBy: base.createdBy,
      image: base.image,
      distanceMeters: json['distance_meters'] != null
          ? (json['distance_meters'] as num).toDouble()
          : null,
    );
  }

  String get formattedDistance {
    if (distanceMeters == null) return '';
    if (distanceMeters! >= 1000) {
      return '${(distanceMeters! / 1000).toStringAsFixed(2)} km';
    }
    return '${distanceMeters!.toStringAsFixed(0)} m';
  }
}

class POICreateRequest {
  final String name;
  final String? description;
  final int? categoryId;
  final double latitude;
  final double longitude;
  final String? image;

  POICreateRequest({
    required this.name,
    this.description,
    this.categoryId,
    required this.latitude,
    required this.longitude,
    this.image
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        if (description != null) 'description': description,
        if (categoryId != null) 'category_id': categoryId,
        'latitude': latitude,
        'longitude': longitude,
        if (image != null) 'image_url': image
      };
}

class POIUpdateRequest {
  final String? name;
  final String? description;
  final int? categoryId;
  final double? latitude;
  final double? longitude;
  final String? image;

  POIUpdateRequest({
    this.name,
    this.description,
    this.categoryId,
    this.latitude,
    this.longitude,
    this.image
  });

  Map<String, dynamic> toJson() => {
        if (name != null) 'name': name,
        if (description != null) 'description': description,
        if (categoryId != null) 'category_id': categoryId,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (image != null) 'image_url': image
      };
}