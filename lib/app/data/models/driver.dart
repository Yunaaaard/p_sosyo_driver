class Driver {
  final int? id;
  final String username;
  final String password;
  final String fullName;
  final String pin;
  final bool rememberMe;
  final bool isAuthenticated;
  final String createdAt;

  Driver({
    this.id,
    required this.username,
    required this.password,
    required this.fullName,
    required this.pin,
    this.rememberMe = false,
    this.isAuthenticated = false,
    String? createdAt,
  }) : createdAt = createdAt ?? DateTime.now().toIso8601String();

  /// Create a Driver from a SQLite row map.
  factory Driver.fromMap(Map<String, dynamic> map) {
    return Driver(
      id: map['id'] as int?,
      username: map['username'] as String,
      password: map['password'] as String,
      fullName: map['full_name'] as String,
      pin: map['pin'] as String,
      rememberMe: (map['remember_me'] as int?) == 1,
      isAuthenticated: (map['is_authenticated'] as int?) == 1,
      createdAt: map['created_at'] as String,
    );
  }

  /// Convert this Driver to a SQLite row map.
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'username': username,
      'password': password,
      'full_name': fullName,
      'pin': pin,
      'remember_me': rememberMe ? 1 : 0,
      'is_authenticated': isAuthenticated ? 1 : 0,
      'created_at': createdAt,
    };
  }

  /// Returns a copy with optional field overrides.
  Driver copyWith({
    int? id,
    String? username,
    String? password,
    String? fullName,
    String? pin,
    bool? rememberMe,
    bool? isAuthenticated,
    String? createdAt,
  }) {
    return Driver(
      id: id ?? this.id,
      username: username ?? this.username,
      password: password ?? this.password,
      fullName: fullName ?? this.fullName,
      pin: pin ?? this.pin,
      rememberMe: rememberMe ?? this.rememberMe,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
