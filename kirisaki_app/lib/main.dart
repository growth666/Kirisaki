import 'package:flutter/material.dart';

import 'app.dart';
import 'core/network/proxy_settings_service.dart';
import 'core/settings/settings_service.dart';
import 'core/settings/refresh_rate_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ProxySettingsService.instance.load();
  await SettingsService.instance.load();
  await RefreshRateService.apply(SettingsService.instance.refreshRateMode);
  runApp(const KirisakiApp());
}
