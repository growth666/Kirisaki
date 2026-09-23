import 'package:kirisaki_app/core/source/chinese_search_dictionary.dart';
import 'package:kirisaki_app/core/source/confirmed_tag_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

import 'dart:async';

import 'package:kirisaki_app/core/settings/settings_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:kirisaki_app/core/source/source_service.dart';
import 'package:kirisaki_app/core/source/source_parse_service.dart';
import 'package:kirisaki_app/features/preview/presentation/pages/image_preview_page.dart';
import 'package:kirisaki_app/features/search/presentation/pages/search_page.dart';

/// 按 Moebooru 真实结构编写的 fixture（与 BuiltinSources 的选择器对应）。
const String _moebooruFixture = '''
[{"id":101,"file_url":"https://safebooru.org/image/original/a1.jpg","preview_url":"https://safebooru.org/data/preview/a1.jpg","width":150,"height":100,"tags":"blue_sky cloud"},
{"id":102,"file_url":"https://safebooru.org/image/original/b2.jpg","preview_url":"https://safebooru.org/data/preview/b2.jpg","width":150,"height":150,"tags":"night"}]
''';

/// 空结果 fixture：列表容器存在但没有任何 post 节点（对应"没有更多"）。
const String _emptyFixture = '[]';

/// alcy.cc 推荐接口 fixture（实测响应结构：data 数组 + link 字段）。
const String _alcyFixture = '''
{"code":200,"category":"pc","count":2,
 "data":[
   {"id":1,"link":"https://tc.alcy.cc/a.webp"},
   {"id":2,"link":"https://tc.alcy.cc/b.webp"}
 ],
 "links":["https://tc.alcy.cc/a.webp","https://tc.alcy.cc/b.webp"]}
''';

/// 推荐流分页追加数据（c/d 两张）。
const String _alcyFixture2 = '''
{"code":200,"category":"pc","count":2,
 "data":[
   {"id":3,"link":"https://tc.alcy.cc/c.webp"},
   {"id":4,"link":"https://tc.alcy.cc/d.webp"}
 ],
 "links":["https://tc.alcy.cc/c.webp","https://tc.alcy.cc/d.webp"]}
''';

/// 8 张数据（回到顶部测试需要足够长的内容）。
const String _alcyMany = '''
{"code":200,"category":"pc","count":8,
 "data":[
   {"id":1,"link":"https://tc.alcy.cc/1.webp"},
   {"id":2,"link":"https://tc.alcy.cc/2.webp"},
   {"id":3,"link":"https://tc.alcy.cc/3.webp"},
   {"id":4,"link":"https://tc.alcy.cc/4.webp"},
   {"id":5,"link":"https://tc.alcy.cc/5.webp"},
   {"id":6,"link":"https://tc.alcy.cc/6.webp"},
   {"id":7,"link":"https://tc.alcy.cc/7.webp"},
   {"id":8,"link":"https://tc.alcy.cc/8.webp"}
 ],
 "links":["https://tc.alcy.cc/1.webp"]}
''';

/// 测试专用路由：'/' 挂注入 mock 服务的搜索页，'/preview' 挂预览页。
/// [autoLoadRecommend] 默认关闭以保持既有用例语义（新推荐流用例单独开启）。
GoRouter _testRouter(
  SourceParseService service, {
  bool autoLoadRecommend = false,
}) {
  return GoRouter(
    initialLocation: '/',
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (BuildContext context, GoRouterState state) => SearchPage(
          service: service,
          sourceService: SourceService(),
          autoLoadRecommend: autoLoadRecommend,
        ),
      ),
      GoRoute(
        path: '/preview',
        builder: (BuildContext context, GoRouterState state) =>
            ImagePreviewPage(imageUrl: state.uri.queryParameters['url']),
      ),
    ],
  );
}

