import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:kirisaki_app/app.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });
  testWidgets('启动后显示搜索页', (WidgetTester tester) async {
    await tester.pumpWidget(const KirisakiApp());
    await tester.pump();

    // 首页默认自动加载推荐流，初始提示已不存在；
    // 断言与加载状态无关的结构内容。
    expect(find.byKey(const Key('searchInput')), findsOneWidget);
    expect(find.text('推荐'), findsOneWidget);
    expect(find.byIcon(Icons.tune), findsOneWidget);
    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
  });

  testWidgets('可导航到图源管理页', (WidgetTester tester) async {
    await tester.pumpWidget(const KirisakiApp());
    await tester.pump();

    final GoRouter router = GoRouter.of(
      tester.element(find.byKey(const Key('searchInput'))),
    );
    router.go('/sources');
    await tester.pumpAndSettle();

    expect(find.text('图源管理'), findsOneWidget);
    expect(find.byType(Switch), findsWidgets);
    expect(find.byTooltip('导入图源'), findsOneWidget);
  });
}
