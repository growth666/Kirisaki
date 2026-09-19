import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kirisaki_app/app.dart';
import 'package:kirisaki_app/core/router/app_router.dart';
import 'package:kirisaki_app/core/settings/settings_service.dart';
import 'package:kirisaki_app/features/profile/presentation/pages/content_display_page.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  testWidgets('profile opens content display before and after hot reload', (
    tester,
  ) async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    await tester.pumpWidget(const KirisakiApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pumpAndSettle();

    for (var visit = 0; visit < 2; visit++) {
      await tester.ensureVisible(find.text('内容显示'));
      await tester.tap(find.text('内容显示'));
      await tester.pumpAndSettle();
      expect(find.byType(ContentDisplayPage), findsOneWidget);
      final before = SettingsService.instance.showAdultContent;
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(SettingsService.instance.showAdultContent, !before);
      appRouter.pop();
      await tester.pumpAndSettle();
      expect(find.byType(ContentDisplayPage), findsNothing);
        tester.element(find.byType(KirisakiApp)).reassemble();
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
