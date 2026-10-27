import 'person.dart';

class ViewingProperty {
  final int id;
  final String title;
  final String city;
  final String location;
  final String? coverUrl;

  const ViewingProperty({
    required this.id,
    required this.title,
    required this.city,
    required this.location,
    this.coverUrl,
  });

  factory ViewingProperty.fromJson(Map<String, dynamic> json) {
    return ViewingProperty(
      id: json['id'] as int,
      title: json['title'] as String? ?? '',
      city: json['city'] as String? ?? '',
      location: json['location'] as String? ?? '',
      coverUrl: json['cover_url'] as String?,
    );
  }
}

/// A request to see a flat at a given time.
class Viewing {
  static const String pending = 'kutilmoqda';
  static const String confirmed = 'tasdiqlandi';
  static const String declined = 'rad_etildi';
  static const String cancelled = 'bekor_qilindi';

  final int id;
  final ViewingProperty property;
  final Person renter;
  final Person owner;
  final DateTime scheduledAt; // local time
  final String note;
  final String status;
  final DateTime createdAt;
  final String role; // "renter" | "owner": which side the signed-in person is

  const Viewing({
    required this.id,
    required this.property,
    required this.renter,
    required this.owner,
    required this.scheduledAt,
    required this.note,
    required this.status,
    required this.createdAt,
    required this.role,
  });

  factory Viewing.fromJson(Map<String, dynamic> json) {
    return Viewing(
      id: json['id'] as int,
      property: ViewingProperty.fromJson(json['property'] as Map<String, dynamic>),
      renter: Person.fromJson(json['renter'] as Map<String, dynamic>),
      owner: Person.fromJson(json['owner'] as Map<String, dynamic>),
      scheduledAt: DateTime.tryParse(json['scheduled_at'] as String? ?? '')?.toLocal() ?? DateTime.now(),
      note: json['note'] as String? ?? '',
      status: json['status'] as String? ?? pending,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal() ?? DateTime.now(),
      role: json['role'] as String? ?? 'renter',
    );
  }

  bool get isOwnerSide => role == 'owner';
  bool get isPending => status == pending;
  bool get isConfirmed => status == confirmed;

  /// A request that is over: declined, cancelled, or in the past.
  bool get isClosed =>
      status == declined || status == cancelled || scheduledAt.isBefore(DateTime.now());

  /// The person on the other side of this viewing.
  Person get counterpart => isOwnerSide ? renter : owner;

  String get statusLabel {
    switch (status) {
      case confirmed:
        return 'Tasdiqlandi';
      case declined:
        return 'Rad etildi';
      case cancelled:
        return 'Bekor qilindi';
      default:
        return 'Javob kutilmoqda';
    }
  }
}
