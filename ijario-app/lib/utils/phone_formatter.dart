import 'package:flutter/services.dart';

/// Formats the 9 national digits of an Uzbek number as "90 123 45 67".
/// The "+998" part is shown by the field as a fixed prefix, so people never
/// have to type it (pasting a full "+998 …" number also works).
class UzPhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('998') && digits.length > 9) digits = digits.substring(3);
    if (digits.length > 9) digits = digits.substring(0, 9);

    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i == 2 || i == 5 || i == 7) buffer.write(' ');
      buffer.write(digits[i]);
    }
    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// "+998901234567" -> "90 123 45 67" (what goes into the field).
String phoneToField(String? phone) {
  final digits = (phone ?? '').replaceAll(RegExp(r'\D'), '');
  if (digits.length != 12 || !digits.startsWith('998')) return '';
  final d = digits.substring(3);
  return '${d.substring(0, 2)} ${d.substring(2, 5)} ${d.substring(5, 7)} ${d.substring(7, 9)}';
}

/// "90 123 45 67" -> "+998901234567" (what goes to the API).
String fieldToPhone(String field) {
  final digits = field.replaceAll(RegExp(r'\D'), '');
  return digits.isEmpty ? '' : '+998$digits';
}
