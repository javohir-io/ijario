import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ijario/models/filter_criteria.dart';
import 'package:ijario/models/property.dart';
import 'package:ijario/theme/app_theme.dart';
import 'package:ijario/utils/formatters.dart';
import 'package:ijario/utils/phone_formatter.dart';
import 'package:ijario/utils/validators.dart';
import 'package:ijario/widgets/empty_state.dart';

const _nbsp = '\u00A0';

Map<String, dynamic> _json({
  int id = 1,
  String title = 'Yorug uy',
  double price = 4000000,
  String currency = 'UZS',
  double priceUzs = 4000000,
  String city = 'Toshkent',
  String location = 'Yunusobod',
  int bedrooms = 2,
  double area = 60,
  String ownerType = 'Egasi',
  String? metro,
  List<String> amenities = const [],
  bool student = false,
  String createdAt = '2026-10-01T08:00:00Z',
}) {
  return {
    'id': id,
    'title': title,
    'price': price,
    'currency': currency,
    'price_uzs': priceUzs,
    'price_unit': 'Oy',
    'city': city,
    'location': location,
    'metro': metro,
    'bedrooms': bedrooms,
    'bathrooms': 1,
    'floor': 3,
    'area': area,
    'renovation': 'Yaxshi',
    'amenities': amenities,
    'student_friendly': student,
    'owner_type': ownerType,
    'created_at': createdAt,
    'owner': {'id': 9, 'full_name': 'Aziza Karimova'},
  };
}

