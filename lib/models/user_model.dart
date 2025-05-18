class User {
  final String? token;
  final int? id;
  final String? username;
  final String? email;
  final DateTime? createdAt;

  User({
    this.token,
    this.id,
    this.username,
    this.email,
    this.createdAt,
  });

  @override
  String toString() {
    return 'User(id: $id, username: $username, email: $email)';
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      token: json['access_token'],  // Remove the null coalescing
      id: json['user_id'] as int?,  // Changed from 'id' to 'user_id'
      username: json['username'] as String?,
      email: json['email'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'token': token,
    'id': id,
    'username': username,
    'email': email,
    'created_at': createdAt?.toIso8601String(),
  };
}