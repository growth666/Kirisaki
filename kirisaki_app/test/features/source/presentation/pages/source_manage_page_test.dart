import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:kirisaki_app/core/source/source_config.dart';
import 'package:kirisaki_app/core/source/source_parse_service.dart';
import 'package:kirisaki_app/core/source/source_service.dart';
import 'package:kirisaki_app/core/source/builtin_sources.dart';
import 'package:kirisaki_app/features/search/presentation/pages/search_page.dart';
import 'package:kirisaki_app/features/source/presentation/pages/source_manage_page.dart';

SourceConfig source() => const SourceConfig(
  id: 'custom',
  name: 'Custom',
  baseUrl: 'https://custom.test',
  searchUrlTemplate: '/?q={keyword}&page={page}',
  extractRule: ExtractRule(
    listSelector: 'img',
    imageUrl: FieldRule(attribute: 'src'),
  ),
);

void main() {
  late SourceService service;
  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    service = SourceService();
    await service.load();
  });

  testWidgets('management and search fit a narrow mobile viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await service.add(
      SourceConfig.fromJson({
        ...source().toJson(),
        'name': 'A very long custom source name',
      }),
    );
    await tester.pumpWidget(
      MaterialApp(home: SourceManagePage(service: service, customOnly: true)),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('导入图源'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(
      MaterialApp(
        home: SearchPage(sourceService: service, autoLoadRecommend: false),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'disabling all search sources leaves an in-flight recommendation intact',
    (tester) async {
      final pending = Completer<http.Response>();
      final parser = SourceParseService(
        client: MockClient((request) => pending.future),
      );
      final recommendBefore = jsonEncode(BuiltinSources.recommend.toJson());
      await tester.pumpWidget(
        MaterialApp(
          home: SearchPage(service: parser, sourceService: service),
        ),
      );
      await tester.pump();
      for (final s in service.all) {
        await service.setEnabled(s.id, false);
      }
      pending.complete(
        http.Response(
          '{"data":[{"link":"https://example.test/recommend.jpg"}]}',
          200,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Card), findsOneWidget);
      expect(find.text('暂无启用的搜索图源'), findsOneWidget);
      expect(jsonEncode(BuiltinSources.recommend.toJson()), recommendBefore);
    },
  );

  testWidgets('import, fixed ID edit, toggle and confirmed deletion', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: SourceManagePage(service: service, customOnly: true)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('导入图源'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('sourceJsonInput')),
      jsonEncode(source().toJson()),
    );
    await tester.tap(find.text('导入'));
    await tester.pumpAndSettle();
    expect(find.text('Custom'), findsOneWidget);
    await tester.tap(find.byTooltip('图源操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('编辑'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('sourceJsonInput')))
          .controller!
          .text,
      contains('custom'),
    );
    await tester.enterText(
      find.byKey(const Key('sourceJsonInput')),
      jsonEncode({...source().toJson(), 'id': 'changed'}),
    );
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.text('编辑时不能修改图源 id'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('sourceJsonInput')),
      jsonEncode({...source().toJson(), 'name': 'Edited'}),
    );
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.text('Edited'), findsOneWidget);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(service.custom.single.enabled, false);
    await tester.tap(find.byTooltip('图源操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '删除'));
    await tester.pumpAndSettle();
    expect(service.custom, isEmpty);
  });

  testWidgets(
    'new source is immediately searchable and disabled source discards pending result',
    (tester) async {
      for (final s in service.all) {
        await service.setEnabled(s.id, false);
      }
      final response = Completer<http.Response>();
      Uri? requested;
      final parser = SourceParseService(
        client: MockClient((request) {
          requested = request.url;
          return response.future;
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: SearchPage(
            service: parser,
            sourceService: service,
            autoLoadRecommend: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('暂无启用的搜索图源'), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (widget) => widget is IconButton && widget.tooltip == '搜索',
              ),
            )
            .onPressed,
        isNull,
      );
      await service.add(source());
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('searchInput')), 'sky');
      await tester.tap(find.byTooltip('搜索'));
      await tester.pump();
      expect(requested?.host, 'custom.test');
      await service.setEnabled('custom', false);
      await tester.pump();
      response.complete(http.Response('<img src="/old.jpg">', 200));
      await tester.pumpAndSettle();
      expect(find.byType(Card), findsNothing);
      expect(find.text('暂无启用的搜索图源'), findsOneWidget);
      expect(find.text('推荐'), findsOneWidget);
    },
  );

  testWidgets(
    'source edits invalidate pending searches and use updated configuration',
    (tester) async {
      for (final s in service.all) {
        await service.setEnabled(s.id, false);
      }
      await service.add(source());
      final response = Completer<http.Response>();
      final requests = <Uri>[];
      final parser = SourceParseService(
        client: MockClient((request) {
          requests.add(request.url);
          return requests.length == 1
              ? response.future
              : Future.value(http.Response('', 200));
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: SearchPage(
            service: parser,
            sourceService: service,
            autoLoadRecommend: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('searchInput')), 'sky');
      await tester.tap(find.byTooltip('搜索'));
      await tester.pump();
      await service.update(
        'custom',
        SourceConfig.fromJson({
          ...source().toJson(),
          'baseUrl': 'https://edited.test',
        }),
      );
      await tester.pump();
      response.complete(http.Response('<img src="/old.jpg">', 200));
      await tester.pumpAndSettle();
      expect(find.byType(Card), findsNothing);
      await tester.tap(find.byTooltip('搜索'));
      await tester.pumpAndSettle();
      expect(requests.last.host, 'edited.test');
    },
  );
}
