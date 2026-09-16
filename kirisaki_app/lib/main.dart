import 'package:flutter/material.dart';

import 'app.dart';
import 'core/network/proxy_settings_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ProxySettingsService.instance.load();
  runApp(const KirisakiApp());
}
