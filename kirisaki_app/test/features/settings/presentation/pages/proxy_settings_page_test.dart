import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:kirisaki_app/core/network/proxy_settings_service.dart';
import 'package:kirisaki_app/features/settings/presentation/pages/proxy_settings_page.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });
  testWidgets(
    'proxy drafts do not activate until valid host and port are saved',
    (tester) async {
      final service = ProxySettingsService();
      await tester.pumpWidget(
        MaterialApp(home: ProxySettingsPage(service: service)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Switch));
      await tester.pump();
      expect(service.enabled, false);
      await tester.tap(find.text('保存'));
      await tester.pump();
      expect(service.enabled, false);
      await tester.enterText(
        find.byKey(const Key('proxyHostInput')),
        '127.0.0.1',
      );
      await tester.enterText(find.byKey(const Key('proxyPortInput')), '7890');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(service.enabled, true);
      final restarted = ProxySettingsService();
      await restarted.load();
      expect(restarted.host, '127.0.0.1');
      expect(restarted.port, 7890);
    },
  );
}
