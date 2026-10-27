import '../models/property.dart';

const _nbsp = '\u00A0';

/// 4000000 -> "4 000 000" (non-breaking spaces so a price never wraps).
String formatNumber(num value) {
  final negative = value < 0;
  final digits = value.abs().round().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(_nbsp);
    buffer.write(digits[i]);
  }
  return '${negative ? '-' : ''}$buffer';
}

/// "4 000 000 so'm" or "$350".
String formatMoney(num price, String currency) {
  if (currency == 'USD') return '\$${formatNumber(price)}';
  return "${formatNumber(price)}${_nbsp}so'm";
}

/// Compact form for tight spaces: "4 mln so'm", "850 ming so'm", "$350".
String formatMoneyShort(num price, String currency) {
  if (currency == 'USD') return '\$${formatNumber(price)}';
  if (price >= 1000000) {
    final millions = price / 1000000;
    final text = millions == millions.roundToDouble()
        ? millions.round().toString()
        : millions.toStringAsFixed(1).replaceAll('.', ',');
    return "$text${_nbsp}mln${_nbsp}so'm";
  }
  if (price >= 1000) return "${(price / 1000).round()}${_nbsp}ming${_nbsp}so'm";
  return "${formatNumber(price)}${_nbsp}so'm";
}

String unitLabel(String priceUnit) => priceUnit == 'Kun' ? 'kun' : 'oy';

/// "4 mln so'm / oy"
String priceWithUnit(Property p, {bool short = true}) {
  final amount = short ? formatMoneyShort(p.price, p.currency) : formatMoney(p.price, p.currency);
  return '$amount / ${unitLabel(p.priceUnit)}';
}

const _months = [
  'yanvar', 'fevral', 'mart', 'aprel', 'may', 'iyun',
  'iyul', 'avgust', 'sentabr', 'oktabr', 'noyabr', 'dekabr',
];
const _weekdays = [
  'Dushanba', 'Seshanba', 'Chorshanba', 'Payshanba', 'Juma', 'Shanba', 'Yakshanba',
];
const _weekdaysShort = ['Du', 'Se', 'Cho', 'Pa', 'Ju', 'Sha', 'Ya'];

String weekdayName(DateTime d) => _weekdays[d.weekday - 1];
String weekdayShort(DateTime d) => _weekdaysShort[d.weekday - 1];

/// "21-oktabr"
String formatDayMonth(DateTime d) => '${d.day}-${_months[d.month - 1]}';

/// "15:00"
String formatTime(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// "Juma, 21-oktabr, 15:00"
String formatViewingTime(DateTime d) =>
    '${weekdayName(d)}, ${formatDayMonth(d)}, ${formatTime(d)}';

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Chat list stamp: today -> "15:42", this week -> "Juma", else "21-okt".
String formatChatStamp(DateTime d, {DateTime? now}) {
  final n = now ?? DateTime.now();
  if (isSameDay(d, n)) return formatTime(d);
  if (isSameDay(d, n.subtract(const Duration(days: 1)))) return 'Kecha';
  if (n.difference(d).inDays < 7) return weekdayName(d);
  return '${d.day}-${_months[d.month - 1].substring(0, 3)}';
}

/// "hozirgina", "5 daqiqa oldin", "3 soat oldin", "kecha", "21-oktabr".
String timeAgo(DateTime d, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final diff = n.difference(d);
  if (diff.inMinutes < 1) return 'hozirgina';
  if (diff.inMinutes < 60) return '${diff.inMinutes} daqiqa oldin';
  if (diff.inHours < 24 && isSameDay(d, n)) return '${diff.inHours} soat oldin';
  if (isSameDay(d, n.subtract(const Duration(days: 1)))) return 'kecha';
  if (diff.inDays < 7) return '${diff.inDays} kun oldin';
  return formatDayMonth(d);
}

/// "+998901234567" -> "+998 90 123 45 67". Anything else is returned as-is.
String formatPhoneDisplay(String? phone) {
  if (phone == null || phone.isEmpty) return '';
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  if (digits.length == 12 && digits.startsWith('998')) {
    return '+998 ${digits.substring(3, 5)} ${digits.substring(5, 8)} '
        '${digits.substring(8, 10)} ${digits.substring(10, 12)}';
  }
  return phone;
}

/// "Aziza Karimova" -> "AK"
String initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
}
