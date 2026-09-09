import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:kirisaki_app/core/source/source_config.dart';
import 'package:kirisaki_app/core/source/source_parse_service.dart';
import 'package:kirisaki_app/features/preview/presentation/pages/image_preview_page.dart';
import 'package:kirisaki_app/features/search/presentation/pages/search_page.dart';

/// 按 Moebooru 真实结构编写的 fixture（与 BuiltinSources 的选择器对应）。
const String _moebooruFixture = '''
<div id="post-list">
  <ul id="post-list-posts">
    <li id="p101" class="javascript-hide" style="width: 160px;">
      <div class="inner" style="width: 150px; height: 150px;">
        <a class="thumb" href="/post/show/101">
          <img src="/data/preview/a1.jpg" class="preview"
               alt="Rating: safe Score: 5 Tags: blue_sky cloud User: alice"
               title="Rating: safe Score: 5 Tags: blue_sky cloud User: alice"
               width="150" height="100">
        </a>
      </div>
      <a class="directlink largeimg" href="/image/original/a1.jpg"></a>
    </li>
    <li id="p102" class="javascript-hide" style="width: 160px;">
      <div class="inner" style="width: 150px; height: 150px;">
        <a class="thumb" href="/post/show/102">
          <img src="/data/preview/b2.jpg" class="preview"
               alt="Rating: safe Score: 3 Tags: night User: bob"
               title="Rating: safe Score: 3 Tags: night User: bob"
               width="150" height="150">
        </a>
      </div>
      <a class="directlink smallimg" href="/image/original/b2.jpg"></a>
    </li>
  </ul>
</div>
''';

/// 空结果 fixture：列表容器存在但没有任何 post 节点（对应"没有更多"）。
const String _emptyFixture = '''
<div id="post-list">
  <ul id="post-list-posts"></ul>
</div>
''';

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
GoRouter _testRouter(SourceParseService service,
    {bool autoLoadRecommend = false}) {
  return GoRouter(
    initialLocation: '/',
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (BuildContext context, GoRouterState state) => SearchPage(
          service: service,
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

    expect(find.text('输入关键词，搜索二次元图片'), findsOneWidget);
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
    expect(find.text('#blue_sky'), findsOneWidget);
    expect(find.text('#night'), findsOneWidget);

    // 点击第一张卡片跳转预览页。
    await tester.tap(find.byType(Card).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('图片预览'), findsOneWidget);
    expect(find.textContaining('/image/original/a1.jpg'), findsOneWidget);
  });

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
        final int page = int.parse(request.url.queryParameters['page'] ?? '1');
        return http.Response(
          page == 1 ? _moebooruFixture : _emptyFixture,
          200,
        );
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
        final int page = int.parse(request.url.queryParameters['page'] ?? '1');
        if (page == 1) {
          pageOneRequests++;
        }
        await Future<void>.delayed(const Duration(milliseconds: 300));
        return http.Response(
          page == 1 ? _moebooruFixture : _emptyFixture,
          200,
        );
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

    // 打开图源下拉并选择 konachan.net。
    // 分类栏新增了同名 chip；DropdownMenu 自身含字段与隐藏菜单项两处
    // 同名文本，用 descendant + first 定位字段内文本。
    await tester.tap(
      find
          .descendant(
            of: find.byType(DropdownMenu<SourceConfig>),
            matching: find.text('yande.re'),
          )
          .first,
    );
    await tester.pumpAndSettle();
    // 直接点击菜单项组件（last 为展开 overlay 中的可见项，
    // 隐藏测量层中的副本位于树序靠前）。
    await tester.tap(
      find.widgetWithText(MenuItemButton, 'konachan.net').last,
    );
    await tester.pumpAndSettle();

    // 切换图源：列表清空、回到初始提示。
    expect(find.byType(Card), findsNothing);
    expect(find.text('输入关键词，搜索二次元图片'), findsOneWidget);
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

  testWidgets('点击分类 chip 同步下拉框选中图源', (WidgetTester tester) async {
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
      find.widgetWithText(ChoiceChip, 'yande.re'),
    );
    expect(yandeChip.selected, isTrue);

    await tester.tap(find.widgetWithText(ChoiceChip, 'konachan.net'));
    await tester.pump();

    final ChoiceChip konachanChip = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, 'konachan.net'),
    );
    expect(konachanChip.selected, isTrue);

    final ChoiceChip yandeChipAfter = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, 'yande.re'),
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
}
