class User {
  final int id;
  final String email;
  final String? fullName;
  final bool isActive;
  final DateTime createdAt;
  final bool isAdmin;
  final String? image;

  User({
    required this.id,
    required this.email,
    this.fullName,
    required this.isActive,
    required this.createdAt,
    required this.isAdmin,
    required this.image
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      email: json['email'] as String,
      fullName: json['full_name'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      isAdmin: json['is_active'] as bool? ?? true,
      image: json['user_image_url'] as String?
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'full_name': fullName,
        'is_active': isActive,
        'created_at': createdAt.toIso8601String(),
        'is_admin': isAdmin,
        'user_image_url': image
      };

  User copyWith({
    int? id,
    String? email,
    String? fullName,
    bool? isActive,
    DateTime? createdAt,
    bool? isAdmin,
    String? image
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      isAdmin: isAdmin ?? this.isAdmin,
      image: image ?? this.image
    );
  }
}

class UserCreateRequest {
  final String email;
  final String password;
  final String? fullName;

  UserCreateRequest({
    required this.email,
    required this.password,
    this.fullName,
  });

  Map<String, dynamic> toJson() => {
        'email': email,
        'password': password,
        if (fullName != null) 'full_name': fullName,
      };
}

class UserUpdateRequest {
  final String? fullName;
  final String? email;

  UserUpdateRequest({this.fullName, this.email});

  Map<String, dynamic> toJson() => {
        if (fullName != null) 'full_name': fullName,
        if (email != null) 'email': email,
      };
}

class UserPasswordUpdateRequest {
  final String oldPassword;
  final String newPassword;

  UserPasswordUpdateRequest({
    required this.oldPassword,
    required this.newPassword,
  });

  Map<String, dynamic> toJson() => {
        'old_password': oldPassword,
        'new_password': newPassword,
      };
}