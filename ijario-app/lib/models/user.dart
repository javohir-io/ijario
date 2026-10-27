class AppUser {
  final int id;
  final String fullName;
  final String email;
  final String? phone;
  final String? telegram;
  final String? avatarUrl;
  final bool isAdmin;

  const AppUser({
    required this.id,
    required this.fullName,
    required this.email,
    this.phone,
    this.telegram,
    this.avatarUrl,
    this.isAdmin = false,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as int,
      fullName: json['full_name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String?,
      telegram: json['telegram'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      isAdmin: json['is_admin'] as bool? ?? false,
    );
  }

  /// Same shape the API sends, so the cached copy can be read back with
  /// [AppUser.fromJson].
  Map<String, dynamic> toJson() => {
        'id': id,
        'full_name': fullName,
        'email': email,
        'phone': phone,
        'telegram': telegram,
        'avatar_url': avatarUrl,
        'is_admin': isAdmin,
      };
}
