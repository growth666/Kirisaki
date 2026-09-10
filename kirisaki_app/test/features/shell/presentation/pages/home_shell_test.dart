import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:kirisaki_app/features/shell/presentation/pages/home_shell.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('三个 tab 与底部导航渲染，切换不重建页面', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeShell()));
    await tester.pump();

    // 主页（推荐流默认自动加载，PageView 只保留当前页附近）。
    expect(find.text('搜图'), findsOneWidget);
    expect(find.text('推荐'), findsWidgets);

    // 切到收藏 tab。
    await tester.tap(find.text('收藏'));
    await tester.pumpAndSettle();
    expect(find.text('我的收藏'), findsOneWidget);
    expect(find.text('暂无收藏'), findsOneWidget);

    // 切到我的 tab（数据概览 + 功能列表入口）。
    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();
    expect(find.text('收藏'), findsWidgets); // 概览统计项
    expect(find.text('浏览历史'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);

    // 切回主页 tab。
    await tester.tap(find.text('主页'));
    await tester.pumpAndSettle();
    expect(find.text('搜图'), findsOneWidget);
  });
}
