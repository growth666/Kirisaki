import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:kirisaki_app/core/source/custom_source_store.dart';
import 'package:kirisaki_app/core/source/source_config.dart';
import 'package:kirisaki_app/core/source/source_json_importer.dart';
import 'package:kirisaki_app/core/source/source_service.dart';

const String _validHtmlJson = '''
{
  "id": "custom_a",
  "name": "自定义A",
  "baseUrl": "https://a.test",
  "searchUrlTemplate": "/post?tags={keyword}&page={page}",
  "extractRule": {
    "listSelector": "li.post",
    "imageUrl": {"selector": "a.directlink", "attribute": "href"}
  },
  "perPage": 50,
  "enabled": true,
  "sourceType": "html"
}
''';

void main() {
  late SourceService service;
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    service = SourceService();
  });

  test('合法 JSON 解析成功并持久化，重启后可恢复', () async {
    final SourceJsonImporter importer = SourceJsonImporter(service: service);

    final SourceImportResult result = await importer.importAndSave(
      _validHtmlJson,
    );

    expect(result.isSuccess, isTrue);
    expect(result.config!.id, 'custom_a');
    expect(result.config!.perPage, 50);
    expect(result.config!.extractRule.listSelector, 'li.post');

    // 模拟 App 重启：新 store 从持久化读取到导入的图源。
    final CustomSourceStore restarted = CustomSourceStore();
    final List<SourceConfig> loaded = await restarted.load();
    expect(loaded, hasLength(1));
    expect(loaded.single.id, 'custom_a');
  });

  test('JSON 格式错误返回明确提示', () {
    final SourceJsonImporter importer = SourceJsonImporter();

    final SourceImportResult result = importer.parseAndValidate('bad{');

    expect(result.isSuccess, isFalse);
    expect(result.errorMessage, startsWith('JSON 格式错误'));
  });

  test('顶层非对象返回明确提示', () {
    final SourceJsonImporter importer = SourceJsonImporter();

    final SourceImportResult result = importer.parseAndValidate('[1,2]');

    expect(result.errorMessage, 'JSON 内容必须是图源配置对象');
  });

  test('字段缺失返回缺失字段名', () {
    final SourceJsonImporter importer = SourceJsonImporter();

    final SourceImportResult result = importer.parseAndValidate('{"id": "x"}');

    expect(result.isSuccess, isFalse);
    expect(result.errorMessage, '缺少必填字段：name');
  });

  test('extractRule 字段缺失返回明确提示', () {
    final SourceJsonImporter importer = SourceJsonImporter();

    final SourceImportResult result = importer.parseAndValidate('''
{"id":"x","name":"x","baseUrl":"https://x","searchUrlTemplate":"/s",
 "extractRule":{"listSelector":"li"}}
''');

    expect(result.errorMessage, '缺少必填字段：extractRule.imageUrl');
  });

  test('重复 id 导入被拒绝', () async {
    final SourceJsonImporter importer = SourceJsonImporter(service: service);

    expect((await importer.importAndSave(_validHtmlJson)).isSuccess, isTrue);
    final SourceImportResult second = await importer.importAndSave(
      _validHtmlJson,
    );

    expect(second.isSuccess, isFalse);
    expect(second.errorMessage, '图源 id 已存在：custom_a');
  });

  test('非法 sourceType 枚举返回明确提示', () {
    final SourceJsonImporter importer = SourceJsonImporter();

    final SourceImportResult result = importer.parseAndValidate(
      _validHtmlJson.replaceAll('"html"', '"xml"'),
    );

    expect(result.errorMessage, contains('sourceType 取值非法'));
  });

  test('perPage 非正整数返回明确提示', () {
    final SourceJsonImporter importer = SourceJsonImporter();

    final SourceImportResult result = importer.parseAndValidate(
      _validHtmlJson.replaceAll('50', '-3'),
    );

    expect(result.errorMessage, 'perPage 必须是正整数');
  });
}
