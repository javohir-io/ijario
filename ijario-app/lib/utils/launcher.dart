import 'package:url_launcher/url_launcher.dart';

/// Opens the phone dialer. Returns false if the device can't.
Future<bool> openPhone(String phone) async {
  try {
    final cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');
    return await launchUrl(Uri(scheme: 'tel', path: cleaned));
  } catch (_) {
    return false;
  }
}

/// Opens a Telegram chat with @[username].
Future<bool> openTelegram(String username) async {
  try {
    final name = username.replaceFirst('@', '');
    return await launchUrl(
      Uri.parse('https://t.me/$name'),
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {
    return false;
  }
}
