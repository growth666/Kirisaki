import 'package:flutter_test/flutter_test.dart';

import 'package:kirisaki_app/core/source/moebooru_json_parser.dart';

void main() {
  final Uri base = Uri.parse('https://example.test');

  test('正常映射 Moebooru post.json 数组', () {
    const String body = '''
[
  {
    "id": 101,
    "tags": "blue_sky cloud",
    "file_url": "https://files.example.test/image/a1.jpg",
    "preview_url": "https://assets.example.test/preview/a1.jpg",
    "sample_url": "https://files.example.test/sample/a1.jpg",
    "width": 1920,
    "height": 1080
  },
  {
    "id": 102,
    "tags": "night",
    "file_url": "https://files.example.test/image/b2.jpg",
    "preview_url": "https://assets.example.test/preview/b2.jpg",
    "width": 800,
    "height": 600
  }
]
''';
    final items = MoebooruJsonParser.parse(body, baseUri: base);

    expect(items, hasLength(2));
    expect(
      items.first.imageUrl,
      'https://files.example.test/image/a1.jpg',
    );
    expect(
      items.first.thumbnailUrl,
      'https://assets.example.test/preview/a1.jpg',
    );
    expect(
      items.first.previewUrl,
      'https://files.example.test/sample/a1.jpg',
    );
    expect(items.first.width, 1920);
    expect(items.first.height, 1080);
    expect(items.first.sourcePage, 'https://example.test/post/show/101');
    expect(items.first.tags, <String>['blue_sky', 'cloud']);
  });

  test('tags 为 null/空时返回空数组，不崩溃', () {
    const String body = '''
[{"id": 1, "tags": null, "file_url": "https://f/x.jpg"}]
''';
    final items = MoebooruJsonParser.parse(body, baseUri: base);

    expect(items.single.tags, isEmpty);
  });

  test('file_url 缺失时依次兜底 jpeg_url/sample_url，全缺跳过', () {
    const String body = '''
[
  {"id": 1, "tags": "", "jpeg_url": "https://f/j.jpg"},
  {"id": 2, "tags": "", "sample_url": "https://f/s.jpg"},
  {"id": 3, "tags": ""}
]
''';
    final items = MoebooruJsonParser.parse(body, baseUri: base);

    expect(items, hasLength(2));
    expect(items[0].imageUrl, 'https://f/j.jpg');
    expect(items[1].imageUrl, 'https://f/s.jpg');
  });

  test('兼容 {"posts": [...]} 包裹形式', () {
    const String body = '''
{"posts": [{"id": 7, "tags": "a", "file_url": "https://f/w.jpg"}]}
''';
    final items = MoebooruJsonParser.parse(body, baseUri: base);

    expect(items.single.sourcePage, 'https://example.test/post/show/7');
  });

  test('坏 JSON 抛 FormatException（由 service 复用"解析失败"文案）', () {
    expect(
      () => MoebooruJsonParser.parse('not-json{', baseUri: base),
      throwsFormatException,
    );
  });

  test('顶层结构非 post 列表抛 FormatException', () {
    expect(
      () => MoebooruJsonParser.parse('{"foo": 1}', baseUri: base),
      throwsFormatException,
    );
  });
}
