class User {
  final int? id;
  final String login;
  final String name;
  final String? createdAt;
  final String? updatedAt;

  User({required this.id, required this.login, required this.name, this.createdAt, this.updatedAt});

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: (json['id'] as num?)?.toInt(),
        login: (json['login'] ?? '') as String,
        name: (json['name'] ?? '') as String,
        createdAt: json['created_at'] as String?,
        updatedAt: json['updated_at'] as String?,
      );

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'login': login,
        'name': name,
        if (createdAt != null) 'created_at': createdAt,
        if (updatedAt != null) 'updated_at': updatedAt,
      };
}
