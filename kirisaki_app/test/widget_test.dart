import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:kirisaki_app/app.dart';

void main() {
  testWidgets('启动后显示搜索页', (WidgetTester tester) async {
    await tester.pumpWidget(const KirisakiApp());
    await tester.pump();

    expect(find.text('输入关键词，搜索二次元图片'), findsOneWidget);
    expect(find.byKey(const Key('searchInput')), findsOneWidget);
  });

  testWidgets('可导航到图源管理页', (WidgetTester tester) async {
    await tester.pumpWidget(const KirisakiApp());
    await tester.pump();

    final GoRouter router =
        GoRouter.of(tester.element(find.byKey(const Key('searchInput'))));
    router.go('/sources');
    await tester.pumpAndSettle();

    expect(find.text('图源管理'), findsOneWidget);
    expect(find.text('图源管理功能开发中'), findsOneWidget);
  });
}
