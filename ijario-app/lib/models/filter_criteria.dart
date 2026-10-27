import 'package:flutter/material.dart';

import 'property.dart';

enum SortMode { newest, cheapest, priciest, largest }

extension SortModeLabel on SortMode {
  String get label {
    switch (this) {
      case SortMode.newest:
        return 'Yangilari';
      case SortMode.cheapest:
        return 'Avval arzonlari';
      case SortMode.priciest:
        return 'Avval qimmatlari';
      case SortMode.largest:
        return 'Eng kattalari';
    }
  }
}

/// What a person has chosen to narrow the list down, and whether a given
/// [Property] fits it. Filtering happens on the loaded list, so results
/// update instantly while sliders move.
class FilterCriteria {
  /// Slider bounds. Hitting the top end means "no upper limit".
  static const double priceMin = 0;
  static const double priceMax = 30000000; // so'm
  static const double areaMin = 10;
  static const double areaMax = 200; // m²

  final String? city; // null = every city
  final String? district; // null = every district
  final RangeValues price; // in so'm (USD listings are converted)
  final RangeValues area;
  final int minRooms; // 0 = any
  final String? renovation;
  final Set<String> amenities;
  final bool ownerOnly;
  final bool studentOnly;
  final bool nearMetro;
  final bool utilitiesIncluded;
  final String? unit; // null = both, "Oy" or "Kun"

  const FilterCriteria({
    this.city,
    this.district,
    this.price = const RangeValues(priceMin, priceMax),
    this.area = const RangeValues(areaMin, areaMax),
    this.minRooms = 0,
    this.renovation,
    this.amenities = const {},
    this.ownerOnly = false,
    this.studentOnly = false,
    this.nearMetro = false,
    this.utilitiesIncluded = false,
    this.unit,
  });

  bool get _priceActive => price.start > priceMin || price.end < priceMax;
  bool get _areaActive => area.start > areaMin || area.end < areaMax;

  /// Filters in the sheet (the city / district chips on the home screen are
  /// not counted here: they are always visible).
  int get activeCount {
    var n = 0;
    if (_priceActive) n++;
    if (_areaActive) n++;
    if (minRooms > 0) n++;
    if (renovation != null) n++;
    n += amenities.length;
    if (ownerOnly) n++;
    if (studentOnly) n++;
    if (nearMetro) n++;
    if (utilitiesIncluded) n++;
    if (unit != null) n++;
    return n;
  }

  bool get isActive => activeCount > 0 || city != null || district != null;

  FilterCriteria copyWith({
    String? city,
    bool clearCity = false,
    String? district,
    bool clearDistrict = false,
    RangeValues? price,
    RangeValues? area,
    int? minRooms,
    String? renovation,
    bool clearRenovation = false,
    Set<String>? amenities,
    bool? ownerOnly,
    bool? studentOnly,
    bool? nearMetro,
    bool? utilitiesIncluded,
    String? unit,
    bool clearUnit = false,
  }) {
    return FilterCriteria(
      city: clearCity ? null : (city ?? this.city),
      district: clearDistrict ? null : (district ?? this.district),
      price: price ?? this.price,
      area: area ?? this.area,
      minRooms: minRooms ?? this.minRooms,
      renovation: clearRenovation ? null : (renovation ?? this.renovation),
      amenities: amenities ?? this.amenities,
      ownerOnly: ownerOnly ?? this.ownerOnly,
      studentOnly: studentOnly ?? this.studentOnly,
      nearMetro: nearMetro ?? this.nearMetro,
      utilitiesIncluded: utilitiesIncluded ?? this.utilitiesIncluded,
      unit: clearUnit ? null : (unit ?? this.unit),
    );
  }

  /// Everything cleared except the chosen city / district.
  FilterCriteria clearedSheetFilters() => FilterCriteria(city: city, district: district);

  bool matches(Property p) {
    if (city != null && p.city != city) return false;
    if (district != null && p.location != district) return false;
    if (unit != null && p.priceUnit != unit) return false;

    if (p.priceUzs < price.start) return false;
    if (price.end < priceMax && p.priceUzs > price.end) return false;

    if (p.area < area.start) return false;
    if (area.end < areaMax && p.area > area.end) return false;

    if (minRooms > 0 && p.bedrooms < minRooms) return false;
    if (renovation != null && p.renovation != renovation) return false;
    if (ownerOnly && !p.isPostedByOwner) return false;
    if (studentOnly && !p.studentFriendly) return false;
    if (nearMetro && !p.hasMetro) return false;
    if (utilitiesIncluded && !p.utilitiesIncluded) return false;

    if (amenities.isNotEmpty) {
      final have = p.amenities.map((e) => e.toLowerCase()).toSet();
      for (final wanted in amenities) {
        if (!have.contains(wanted.toLowerCase())) return false;
      }
    }
    return true;
  }
}

/// Sorts a copy of [items] without touching the original list.
List<Property> sortProperties(List<Property> items, SortMode mode) {
  final list = List<Property>.of(items);
  switch (mode) {
    case SortMode.newest:
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      break;
    case SortMode.cheapest:
      list.sort((a, b) => a.monthlyEquivalentUzs.compareTo(b.monthlyEquivalentUzs));
      break;
    case SortMode.priciest:
      list.sort((a, b) => b.monthlyEquivalentUzs.compareTo(a.monthlyEquivalentUzs));
      break;
    case SortMode.largest:
      list.sort((a, b) => b.area.compareTo(a.area));
      break;
  }
  return list;
}
