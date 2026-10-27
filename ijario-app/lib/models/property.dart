import 'person.dart';

class PropertyImage {
  final int id;
  final String url;

  const PropertyImage({required this.id, required this.url});

  factory PropertyImage.fromJson(Map<String, dynamic> json) {
    return PropertyImage(id: json['id'] as int, url: json['url'] as String);
  }
}

/// How a monthly price compares with similar active listings. The server
/// only sends this when it has enough comparable listings.
class PriceInsight {
  final double median;
  final String currency;
  final int diffPercent; // negative = cheaper than the median
  final int sampleSize;
  final String scope; // "tuman" | "shahar"
  final String verdict; // "arzon" | "bozor_narxida" | "qimmat"

  const PriceInsight({
    required this.median,
    required this.currency,
    required this.diffPercent,
    required this.sampleSize,
    required this.scope,
    required this.verdict,
  });

  factory PriceInsight.fromJson(Map<String, dynamic> json) {
    return PriceInsight(
      median: (json['median'] as num?)?.toDouble() ?? 0,
      currency: json['currency'] as String? ?? 'UZS',
      diffPercent: (json['diff_percent'] as num?)?.toInt() ?? 0,
      sampleSize: (json['sample_size'] as num?)?.toInt() ?? 0,
      scope: json['scope'] as String? ?? 'shahar',
      verdict: json['verdict'] as String? ?? 'bozor_narxida',
    );
  }

  String get scopeLabel => scope == 'tuman' ? "tuman o'rtachasidan" : "shahar o'rtachasidan";

  /// "12% arzon" / "8% qimmat" / "Bozor narxida"
  String get headline {
    final abs = diffPercent.abs();
    if (verdict == 'arzon') return '$abs% arzon';
    if (verdict == 'qimmat') return '$abs% qimmat';
    return 'Bozor narxida';
  }
}

class Property {
  static const String unitMonth = 'Oy';
  static const String unitDay = 'Kun';
  static const String statusActive = 'faol';
  static const String statusRented = 'band';
  static const String ownerOwner = 'Egasi';
  static const String ownerAgent = 'Rieltor';

  final int id;
  final String title;
  final String description;
  final String city;
  final String location; // district / area
  final String? metro;
  final double price;
  final String currency; // "UZS" | "USD"
  final String priceUnit; // "Oy" | "Kun"
  final double deposit;
  final bool utilitiesIncluded;
  final int bedrooms;
  final int bathrooms;
  final int floor;
  final double area;
  final String renovation;
  final List<String> amenities;
  final bool studentFriendly;
  final String ownerType; // "Egasi" | "Rieltor"
  final String status; // "faol" | "band"
  final int views;
  final int savesCount;
  final double priceUzs; // price normalised to UZS (for sorting/filtering)
  final DateTime createdAt;
  final Person owner;
  final List<PropertyImage> images;
  final PriceInsight? insight;
  bool isSaved;

  Property({
    required this.id,
    required this.title,
    required this.description,
    required this.city,
    required this.location,
    this.metro,
    required this.price,
    required this.currency,
    required this.priceUnit,
    required this.deposit,
    required this.utilitiesIncluded,
    required this.bedrooms,
    required this.bathrooms,
    required this.floor,
    required this.area,
    required this.renovation,
    required this.amenities,
    required this.studentFriendly,
    required this.ownerType,
    required this.status,
    required this.views,
    required this.savesCount,
    required this.priceUzs,
    required this.createdAt,
    required this.owner,
    this.images = const [],
    this.insight,
    this.isSaved = false,
  });

  factory Property.fromJson(Map<String, dynamic> json) {
    final price = (json['price'] as num?)?.toDouble() ?? 0;
    final currency = json['currency'] as String? ?? 'UZS';
    final ownerJson = json['owner'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final insightJson = json['price_insight'];
    return Property(
      id: json['id'] as int,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      city: json['city'] as String? ?? 'Toshkent',
      location: json['location'] as String? ?? '',
      metro: _blankToNull(json['metro'] as String?),
      price: price,
      currency: currency,
      priceUnit: json['price_unit'] as String? ?? unitMonth,
      deposit: (json['deposit'] as num?)?.toDouble() ?? 0,
      utilitiesIncluded: json['utilities_included'] as bool? ?? false,
      bedrooms: json['bedrooms'] as int? ?? 1,
      bathrooms: json['bathrooms'] as int? ?? 1,
      floor: json['floor'] as int? ?? 1,
      area: (json['area'] as num?)?.toDouble() ?? 0,
      renovation: json['renovation'] as String? ?? "O'rtacha",
      amenities: (json['amenities'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      studentFriendly: json['student_friendly'] as bool? ?? false,
      ownerType: json['owner_type'] as String? ?? ownerOwner,
      status: json['status'] as String? ?? statusActive,
      views: json['views'] as int? ?? 0,
      savesCount: json['saves_count'] as int? ?? 0,
      priceUzs: (json['price_uzs'] as num?)?.toDouble() ?? price,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal() ?? DateTime.now(),
      owner: Person.fromJson(ownerJson),
      images: (json['images'] as List<dynamic>? ?? const [])
          .map((e) => PropertyImage.fromJson(e as Map<String, dynamic>))
          .toList(),
      insight: insightJson is Map<String, dynamic> ? PriceInsight.fromJson(insightJson) : null,
      isSaved: json['is_saved'] as bool? ?? false,
    );
  }

  static String? _blankToNull(String? v) {
    if (v == null) return null;
    final t = v.trim();
    return t.isEmpty ? null : t;
  }

  bool get isDaily => priceUnit == unitDay;

  /// For sorting only: a daily rate counts as ~30 days, so it doesn't sort
  /// below monthly listings just because the number is smaller.
  double get monthlyEquivalentUzs => isDaily ? priceUzs * 30 : priceUzs;
  bool get isRented => status == statusRented;
  bool get isPostedByOwner => ownerType == ownerOwner;
  bool get hasMetro => metro != null;
  String? get coverUrl => images.isEmpty ? null : images.first.url;

  /// "Toshkent, Yunusobod"
  String get placeLabel => location.isEmpty ? city : '$city, $location';
}
