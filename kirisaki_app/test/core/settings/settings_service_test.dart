import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:kirisaki_app/core/settings/settings_service.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test('主题模式持久化往返', () async {
    final SettingsService service = SettingsService();
    expect(service.themeMode, ThemeMode.system); // 默认跟随系统

    await service.setThemeMode(ThemeMode.dark);
    expect(service.themeMode, ThemeMode.dark);

    final SettingsService restarted = SettingsService();
    await restarted.load();
    expect(restarted.themeMode, ThemeMode.dark);
  });

  test('themeMode 变化触发通知', () async {
    final SettingsService service = SettingsService();
    int notified = 0;
    service.addListener(() => notified++);

    await service.setThemeMode(ThemeMode.light);
    expect(notified, 1);
  });
}
