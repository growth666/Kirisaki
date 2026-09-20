import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kirisaki_app/core/source/confirmed_tag_service.dart';
import 'package:kirisaki_app/features/settings/presentation/pages/settings_page.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  testWidgets('clearing confirmed tags requires confirmation', (tester) async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final service = ConfirmedTagService();
    await service.save('s', 'a', 'A');
    await tester.pumpWidget(const MaterialApp(home: SettingsPage()));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('已确认标签'), 200);
    await tester.tap(find.text('已确认标签'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(await service.lookup('s', 'a'), 'A');
    await tester.tap(find.text('已确认标签'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '清除'));
    await tester.pumpAndSettle();
    expect(await service.lookup('s', 'a'), isNull);
    expect(find.text('已确认标签已清除'), findsOneWidget);
  });
}
