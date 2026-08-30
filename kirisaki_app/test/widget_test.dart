import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:kirisaki_app/app.dart';

void main() {
  testWidgets('启动后显示搜索页占位', (WidgetTester tester) async {
    await tester.pumpWidget(const KirisakiApp());
    await tester.pumpAndSettle();

    expect(find.text('搜索'), findsOneWidget);
    expect(find.text('图片搜索功能开发中'), findsOneWidget);
  });

  testWidgets('可导航到图源管理页', (WidgetTester tester) async {
    await tester.pumpWidget(const KirisakiApp());
    await tester.pumpAndSettle();

    final GoRouter router = GoRouter.of(tester.element(find.text('搜索')));
    router.go('/sources');
    await tester.pumpAndSettle();

    expect(find.text('图源管理'), findsOneWidget);
    expect(find.text('图源管理功能开发中'), findsOneWidget);
  });
}
