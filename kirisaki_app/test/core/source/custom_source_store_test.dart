import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:kirisaki_app/core/source/custom_source_store.dart';
import 'package:kirisaki_app/core/source/source_config.dart';

void main() {
  setUp(() {
    // 用官方内存实现替换平台通道，避免依赖真实设备存储。
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test('save→load 往返保留全部字段（HTML 图源）', () async {
    final CustomSourceStore store = CustomSourceStore();
    final SourceConfig config = SourceConfig(
      id: 'custom1',
      name: '自定义图源',
      baseUrl: 'https://custom.test',
      searchUrlTemplate: '/search?q={keyword}&page={page}',
      extractRule: ExtractRule(
        listSelector: '.post',
        imageUrl: const FieldRule(attribute: 'src'),
        tags: FieldRule(
          selector: 'a.tags',
          regex: RegExp(r'Tags:\s*(.*)'),
        ),
      ),
      perPage: 50,
      enabled: false,
      sourceType: SourceType.html,
    );

    await store.save(<SourceConfig>[config]);
    final List<SourceConfig> loaded = await store.load();

    expect(loaded, hasLength(1));
    final SourceConfig restored = loaded.single;
    expect(restored.id, 'custom1');
    expect(restored.name, '自定义图源');
    expect(restored.baseUrl, 'https://custom.test');
    expect(restored.searchUrlTemplate, '/search?q={keyword}&page={page}');
    expect(restored.extractRule.listSelector, '.post');
    expect(
      restored.extractRule.tags!.regex!.pattern,
      RegExp(r'Tags:\s*(.*)').pattern,
    );
    expect(restored.perPage, 50);
    expect(restored.enabled, isFalse);
    expect(restored.sourceType, SourceType.html);
  });

  test('JSON 图源往返（sourceType.json 与占位规则还原）', () async {
    final CustomSourceStore store = CustomSourceStore();
    final SourceConfig config = SourceConfig(
      id: 'json1',
      name: 'JSON 图源',
      baseUrl: 'https://json.test',
      searchUrlTemplate: '/post.json?tags={keyword}&limit={limit}',
      extractRule: const ExtractRule(
        listSelector: 'li',
        imageUrl: FieldRule(),
      ),
      sourceType: SourceType.json,
    );

    await store.save(<SourceConfig>[config]);
    final SourceConfig restored = (await store.load()).single;

    expect(restored.sourceType, SourceType.json);
    expect(restored.extractRule.listSelector, 'li');
    expect(restored.perPage, isNull);
  });

  test('无数据时返回空列表（内置图源不参与持久化）', () async {
    final CustomSourceStore store = CustomSourceStore();

    final List<SourceConfig> loaded = await store.load();

    expect(loaded, isEmpty);
  });

  test('损坏数据容错返回空列表', () async {
    final CustomSourceStore store = CustomSourceStore();
    await SharedPreferencesAsync().setString(
      CustomSourceStore.storageKey,
      'not-json{',
    );

    final List<SourceConfig> loaded = await store.load();

    expect(loaded, isEmpty);
  });
}
