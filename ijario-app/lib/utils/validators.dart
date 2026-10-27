/// Form validators. Each returns an error message in Uzbek, or null if valid.
class Validators {
  Validators._();

  static String? required(String? value, [String message = "Bu maydonni to'ldiring"]) {
    if (value == null || value.trim().isEmpty) return message;
    return null;
  }

  static String? name(String? value) {
    if (value == null || value.trim().length < 2) return 'Ismingizni kiriting';
    return null;
  }

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Elektron pochtani kiriting';
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$').hasMatch(v);
    return ok ? null : "Elektron pochta noto'g'ri. Namuna: ism@mail.com";
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Parolni kiriting';
    if (value.length < 6) return "Parol kamida 6 ta belgidan iborat bo'lsin";
    return null;
  }

  /// The field holds the 9 national digits (formatted), e.g. "90 123 45 67".
  static String? phone(String? value) {
    final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return 'Telefon raqamini kiriting';
    if (digits.length != 9) return "Telefon raqamini to'liq kiriting";
    return null;
  }

  static String? optionalPhone(String? value) {
    final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return null;
    return digits.length == 9 ? null : "Telefon raqamini to'liq kiriting";
  }

  static String? optionalTelegram(String? value) {
    final v = (value ?? '').trim().replaceFirst(RegExp(r'^@'), '');
    if (v.isEmpty) return null;
    return RegExp(r'^[A-Za-z0-9_]{4,32}$').hasMatch(v)
        ? null
        : "Telegram nomi noto'g'ri. Namuna: @ijario";
  }

  static String? positiveNumber(String? value, [String message = "Musbat son kiriting"]) {
    final n = parseNumber(value);
    if (n == null || n <= 0) return message;
    return null;
  }

  /// Parses "4 000 000" / "4,5" / "350.5" into a double.
  static double? parseNumber(String? value) {
    if (value == null) return null;
    final cleaned = value.replaceAll(RegExp(r'[\s\u00A0]'), '').replaceAll(',', '.');
    return double.tryParse(cleaned);
  }
}
