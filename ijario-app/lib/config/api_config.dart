/// Central place to point the app at your backend.
///
/// For local development, the default below is used automatically. For a
/// production build (e.g. deploying to Netlify), override it at build time
/// instead of editing this file:
///
///   flutter build web --release --dart-define=API_BASE_URL=https://your-backend.onrender.com
///
/// Local-dev defaults, if you don't pass --dart-define:
/// - Android emulator      -> http://10.0.2.2:8000   (emulator's alias for your host machine)
/// - iOS simulator         -> http://localhost:8000
/// - Flutter web / desktop -> http://localhost:8000
/// - Physical phone        -> http://<your-computer's-LAN-IP>:8000  (phone and computer must be on the same Wi-Fi)
class ApiConfig {
  ApiConfig._();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );
}
