import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:kirisaki_app/core/source/source_config.dart';
import 'package:kirisaki_app/core/source/source_parse_service.dart';

const SourceConfig _testConfig = SourceConfig(
  id: 'test',
  name: '测试图源',
  baseUrl: 'https://example.test',
  searchUrlTemplate: '/post?tags={keyword}&page={page}',
  extractRule: ExtractRule(
    listSelector: 'li.post',
    imageUrl: FieldRule(selector: 'a.directlink img', attribute: 'data-src'),
    thumbnailUrl: FieldRule(selector: 'a.thumb img', attribute: 'src'),
    width: FieldRule(selector: 'span.width', useText: true),
    height: FieldRule(selector: 'span.height', useText: true),
    sourcePage: FieldRule(selector: 'a.detail', attribute: 'href'),
  ),
);

const String _fixtureHtml = '''
<ul id="posts">
  <li class="post">
    <a class="thumb" href="/post/show/1"><img src="/thumbs/1.jpg"></a>
    <a class="directlink" href="/image/1.jpg"><img data-src="/image/1.jpg"></a>
    <a class="detail" href="/post/show/1"></a>
    <span class="width">1920</span>
    <span class="height">1080</span>
  </li>
  <li class="post">
    <a class="thumb" href="/post/show/2"><img src="/thumbs/2.jpg"></a>
  </li>
</ul>
''';

