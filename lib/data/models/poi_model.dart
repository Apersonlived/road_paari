class POICategory {
  final int id;
  final String name;
  final String? description;
  final String? icon;

  POICategory({
    required this.id,
    required this.name,
    this.description,
    this.icon,
  });

  factory POICategory.fromJson(Map<String, dynamic> json) {
    return POICategory(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      icon: json['icon'],
    );
  }
}

class POI {
  final int id;
  final String name;
  final String? description;
  final int? categoryId;
  final double? latitude;
  final double? longitude;
  final String? imageUrl;
  final DateTime? createdAt;
  final int? createdBy;
  final double? distanceMeters; // for nearby results

  POI({
    required this.id,
    required this.name,
    this.description,
    this.categoryId,
    this.latitude,
    this.longitude,
    this.imageUrl,
    this.createdAt,
    this.createdBy,
    this.distanceMeters,
  });

  factory POI.fromJson(Map<String, dynamic> json) {
    return POI(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      categoryId: json['category_id'],
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      imageUrl: json['image_url'],
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
      createdBy: json['created_by'],
      distanceMeters: (json['distance_meters'] as num?)?.toDouble(),
    );
  }
}