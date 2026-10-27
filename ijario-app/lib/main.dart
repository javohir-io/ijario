import 'package:flutter/material.dart';

import 'app.dart';
import 'services/api_client.dart';
import 'services/settings_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Best-effort warm-up ping, fired the moment the app launches: matters
  // most against a backend on a free-tier host that spins down when idle, so
  // it starts waking up before the person even reaches the sign-in button.
  ApiClient.instance.ping();

  await SettingsStore.instance.load();
  runApp(const IjarioApp());
}