void main() {
  group('buildSearchUri', () {
    final SourceParseService service = SourceParseService();

    test('关键词 URL 编码与分页参数替换', () {
      final Uri uri = service.buildSearchUri(_testConfig, '初音 ミク', 3);
      expect(
        uri.toString(),
        'https://example.test/post'
        '?tags=%E5%88%9D%E9%9F%B3%20%E3%83%9F%E3%82%AF&page=3',
      );
    });

    test('绝对地址模板保持原样', () {
      const SourceConfig config = SourceConfig(
        id: 'abs',
        name: '绝对地址图源',
        baseUrl: 'https://example.test',
        searchUrlTemplate: 'https://cdn.test/search/{keyword}?p={page}',
        extractRule: ExtractRule(
          listSelector: '.post',
          imageUrl: FieldRule(attribute: 'src'),
        ),
      );
      expect(
        service.buildSearchUri(config, 'a b', 2).toString(),
        'https://cdn.test/search/a%20b?p=2',
      );
    });
  });

  group('buildProxyUri', () {
    test('拼接 CORS 代理前缀', () {
      final Uri uri = SourceParseService.buildProxyUri(
        Uri.parse('https://example.test/post?tags=a'),
      );
      expect(
        uri.toString(),
        'https://corsproxy.io/?url='
        '${Uri.encodeComponent('https://example.test/post?tags=a')}',
      );
    });
  });

  group('search 成功路径', () {
    test('解析 HTML 提取图片列表', () async {
      final SourceParseService service = SourceParseService(
        client: MockClient((http.Request request) async {
          return http.Response(_fixtureHtml, 200);
        }),
      );

      final result = await service.search(_testConfig, keyword: 'test');

      expect(result.isSuccess, isTrue);
      expect(result.errorMessage, isNull);
      expect(result.items, hasLength(1));
      final item = result.items.single;
      expect(item.imageUrl, 'https://example.test/image/1.jpg');
      expect(item.thumbnailUrl, 'https://example.test/thumbs/1.jpg');
      expect(item.sourcePage, 'https://example.test/post/show/1');
      expect(item.width, 1920);
      expect(item.height, 1080);
    });
  });

  group('search 失败路径', () {
    test('空关键词', () async {
      final SourceParseService service = SourceParseService(
        client: MockClient((http.Request request) async {
          fail('不应发起请求');
        }),
      );

      final result = await service.search(_testConfig, keyword: '  ');

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, '请输入搜索关键词');
    });

    test('网络超时', () async {
      final SourceParseService service = SourceParseService(
        client: MockClient((http.Request request) async {
          throw TimeoutException('mock timeout');
        }),
      );

      final result = await service.search(_testConfig, keyword: 'test');

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, '网络超时，请稍后重试');
    });

    test('网络连接失败', () async {
      final SourceParseService service = SourceParseService(
        client: MockClient((http.Request request) async {
          throw http.ClientException('mock network error');
        }),
      );

      final result = await service.search(_testConfig, keyword: 'test');

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, '网络连接失败，请检查网络');
    });

    test('服务器返回非 200', () async {
      final SourceParseService service = SourceParseService(
        client: MockClient((http.Request request) async {
          return http.Response('Internal Server Error', 500);
        }),
      );

      final result = await service.search(_testConfig, keyword: 'test');

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, '服务器响应异常（HTTP 500）');
    });

    test('解析结果为空列表', () async {
      final SourceParseService service = SourceParseService(
        client: MockClient((http.Request request) async {
          return http.Response('<ul id="posts"></ul>', 200);
        }),
      );

      final result = await service.search(_testConfig, keyword: 'test');

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, SourceParseService.noImagesMessage);
    });
  });

  group('tags 多值提取', () {
    // 按 Moebooru 真实结构编写的图源配置（与 BuiltinSources 同构）。
    // 注意：含 RegExp 的配置无法 const 构造，故用 final。
    final SourceConfig moebooruConfig = SourceConfig(
      id: 'moebooru',
      name: 'moebooru',
      baseUrl: 'https://example.test',
      searchUrlTemplate: '/post?tags={keyword}',
      extractRule: ExtractRule(
        listSelector: 'ul#post-list-posts > li',
        imageUrl: FieldRule(selector: 'a.directlink', attribute: 'href'),
        tags: FieldRule(
          selector: 'a.thumb img.preview',
          attribute: 'title',
          regex: RegExp(r'Tags:\s*(.*?)(?:\s*User:.*)?$'),
        ),
      ),
    );

    const String fixture = '''
<div id="post-list">
  <ul id="post-list-posts">
    <li id="p101">
      <a class="thumb" href="/post/show/101">
        <img src="/data/preview/a1.jpg" class="preview"
             alt="Rating: safe Score: 5 Tags: blue_sky cloud User: alice"
             title="Rating: safe Score: 5 Tags: blue_sky cloud User: alice"
             width="150" height="100">
      </a>
      <a class="directlink largeimg" href="/image/original/a1.jpg"></a>
    </li>
  </ul>
</div>
''';

    test('正则切出 title 中的 Tags 段并按空白拆分', () async {
      final SourceParseService service = SourceParseService(
        client: MockClient(
          (http.Request request) async => http.Response(fixture, 200),
        ),
      );

      final result = await service.search(moebooruConfig, keyword: 'x');

      expect(result.isSuccess, isTrue);
      expect(result.items.single.imageUrl,
          'https://example.test/image/original/a1.jpg');
      expect(result.items.single.tags, <String>['blue_sky', 'cloud']);
    });
  });

  group('HTTP 状态码文案', () {
    test('429 返回限流文案', () async {
      final SourceParseService service = SourceParseService(
        client: MockClient(
          (http.Request request) async =>
              http.Response('Too Many Requests', 429),
        ),
      );

      final result = await service.search(_testConfig, keyword: 'test');

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, '请求过于频繁，已被图源限流（429），请稍后再试');
    });

    test('404 返回页面不存在文案', () async {
      final SourceParseService service = SourceParseService(
        client: MockClient(
          (http.Request request) async => http.Response('Not Found', 404),
        ),
      );

      final result = await service.search(_testConfig, keyword: 'test');

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, '页面不存在（404），请检查图源地址配置');
    });
  });

  group('regex 容错', () {
    // 含 RegExp 的配置无法 const 构造，故用工厂函数。
    SourceConfig configWithTags() => SourceConfig(
          id: 'tolerant',
          name: 'tolerant',
          baseUrl: 'https://example.test',
          searchUrlTemplate: '/post?tags={keyword}',
          extractRule: ExtractRule(
            listSelector: 'ul#post-list-posts > li',
            imageUrl:
                const FieldRule(selector: 'a.directlink', attribute: 'href'),
            tags: FieldRule(
              selector: 'a.thumb img.preview',
              attribute: 'title',
              regex: RegExp(r'Tags:\s*(.*?)(?:\s*User:.*)?$'),
            ),
          ),
        );

    test('title 为空 → tags 为空数组，不崩溃', () async {
      final SourceParseService service = SourceParseService(
        client: MockClient(
          (http.Request request) async =>
              http.Response(_tagsFixture(''), 200, headers: _utf8Headers),
        ),
      );

      final result = await service.search(configWithTags(), keyword: 'x');

      expect(result.isSuccess, isTrue);
      expect(result.items.single.tags, isEmpty);
    });

    test('title 无 Tags: 段 → tags 为空数组', () async {
      final SourceParseService service = SourceParseService(
        client: MockClient(
          (http.Request request) async => http.Response(
            _tagsFixture('Rating: safe User: alice'),
            200,
            headers: _utf8Headers,
          ),
        ),
      );

      final result = await service.search(configWithTags(), keyword: 'x');

      expect(result.isSuccess, isTrue);
      expect(result.items.single.tags, isEmpty);
    });

    test('特殊字符标签正常切分，不崩溃', () async {
      final SourceParseService service = SourceParseService(
        client: MockClient(
          (http.Request request) async => http.Response(
            _tagsFixture('Tags: オリジナル 初音ミク a/b'),
            200,
            headers: _utf8Headers,
          ),
        ),
      );

      final result = await service.search(configWithTags(), keyword: 'x');

      expect(result.isSuccess, isTrue);
      expect(result.items.single.tags, <String>['オリジナル', '初音ミク', 'a/b']);
    });
  });

  group('buildSearchUri {limit}', () {
    final SourceParseService service = SourceParseService();

    test('perPage 非空时替换 {limit}', () {
      const SourceConfig config = SourceConfig(
        id: 'limit',
        name: 'limit',
        baseUrl: 'https://example.test',
        searchUrlTemplate: '/post?tags={keyword}&limit={limit}',
        perPage: 100,
        extractRule: ExtractRule(
          listSelector: 'li',
          imageUrl: FieldRule(attribute: 'src'),
        ),
      );

      expect(
        service.buildSearchUri(config, 'a', 1).toString(),
        'https://example.test/post?tags=a&limit=100',
      );
    });

    test('perPage 为空时 {limit} 替换为空字符串', () {
      const SourceConfig config = SourceConfig(
        id: 'limit',
        name: 'limit',
        baseUrl: 'https://example.test',
        searchUrlTemplate: '/post?tags={keyword}&limit={limit}',
        extractRule: ExtractRule(
          listSelector: 'li',
          imageUrl: FieldRule(attribute: 'src'),
        ),
      );

      expect(
        service.buildSearchUri(config, 'a', 1).toString(),
        'https://example.test/post?tags=a&limit=',
      );
    });
  });

  group('空关键词', () {
    test('空关键词不发起请求', () async {
      int requestCount = 0;
      final SourceParseService service = SourceParseService(
        client: MockClient((http.Request request) async {
          requestCount++;
          return http.Response('', 200);
        }),
      );

      final result = await service.search(_testConfig, keyword: '   ');

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, '请输入搜索关键词');
      expect(requestCount, 0);
    });
  });
}

/// 明确 UTF-8 的响应头：http.Response 默认按 latin1 编码 body，
/// 含非 ASCII 字符（如日文标签）的 fixture 必须携带 charset=utf-8。
const Map<String, String> _utf8Headers = <String, String>{
  'content-type': 'text/html; charset=utf-8',
};

/// 生成单 post 的 Moebooru 结构 fixture，title 可注入。
String _tagsFixture(String title) => '''
<div id="post-list">
  <ul id="post-list-posts">
    <li id="p1">
      <a class="thumb" href="/post/show/1">
        <img src="/t.jpg" class="preview" alt="$title" title="$title"
             width="150" height="100">
      </a>
      <a class="directlink" href="/i.jpg"></a>
    </li>
  </ul>
</div>
''';