void main() {
  for (final status in [200, 503]) {
    testWidgets(
      'Zerochan still searches when suggestions return $status without candidates',
      (tester) async {
        final requests = <Uri>[];
        final service = SourceParseService(
          client: MockClient((request) async {
            requests.add(request.url);
            if (request.url.path == '/suggest') {
              return http.Response('', status);
            }
            return http.Response('{"items":[]}', 200);
          }),
        );
        await tester.pumpWidget(
          MaterialApp.router(routerConfig: _testRouter(service)),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ChoiceChip, 'Zerochan'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(const Key('searchInput')), 'solo');
        await tester.tap(find.byIcon(Icons.arrow_forward));
        await tester.pumpAndSettle();
        expect(requests.map((uri) => uri.path), ['/suggest', '/solo']);
        expect(find.text('选择 Zerochan 标签'), findsNothing);
        expect(
          tester
              .widget<TextField>(find.byKey(const Key('searchInput')))
              .controller!
              .text,
          'solo',
        );
      },
    );
  }
  testWidgets(
    'Zerochan imported tag requires site candidate confirmation before search',
    (tester) async {
      final requests = <Uri>[];
      final service = SourceParseService(
        client: MockClient((request) async {
          requests.add(request.url);
          if (request.url.path == '/suggest') {
            return http.Response('Solo|Theme|-', 200);
          }
          return http.Response('{"items":[]}', 200);
        }),
      );
      await tester.pumpWidget(
        MaterialApp.router(routerConfig: _testRouter(service)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Zerochan'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('searchInput')), 'solo');
      await tester.tap(find.byIcon(Icons.arrow_forward));
      await tester.pumpAndSettle();
      expect(requests, hasLength(1));
      expect(requests.single.path, '/suggest');
      expect(find.text('选择 Zerochan 标签'), findsOneWidget);
      await tester.tap(find.text('Solo'));
      await tester.pumpAndSettle();
      expect(requests.last.path, '/Solo');
      requests.clear();
      await tester.enterText(find.byKey(const Key('searchInput')), 'solo');
      await tester.tap(find.byIcon(Icons.arrow_forward));
      await tester.pumpAndSettle();
      expect(requests.map((uri) => uri.path), ['/Solo']);
      expect(find.text('选择 Zerochan 标签'), findsNothing);
      await ConfirmedTagService().clear();
      await tester.enterText(find.byKey(const Key('searchInput')), 'solo');
      await tester.tap(find.byIcon(Icons.arrow_forward));
      await tester.pumpAndSettle();
      expect(find.text('选择 Zerochan 标签'), findsOneWidget);
      await tester.tap(find.text('Solo'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('searchInput')))
            .controller!
            .text,
        'Solo',
      );
    },
  );
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await ChineseSearchDictionary.load();
  });
  testWidgets(
    'mouse candidate click survives pointer-down and supersedes loading recommendation',
    (tester) async {
      final pending = Completer<http.Response>();
      final queries = <String?>[];
      final service = SourceParseService(
        client: MockClient((request) async {
          if (request.url.host == 't.alcy.cc') return pending.future;
          queries.add(request.url.queryParameters['tags']);
          return http.Response('[]', 200);
        }),
      );
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: _testRouter(service, autoLoadRecommend: true),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.enterText(find.byKey(const Key('searchInput')), '蕾姆');
      await tester.pump();
      final candidate = find.widgetWithText(ActionChip, '蕾姆 · Re:从零开始的异世界生活');
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: tester.getCenter(candidate));
      await mouse.down(tester.getCenter(candidate));
      await tester.pump(const Duration(milliseconds: 100));
      expect(candidate, findsOneWidget);
      await mouse.up();
      await tester.pumpAndSettle();
      expect(queries, ['rem_(re:zero)']);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('searchInput')))
            .controller!
            .text,
        'rem_(re:zero)',
      );
      pending.complete(http.Response(_alcyFixture, 200));
      await tester.pumpAndSettle();
      expect(find.byType(Card), findsNothing);
      await mouse.removePointer();
    },
  );
  testWidgets('输入部分中文名显示候选且点击才搜索', (tester) async {
    final queries = <String?>[];
    final service = SourceParseService(
      client: MockClient((request) async {
        queries.add(request.url.queryParameters['tags']);
        return http.Response('[]', 200);
      }),
    );
    await tester.pumpWidget(
      MaterialApp.router(routerConfig: _testRouter(service)),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('searchInput')), '中野');
    await tester.pumpAndSettle();
    expect(queries, isEmpty);
    final candidate = find.widgetWithText(ActionChip, '中野三玖 · 五等分的新娘');
    expect(candidate, findsOneWidget);
    await tester.ensureVisible(candidate);
    await tester.pumpAndSettle();
    await tester.tap(candidate);
    await tester.pumpAndSettle();
    expect(queries, ['nakano_miku']);
    expect(find.text('中文候选 · 左右滑动，点击搜索'), findsNothing);
    expect(find.text('中文搜索辅助'), findsNothing);
  });
  testWidgets('同名角色展示作品并按用户选择搜索', (tester) async {
    final queries = <String?>[];
    final service = SourceParseService(
      client: MockClient((request) async {
        queries.add(request.url.queryParameters['tags']);
        return http.Response('[]', 200);
      }),
    );
    await tester.pumpWidget(
      MaterialApp.router(routerConfig: _testRouter(service)),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('searchInput')), '小樱');
    await tester.tap(find.byIcon(Icons.arrow_forward));
    await tester.pumpAndSettle();
    expect(queries, isEmpty);
    expect(find.text('春野樱 · 火影忍者'), findsOneWidget);
    expect(find.text('木之本樱 · 魔卡少女樱'), findsOneWidget);
    await tester.tap(find.text('kinomoto_sakura'));
    await tester.pumpAndSettle();
    expect(queries, ['kinomoto_sakura']);
  });
  testWidgets('中文候选确认后使用图源标签发起请求', (tester) async {
    final queries = <String?>[];
    final service = SourceParseService(
      client: MockClient((request) async {
        queries.add(request.url.queryParameters['tags']);
        return http.Response('[]', 200);
      }),
    );
    await tester.pumpWidget(
      MaterialApp.router(routerConfig: _testRouter(service)),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('searchInput')), '蕾姆');
    await tester.tap(find.byIcon(Icons.arrow_forward));
    await tester.pumpAndSettle();
    expect(queries, isEmpty);
    expect(find.text('蕾姆 · Re:从零开始的异世界生活'), findsOneWidget);
    await tester.tap(find.text('rem_(re:zero)'));
    await tester.pumpAndSettle();
    expect(queries, ['rem_(re:zero)']);
  });

  testWidgets('未收录中文可取消或显式原词搜索', (tester) async {
    final queries = <String?>[];
    final service = SourceParseService(
      client: MockClient((request) async {
        queries.add(request.url.queryParameters['tags']);
        return http.Response('[]', 200);
      }),
    );
    await tester.pumpWidget(
      MaterialApp.router(routerConfig: _testRouter(service)),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('searchInput')), '未收录人物');
    await tester.tap(find.byIcon(Icons.arrow_forward));
    await tester.pumpAndSettle();
    await tester.tap(find.text('返回修改'));
    await tester.pumpAndSettle();
    expect(queries, isEmpty);
    await tester.tap(find.byIcon(Icons.arrow_forward));
    await tester.pumpAndSettle();
    await tester.tap(find.text('直接搜索原词'));
    await tester.pumpAndSettle();
    expect(queries, ['未收录人物']);
  });
  testWidgets('内容切换重新请求并丢弃旧结果', (tester) async {
    final settings = SettingsService.instance;
    await settings.setShowAdultContent(false);
    final old = Completer<http.Response>();
    var calls = 0;
    final service = SourceParseService(
      client: MockClient((request) async {
        calls++;
        if (calls == 1) return old.future;
        return http.Response('[]', 200);
      }),
    );
    await tester.pumpWidget(
      MaterialApp.router(routerConfig: _testRouter(service)),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('searchInput')), 'sky');
    await tester.tap(find.byIcon(Icons.arrow_forward));
    await tester.pump();
    await settings.setShowAdultContent(true);
    await tester.pumpAndSettle();
    expect(calls, 2);
    old.complete(http.Response(_moebooruFixture, 200));
    await tester.pumpAndSettle();
    expect(find.byType(Card), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await settings.setShowAdultContent(false);
  });
  testWidgets('推荐失败后重试仍请求推荐源', (tester) async {
    var calls = 0;
    final service = SourceParseService(
      client: MockClient((request) async {
        expect(request.url.host, 't.alcy.cc');
        calls++;
        return http.Response(
          calls == 1 ? '' : _alcyFixture,
          calls == 1 ? 503 : 200,
        );
      }),
    );
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: _testRouter(service, autoLoadRecommend: true),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('503'), findsOneWidget);
    expect(find.text('没有找到相关图片，换个关键词试试'), findsNothing);
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.byType(Card), findsNWidgets(2));
  });

  testWidgets('分页失败保留图片并重试同一页', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 350));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final pages = <String?>[];
    final service = SourceParseService(
      client: MockClient((request) async {
        pages.add(request.url.queryParameters['pid']);
        return http.Response(
          pages.length == 2 ? '' : _moebooruFixture,
          pages.length == 2 ? 429 : 200,
        );
      }),
    );
    await tester.pumpWidget(
      MaterialApp.router(routerConfig: _testRouter(service)),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('searchInput')), 'sky');
    await tester.tap(find.byIcon(Icons.arrow_forward));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(find.textContaining('429'), findsOneWidget);
    expect(find.text('没有更多了'), findsNothing);
    expect(find.byType(Card), findsNWidgets(2));
    await tester.ensureVisible(find.text('重试加载更多'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('重试加载更多'));
    await tester.pumpAndSettle();
    expect(pages.take(3), ['0', '1', '1']);
  });

  testWidgets('Zerochan rem candidate searches its full name', (tester) async {
    final service = SourceParseService(
      client: MockClient((request) async {
        if (!request.url.hasQuery) {
          return http.Response(
            '<ul id="children-grid"><a class="thumb" href="/Rem+%28Re%3AZero%29"></a></ul>',
            200,
          );
        }
        if (request.url.path == '/rem') return http.Response('{}', 200);
        expect(Uri.decodeComponent(request.url.path), '/Rem (Re:Zero)');
        return http.Response(
          '{"items":[{"id":10,"tag":"Rem (Re:Zero)"}]}',
          200,
        );
      }),
    );
    final router = _testRouter(service);
    addTearDown(router.dispose);
    addTearDown(service.close);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Zerochan'));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('searchInput')), 'rem');
    await tester.tap(find.byIcon(Icons.arrow_forward));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ActionChip, 'Rem (Re:Zero)'));
    await tester.pumpAndSettle();
    expect(find.byType(Card), findsOneWidget);
  });
  testWidgets('Danbooru rem candidate is clickable and submits exact tag', (
    tester,
  ) async {
    final queries = <String>[];
    final service = SourceParseService(
      client: MockClient((request) async {
        if (request.url.path == '/tags.json') {
          return http.Response('[{"name":"rem_(re:zero)","category":4}]', 200);
        }
        final query = request.url.queryParameters['tags']!;
        queries.add(query);
        return http.Response(query == 'rem' ? '[]' : _moebooruFixture, 200);
      }),
    );
    final router = _testRouter(service);
    addTearDown(router.dispose);
    addTearDown(service.close);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Danbooru (Safe)'));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('searchInput')), 'rem');
    await tester.tap(find.byIcon(Icons.arrow_forward));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ActionChip, 'rem_(re:zero)'));
    await tester.pumpAndSettle();
    expect(queries, ['rem', 'rem_(re:zero)']);
    expect(find.byType(Card), findsNWidgets(2));
  });
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });
  testWidgets('初始提示展示', (WidgetTester tester) async {
    final SourceParseService service = SourceParseService(
      client: MockClient(
        (http.Request request) async => http.Response('', 200),
      ),
    );
    await tester.pumpWidget(
      MaterialApp.router(routerConfig: _testRouter(service)),
    );
    await tester.pump();

    expect(find.text('输入关键词，来点美图(๑•̀ㅂ•́)و✧  '), findsOneWidget);
  });

  testWidgets('搜索后展示瀑布流卡片，点击跳转预览页', (WidgetTester tester) async {
    final SourceParseService service = SourceParseService(
      client: MockClient((http.Request request) async {
        await Future<void>.delayed(const Duration(milliseconds: 300));
        return http.Response(_moebooruFixture, 200);
      }),
    );
    await tester.pumpWidget(
      MaterialApp.router(routerConfig: _testRouter(service)),
    );
    await tester.pump();

    await tester.enterText(find.byKey(const Key('searchInput')), 'blue_sky');
    await tester.tap(find.byIcon(Icons.arrow_forward));
    await tester.pump();

    // 加载中：展示加载动画。
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    // 瀑布流卡片：两张卡片、标签文本可见。
    expect(find.byType(Card), findsNWidgets(2));
    expect(find.text('#blue_sky'), findsNothing);
    expect(find.text('#night'), findsNothing);

    // 点击第一张卡片跳转预览页。
    await tester.tap(find.byType(Card).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('图片预览'), findsOneWidget);
    expect(find.textContaining('/image/original/a1.jpg'), findsOneWidget);
  });

  for (final submitWithKeyboard in [false, true]) {
    testWidgets('搜索收起键盘且预览返回不恢复输入焦点：keyboard=$submitWithKeyboard', (
      WidgetTester tester,
    ) async {
      final service = SourceParseService(
        client: MockClient((_) async => http.Response(_moebooruFixture, 200)),
      );
      final router = _testRouter(service);
      addTearDown(router.dispose);
      addTearDown(service.close);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      final input = find.byKey(const Key('searchInput'));
      await tester.enterText(input, 'blue_sky');
      if (submitWithKeyboard) {
        await tester.testTextInput.receiveAction(TextInputAction.search);
      } else {
        await tester.tap(find.byIcon(Icons.arrow_forward));
      }
      await tester.pumpAndSettle();
      final editable = tester.state<EditableTextState>(
        find.descendant(of: input, matching: find.byType(EditableText)),
      );
      expect(editable.widget.focusNode.hasFocus, isFalse);
      expect(tester.testTextInput.isVisible, isFalse);

      // Re-focus while results are visible, then repeat navigation to catch
      // the route restoring a previously focused input on subsequent visits.
      for (var visit = 0; visit < 2; visit++) {
        await tester.showKeyboard(input);
        expect(editable.widget.focusNode.hasFocus, isTrue);
        await tester.tap(find.byType(Card).first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.text('图片预览'), findsOneWidget);
        router.pop();
        await tester.pumpAndSettle();
        expect(editable.widget.focusNode.hasFocus, isFalse);
        expect(tester.testTextInput.isVisible, isFalse);
        expect(tester.widget<TextField>(input).controller!.text, 'blue_sky');
      }
      await tester.showKeyboard(input);
      expect(editable.widget.focusNode.hasFocus, isTrue);
      expect(tester.testTextInput.isVisible, isTrue);
    });
  }

  testWidgets('空结果显示空态提示', (WidgetTester tester) async {
    final SourceParseService service = SourceParseService(
      client: MockClient(
        (http.Request request) async => http.Response(_emptyFixture, 200),
      ),
    );
    await tester.pumpWidget(
      MaterialApp.router(routerConfig: _testRouter(service)),
    );
    await tester.pump();

    await tester.enterText(find.byKey(const Key('searchInput')), 'none');
    await tester.tap(find.byIcon(Icons.arrow_forward));
    await tester.pump();
    await tester.pump();

    expect(find.text('没有找到相关图片，换个关键词试试'), findsOneWidget);
  });

  testWidgets('网络异常显示错误态与重试按钮', (WidgetTester tester) async {
    final SourceParseService service = SourceParseService(
      client: MockClient(
        (http.Request request) async =>
            throw http.ClientException('network down'),
      ),
    );
    await tester.pumpWidget(
      MaterialApp.router(routerConfig: _testRouter(service)),
    );
    await tester.pump();

    await tester.enterText(find.byKey(const Key('searchInput')), 'test');
    await tester.tap(find.byIcon(Icons.arrow_forward));
    await tester.pump();
    await tester.pump();

    expect(find.text('网络连接失败，请检查网络'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
  });

  testWidgets('上拉分页：第二页为空时显示"没有更多了"', (WidgetTester tester) async {
    // 缩小测试视口，保证内容溢出可滚动，滚动触底才能触发分页监听。
    await tester.binding.setSurfaceSize(const Size(400, 250));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final SourceParseService service = SourceParseService(
      client: MockClient((http.Request request) async {
        final int page =
            int.parse(request.url.queryParameters['pid'] ?? '0') + 1;
        return http.Response(page == 1 ? _moebooruFixture : _emptyFixture, 200);
      }),
    );
    await tester.pumpWidget(
      MaterialApp.router(routerConfig: _testRouter(service)),
    );
    await tester.pump();

    await tester.enterText(find.byKey(const Key('searchInput')), 'blue_sky');
    await tester.tap(find.byIcon(Icons.arrow_forward));
    await tester.pump();
    await tester.pump();

    expect(find.byType(Card), findsNWidgets(2));

    // 上拉触底触发 _loadMore → 第二页空结果 → hasMore=false。
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.text('没有更多了'), findsOneWidget);
  });

  testWidgets('连点搜索按钮只发起一次请求（请求锁）', (WidgetTester tester) async {
    int pageOneRequests = 0;
    final SourceParseService service = SourceParseService(
      client: MockClient((http.Request request) async {
        final int page =
            int.parse(request.url.queryParameters['pid'] ?? '0') + 1;
        if (page == 1) {
          pageOneRequests++;
        }
        await Future<void>.delayed(const Duration(milliseconds: 300));
        return http.Response(page == 1 ? _moebooruFixture : _emptyFixture, 200);
      }),
    );
    await tester.pumpWidget(
      MaterialApp.router(routerConfig: _testRouter(service)),
    );
    await tester.pump();

    await tester.enterText(find.byKey(const Key('searchInput')), 'blue_sky');
    await tester.tap(find.byIcon(Icons.arrow_forward));
    await tester.pump(); // 进入加载态，按钮已禁用

    // 第二击：按钮禁用，不应再发起首页请求。
    await tester.tap(find.byIcon(Icons.arrow_forward), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    expect(pageOneRequests, 1);
    // 排空可能的分页请求计时器，避免测试结束时有遗留 Timer。
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
  });

  testWidgets('切换图源清空列表回到初始提示', (WidgetTester tester) async {
    final SourceParseService service = SourceParseService(
      client: MockClient((http.Request request) async {
        await Future<void>.delayed(const Duration(milliseconds: 300));
        return http.Response(_moebooruFixture, 200);
      }),
    );
    await tester.pumpWidget(
      MaterialApp.router(routerConfig: _testRouter(service)),
    );
    await tester.pump();

    await tester.enterText(find.byKey(const Key('searchInput')), 'blue_sky');
    await tester.tap(find.byIcon(Icons.arrow_forward));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    expect(find.byType(Card), findsNWidgets(2));

    // 通过唯一的图源切换栏选择图源。
    await tester.tap(find.widgetWithText(ChoiceChip, 'Danbooru (Safe)'));
    await tester.pumpAndSettle();

    // 切换图源：列表清空、回到初始提示。
    expect(find.byType(Card), findsNothing);
    expect(find.text('输入关键词，来点美图(๑•̀ㅂ•́)و✧  '), findsOneWidget);
  });

  testWidgets('默认自动加载推荐流（无需关键词）', (WidgetTester tester) async {
    final SourceParseService service = SourceParseService(
      client: MockClient((http.Request request) async {
        expect(request.url.queryParameters['pc'], '18'); // perPage → pc 参数
        return http.Response(_alcyFixture, 200);
      }),
    );
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: _testRouter(service, autoLoadRecommend: true),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(Card), findsNWidgets(2));
  });

  testWidgets('推荐流上拉分页追加新图', (WidgetTester tester) async {
    // 窄视口保证内容溢出可滚动。
    await tester.binding.setSurfaceSize(const Size(400, 300));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    int requestCount = 0;
    final SourceParseService service = SourceParseService(
      client: MockClient((http.Request request) async {
        requestCount++;
        // 第一页 2 张，后续每次追加 2 张新图（随机接口"下滑更新"语义）。
        return http.Response(
          requestCount == 1 ? _alcyFixture : _alcyFixture2,
          200,
        );
      }),
    );
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: _testRouter(service, autoLoadRecommend: true),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(Card), findsNWidgets(2));

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
    await tester.pump();
    await tester.pump();
    await tester.pump();

    final int cards = tester.widgetList(find.byType(Card)).length;
    expect(cards, greaterThanOrEqualTo(4)); // 分页追加成功
  });

  testWidgets('点击分类 chip 切换选中图源', (WidgetTester tester) async {
    final SourceParseService service = SourceParseService(
      client: MockClient(
        (http.Request request) async => http.Response('', 200),
      ),
    );
    await tester.pumpWidget(
      MaterialApp.router(routerConfig: _testRouter(service)),
    );
    await tester.pump();

    // 初始：默认图源 yande.re 的 chip 选中。
    final ChoiceChip yandeChip = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, 'Safebooru'),
    );
    expect(yandeChip.selected, isTrue);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Danbooru (Safe)'));
    await tester.pump();

    final ChoiceChip konachanChip = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, 'Danbooru (Safe)'),
    );
    expect(konachanChip.selected, isTrue);

    final ChoiceChip yandeChipAfter = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, 'Safebooru'),
    );
    expect(yandeChipAfter.selected, isFalse);
  });

  testWidgets('下滑显示回到顶部按钮，点击回顶后隐藏', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 300));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final SourceParseService service = SourceParseService(
      client: MockClient((http.Request request) async {
        return http.Response(_alcyMany, 200);
      }),
    );
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: _testRouter(service, autoLoadRecommend: true),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(FloatingActionButton), findsNothing);

    // 下滑超过 600px 阈值。
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -700));
    await tester.pump();

    expect(find.byType(FloatingActionButton), findsOneWidget);

    // FAB 入场缩放动画期间命中判定与派发位置存在偏差（点击实际生效），
    // 关闭未命中警告避免噪音。
    await tester.tap(find.byType(FloatingActionButton), warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400)); // 回顶动画完成
    await tester.pump();

    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('从预览返回后列表不重建、滚动位置保留', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 300));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final SourceParseService service = SourceParseService(
      client: MockClient((http.Request request) async {
        return http.Response(_alcyMany, 200);
      }),
    );
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: _testRouter(service, autoLoadRecommend: true),
      ),
    );
    await tester.pump();
    await tester.pump();

    // 滚动一段距离。
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
    await tester.pump();

    final ScrollableState scrollable = tester.state<ScrollableState>(
      find.descendant(
        of: find.byType(CustomScrollView),
        matching: find.byType(Scrollable),
      ),
    );
    final double offsetBefore = scrollable.position.pixels;
    expect(offsetBefore, greaterThan(0));

    // 打开预览再返回。
    await tester.tap(find.byType(Card).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('图片预览'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // 返回后滚动位置保留（保活：列表未重建）。
    final ScrollableState after = tester.state<ScrollableState>(
      find.descendant(
        of: find.byType(CustomScrollView),
        matching: find.byType(Scrollable),
      ),
    );
    expect(after.position.pixels, offsetBefore);
    expect(identical(scrollable, after), isTrue);
  });
}
