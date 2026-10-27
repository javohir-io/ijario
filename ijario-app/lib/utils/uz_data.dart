import 'package:flutter/material.dart';

/// Static reference data for Uzbekistan. Everything here is checkable:
/// Tashkent has 12 districts (tumanlar); the other cities are regional centres.
class UzData {
  UzData._();

  static const List<String> cities = [
    'Toshkent',
    'Samarqand',
    'Buxoro',
    'Andijon',
    'Namangan',
    "Farg'ona",
    'Nukus',
    'Qarshi',
    'Navoiy',
    'Urganch',
    'Jizzax',
    'Termiz',
    'Guliston',
  ];

  static const Map<String, List<String>> districts = {
    'Toshkent': [
      'Bektemir',
      'Chilonzor',
      'Mirobod',
      "Mirzo Ulug'bek",
      'Olmazor',
      'Sergeli',
      'Shayxontohur',
      'Uchtepa',
      'Yakkasaroy',
      'Yangihayot',
      'Yashnobod',
      'Yunusobod',
    ],
  };

  static List<String> districtsOf(String? city) => districts[city] ?? const [];

  /// Highest to lowest quality. ("Yomon" from the old app is gone: nobody
  /// advertises a flat as bad, and it made the filter noisy.)
  static const List<String> renovations = [
    "Evro ta'mir",
    'Yaxshi',
    "O'rtacha",
    "Ta'mir talab",
  ];

  static const List<String> amenities = [
    'Mebel',
    'Konditsioner',
    'Wi-Fi',
    'Kir yuvish mashinasi',
    'Muzlatgich',
    'Televizor',
    'Lift',
    'Avtoturargoh',
    'Balkon',
    'Xavfsizlik',
  ];

  static IconData amenityIcon(String name) {
    switch (name) {
      case 'Mebel':
        return Icons.chair_alt_rounded;
      case 'Konditsioner':
        return Icons.ac_unit_rounded;
      case 'Wi-Fi':
        return Icons.wifi_rounded;
      case 'Kir yuvish mashinasi':
        return Icons.local_laundry_service_rounded;
      case 'Muzlatgich':
        return Icons.kitchen_rounded;
      case 'Televizor':
        return Icons.tv_rounded;
      case 'Lift':
        return Icons.elevator_rounded;
      case 'Avtoturargoh':
        return Icons.local_parking_rounded;
      case 'Balkon':
        return Icons.balcony_rounded;
      case 'Xavfsizlik':
        return Icons.shield_rounded;
      default:
        return Icons.check_rounded;
    }
  }

  /// Viewing slots offered to renters (local time).
  static const List<int> viewingHours = [9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20];

  static const List<String> reportReasons = [
    'aldamchi',
    'narx_notogri',
    'allaqachon_band',
    'boshqa',
  ];

  static String reportReasonLabel(String key) {
    switch (key) {
      case 'aldamchi':
        return "Aldamchi e'lon (rasm yoki ma'lumot yolg'on)";
      case 'narx_notogri':
        return "Narx e'londagidan boshqacha";
      case 'allaqachon_band':
        return 'Uy allaqachon ijaraga berilgan';
      default:
        return 'Boshqa sabab';
    }
  }
}
