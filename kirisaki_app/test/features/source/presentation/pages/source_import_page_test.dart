import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:kirisaki_app/core/source/custom_source_store.dart';
import 'package:kirisaki_app/core/source/source_json_importer.dart';
import 'package:kirisaki_app/features/source/presentation/pages/source_import_page.dart';

const String _validJson = '''
{
  "id": "ui_a",
  "name": "UI图源",
  "baseUrl": "https://ui.test",
  "searchUrlTemplate": "/post?tags={keyword}",
  "extractRule": {
    "listSelector": "li.post",
    "imageUrl": {"attribute": "src"}
  }
}
''';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('粘贴非法 JSON 显示错误文本且不崩溃', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: SourceImportPage()));
    await tester.pump();

    await tester.enterText(find.byKey(const Key('sourceJsonInput')), 'bad{');
    await tester.tap(find.text('导入'));
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('JSON 格式错误'), findsOneWidget);
    expect(find.byType(SourceImportPage), findsOneWidget); // 页面仍存活
  });

  testWidgets('合法 JSON 导入成功：持久化可读 + SnackBar + 返回上一页', (
    WidgetTester tester,
  ) async {
    final SourceJsonImporter importer = SourceJsonImporter(
      store: CustomSourceStore(),
    );
    final GoRouter router = GoRouter(
      initialLocation: '/back',
      routes: <RouteBase>[
        GoRoute(
          path: '/back',
          builder: (BuildContext context, GoRouterState state) =>
              const Scaffold(body: Text('返回页')),
        ),
        GoRoute(
          path: '/import',
          builder: (BuildContext context, GoRouterState state) =>
              SourceImportPage(importer: importer),
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    router.push('/import'); // 压栈后 pop 才合法
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('sourceJsonInput')),
      _validJson,
    );
    await tester.tap(find.text('导入'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // 成功：返回上一页 + SnackBar 提示。
    expect(find.text('返回页'), findsOneWidget);
    expect(find.textContaining('导入成功'), findsOneWidget);

    // 持久化：新 store 可读取导入的图源。
    final CustomSourceStore store = CustomSourceStore();
    final loaded = await store.load();
    expect(loaded, hasLength(1));
    expect(loaded.single.id, 'ui_a');
  });
}
