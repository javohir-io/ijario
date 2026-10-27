/// The public face of another user: what you see on a listing, in a chat
/// or on a viewing request.
class Person {
  final int id;
  final String fullName;
  final String? phone;
  final String? telegram;
  final String? avatarUrl;

  const Person({
    required this.id,
    required this.fullName,
    this.phone,
    this.telegram,
    this.avatarUrl,
  });

  factory Person.fromJson(Map<String, dynamic> json) {
    return Person(
      id: json['id'] as int? ?? 0,
      fullName: json['full_name'] as String? ?? 'Foydalanuvchi',
      phone: json['phone'] as String?,
      telegram: json['telegram'] as String?,
      avatarUrl: json['avatar_url'] as String?,
    );
  }
}