void main() {
  group('formatters', () {
    test('groups thousands with non-breaking spaces', () {
      expect(formatNumber(4000000), '4${_nbsp}000${_nbsp}000');
      expect(formatNumber(950), '950');
    });

    test('money in so\'m and dollars', () {
      expect(formatMoney(4000000, 'UZS'), "4${_nbsp}000${_nbsp}000${_nbsp}so'm");
      expect(formatMoney(350, 'USD'), '\$350');
    });

    test('short money', () {
      expect(formatMoneyShort(4000000, 'UZS'), "4${_nbsp}mln${_nbsp}so'm");
      expect(formatMoneyShort(4500000, 'UZS'), "4,5${_nbsp}mln${_nbsp}so'm");
      expect(formatMoneyShort(850000, 'UZS'), "850${_nbsp}ming${_nbsp}so'm");
    });

    test('phone display', () {
      expect(formatPhoneDisplay('+998901234567'), '+998 90 123 45 67');
      expect(formatPhoneDisplay(null), '');
    });

    test('Uzbek dates', () {
      final d = DateTime(2026, 10, 21, 15, 5); // a Wednesday
      expect(formatDayMonth(d), '21-oktabr');
      expect(formatTime(d), '15:05');
      expect(weekdayName(d), 'Chorshanba');
    });

    test('initials', () {
      expect(initials('Aziza Karimova'), 'AK');
      expect(initials('  '), '?');
    });
  });

  group('phone input', () {
    test('formats national digits as they are typed', () {
      final f = UzPhoneFormatter();
      final out = f.formatEditUpdate(TextEditingValue.empty, const TextEditingValue(text: '901234567'));
      expect(out.text, '90 123 45 67');
    });

    test('accepts a pasted full number', () {
      final f = UzPhoneFormatter();
      final out = f.formatEditUpdate(TextEditingValue.empty, const TextEditingValue(text: '+998 90 123 45 67'));
      expect(out.text, '90 123 45 67');
    });

    test('round trip to the API format', () {
      expect(fieldToPhone('90 123 45 67'), '+998901234567');
      expect(phoneToField('+998901234567'), '90 123 45 67');
      expect(fieldToPhone(''), '');
    });
  });

  group('validators', () {
    test('email and password', () {
      expect(Validators.email('aziza@mail.com'), isNull);
      expect(Validators.email('aziza@'), isNotNull);
      expect(Validators.password('12345'), isNotNull);
      expect(Validators.password('123456'), isNull);
    });

    test('phone must have nine digits', () {
      expect(Validators.phone('90 123 45 67'), isNull);
      expect(Validators.phone('90 123'), isNotNull);
      expect(Validators.optionalPhone(''), isNull);
    });

    test('numbers', () {
      expect(Validators.parseNumber('4 000 000'), 4000000);
      expect(Validators.parseNumber('4,5'), 4.5);
      expect(Validators.positiveNumber('0'), isNotNull);
    });
  });

  group('Property', () {
    test('parses a listing from the OLD backend (no new fields)', () {
      final p = Property.fromJson({
        'id': 5,
        'title': 'Eski e\'lon',
        'price': 3000000,
        'price_unit': 'Oy',
        'location': 'Chilonzor',
        'created_at': '2026-01-01T00:00:00',
        'owner': {'id': 2, 'full_name': 'Ali'},
      });
      expect(p.city, 'Toshkent');
      expect(p.currency, 'UZS');
      expect(p.isRented, isFalse);
      expect(p.priceUzs, 3000000);
      expect(p.hasMetro, isFalse);
      expect(p.insight, isNull);
    });

    test('reads the price insight', () {
      final json = _json();
      json['price_insight'] = {
        'median': 4200000,
        'currency': 'UZS',
        'diff_percent': -12,
        'sample_size': 7,
        'scope': 'tuman',
        'verdict': 'arzon',
      };
      final p = Property.fromJson(json);
      expect(p.insight, isNotNull);
      expect(p.insight!.headline, '12% arzon');
    });
  });

  group('FilterCriteria', () {
    final cheap = Property.fromJson(_json(id: 1, priceUzs: 2500000, price: 2500000, area: 35, bedrooms: 1));
    final usd = Property.fromJson(_json(id: 2, currency: 'USD', price: 500, priceUzs: 6000000, ownerType: 'Rieltor', metro: 'Novza'));
    final big = Property.fromJson(_json(id: 3, priceUzs: 9000000, price: 9000000, area: 120, bedrooms: 4, city: 'Samarqand', location: 'Registon', amenities: ['Mebel'], student: true));

    test('empty criteria matches everything', () {
      const c = FilterCriteria();
      expect([cheap, usd, big].every(c.matches), isTrue);
      expect(c.isActive, isFalse);
    });

    test('price range uses the so\'m equivalent (USD listings convert)', () {
      final c = const FilterCriteria().copyWith(price: const RangeValues(0, 5000000));
      expect(c.matches(cheap), isTrue);
      expect(c.matches(usd), isFalse); // 500 USD ~ 6 mln
    });

    test('top of the slider means no upper limit', () {
      final c = const FilterCriteria().copyWith(price: const RangeValues(0, FilterCriteria.priceMax));
      expect(c.matches(big), isTrue);
    });

    test('toggles', () {
      expect(const FilterCriteria(ownerOnly: true).matches(usd), isFalse);
      expect(const FilterCriteria(nearMetro: true).matches(usd), isTrue);
      expect(const FilterCriteria(nearMetro: true).matches(cheap), isFalse);
      expect(const FilterCriteria(studentOnly: true).matches(big), isTrue);
      expect(const FilterCriteria(minRooms: 3).matches(big), isTrue);
      expect(const FilterCriteria(minRooms: 3).matches(cheap), isFalse);
    });

    test('city, district and amenities', () {
      expect(const FilterCriteria(city: 'Samarqand').matches(big), isTrue);
      expect(const FilterCriteria(city: 'Samarqand').matches(cheap), isFalse);
      expect(const FilterCriteria(district: 'Yunusobod').matches(cheap), isTrue);
      expect(const FilterCriteria(amenities: {'Mebel'}).matches(big), isTrue);
      expect(const FilterCriteria(amenities: {'Mebel'}).matches(cheap), isFalse);
    });

    test('active count ignores the city chips', () {
      final c = const FilterCriteria(city: 'Toshkent', ownerOnly: true, minRooms: 2);
      expect(c.activeCount, 2);
      expect(c.clearedSheetFilters().activeCount, 0);
      expect(c.clearedSheetFilters().city, 'Toshkent');
    });

    test('sorting leaves the original list alone', () {
      final list = [big, cheap, usd];
      final sorted = sortProperties(list, SortMode.cheapest);
      expect(sorted.map((p) => p.id).toList(), [1, 2, 3]);
      expect(list.first.id, 3);
      expect(sortProperties(list, SortMode.priciest).first.id, 3);
    });
  });

  group('widgets', () {
    testWidgets('EmptyState shows its message and action', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: BTheme.light(),
          home: Scaffold(
            body: EmptyState(
              title: 'Hech narsa topilmadi',
              message: "Filtrlarni o'zgartirib ko'ring.",
              actionLabel: 'Tozalash',
              onAction: () => tapped = true,
            ),
          ),
        ),
      );
      expect(find.text('Hech narsa topilmadi'), findsOneWidget);
      await tester.tap(find.text('Tozalash'));
      expect(tapped, isTrue);
    });
  });
}
