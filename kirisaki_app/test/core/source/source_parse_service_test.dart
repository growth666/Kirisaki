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
  test(
    'Zerochan retries without qualifier and with reversed name, then caches',
    () async {
      final queries = <String>[];
      final service = SourceParseService(
        client: MockClient((request) async {
          final query = request.url.queryParameters['q']!;
          queries.add(query);
          return http.Response(
            query == 'Miku Hatsune' ? 'Hatsune Miku|Character|VOCALOID' : '',
            200,
          );
        }),
      );
      expect(
        await service.zerochanCandidates(
          _testConfig,
          'hatsune_miku_(vocaloid)',
        ),
        isEmpty,
      );
      queries.clear();
      expect(
        await service.zerochanCandidates(
          _testConfig,
          'Hatsune_Miku_(VOCALOID)',
        ),
        ['Hatsune Miku'],
      );
      expect(queries, [
        'Hatsune Miku (VOCALOID)',
        'Hatsune Miku',
        'Miku Hatsune',
      ]);
      await service.zerochanCandidates(_testConfig, 'Hatsune_Miku_(VOCALOID)');
      expect(queries, hasLength(3));
      expect(SourceParseService.zerochanSearchKeyword('rem_(re:zero)'), 'rem');
      expect(
        SourceParseService.zerochanSearchKeyword('long_character_name'),
        'long character name',
      );
      service.close();
    },
  );
  test(
    'Zerochan autocomplete parses official names and caches successful lookups',
    () async {
      var calls = 0;
      final service = SourceParseService(
        client: MockClient((request) async {
          calls++;
          expect(request.url.path, '/suggest');
          expect(request.url.queryParameters['q'], 'hatsune miku');
          return http.Response(
            'Hatsune Miku|Character|VOCALOID\nHatsune Miku|Character|VOCALOID\n<html>error</html>',
            200,
          );
        }),
      );
      expect(await service.zerochanCandidates(_testConfig, 'hatsune_miku'), [
        'Hatsune Miku',
      ]);
      expect(await service.zerochanCandidates(_testConfig, 'hatsune_miku'), [
        'Hatsune Miku',
      ]);
      expect(calls, 1);
      service.close();
    },
  );
  for (final target in ['https://other.test/path', '/original?json&p=1&l=2']) {
    test('Zerochan rejects unsafe or looping redirect: $target', () async {
      var calls = 0;
      final service = SourceParseService(
        client: MockClient((request) async {
          calls++;
          return http.Response('', 301, headers: {'location': target});
        }),
      );
      final config = SourceConfig.fromJson({
        ..._testConfig.toJson(),
        'baseUrl': 'https://www.zerochan.net',
        'sourceType': 'json',
        'jsonFormat': 'zerochan',
        'searchUrlTemplate': '/{keyword}?json&p={page}&l=2',
      });
      final result = await service.search(config, keyword: 'original');
      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('图源地址异常'));
      expect(calls, lessThanOrEqualTo(2));
      service.close();
    });
  }
  test('Zerochan redirect preserves API query, page and user agent', () async {
    final requests = <http.Request>[];
    final service = SourceParseService(
      client: MockClient((request) async {
        requests.add(request);
        expect(request.followRedirects, isFalse);
        expect(request.headers['User-Agent'], isNotEmpty);
        if (requests.length == 1) {
          return http.Response(
            '',
            301,
            headers: {'location': '/Cherry+Blossom'},
          );
        }
        expect(request.url.queryParameters['json'], '');
        expect(request.url.queryParameters['p'], '2');
        expect(request.url.path, '/Cherry+Blossom');
        return http.Response('{"items":[{"id":1,"tag":"Miku"}]}', 200);
      }),
    );
    final config = SourceConfig.fromJson({
      ..._testConfig.toJson(),
      'baseUrl': 'https://www.zerochan.net',
      'sourceType': 'json',
      'jsonFormat': 'zerochan',
      'searchUrlTemplate': '/{keyword}?json&p={page}&l=2',
    });
    final result = await service.search(
      config,
      keyword: 'Cherry Blossoms',
      page: 2,
    );
    expect(result.items, hasLength(1));
    expect(requests, hasLength(2));
    service.close();
  });
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
      expect(
        result.items.single.imageUrl,
        'https://example.test/image/original/a1.jpg',
      );
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
        imageUrl: const FieldRule(selector: 'a.directlink', attribute: 'href'),
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

  group('JSON 图源分流', () {
    // JSON 图源配置：extractRule 为占位，走 Moebooru post.json 解析。
    final SourceConfig jsonConfig = SourceConfig(
      id: 'json',
      name: 'json',
      baseUrl: 'https://example.test',
      searchUrlTemplate: '/post.json?tags={keyword}&page={page}',
      sourceType: SourceType.json,
      extractRule: const ExtractRule(listSelector: 'li', imageUrl: FieldRule()),
    );

    test('百度聚合图源字段映射（hoverUrl→原图、thumbnailUrl→缩略图）', () async {
      // 按实测响应结构编写的 fixture（与 BuiltinSources 百度配置同构）。
      const String baiduFixture = '''
{"code":"200","data":[
  {"oriTitle":"初音","hoverUrl":"https://img.baidu.com/original.jpg",
   "thumbnailUrl":"https://img.baidu.com/thumb.jpg","width":1000,"height":1778}
]}
''';
      const SourceConfig baiduConfig = SourceConfig(
        id: 'baidu',
        name: '百度图片',
        baseUrl: 'https://zj.v.api.aa1.cn',
        searchUrlTemplate: '/api/so-baidu-img/?msg={keyword}&page={page}',
        sourceType: SourceType.json,
        jsonListKey: 'data',
        jsonFieldMapping: <String, String>{
          'file_url': 'hoverUrl',
          'preview_url': 'thumbnailUrl',
        },
        extractRule: ExtractRule(listSelector: 'li', imageUrl: FieldRule()),
      );
      final SourceParseService service = SourceParseService(
        client: MockClient(
          (http.Request request) async =>
              http.Response(baiduFixture, 200, headers: _utf8Headers),
        ),
      );

      final result = await service.search(baiduConfig, keyword: '初音');

      expect(result.isSuccess, isTrue);
      expect(
        result.items.single.imageUrl,
        'https://img.baidu.com/original.jpg',
      );
      expect(
        result.items.single.thumbnailUrl,
        'https://img.baidu.com/thumb.jpg',
      );
      expect(result.items.single.width, 1000);
      expect(result.items.single.height, 1778);
      expect(result.items.single.tags, isEmpty);
    });

    const String jsonPosts = '''
[
  {"id": 1, "tags": "sky cloud",
   "file_url": "https://files.example.test/a.jpg",
   "preview_url": "https://files.example.test/a_preview.jpg",
   "width": 1920, "height": 1080}
]
''';

    test('JSON 图源请求 post.json 并成功解析', () async {
      final SourceParseService service = SourceParseService(
        client: MockClient((http.Request request) async {
          expect(request.url.path, '/post.json');
          return http.Response(jsonPosts, 200);
        }),
      );

      final result = await service.search(jsonConfig, keyword: 'sky');

      expect(result.isSuccess, isTrue);
      expect(result.items.single.tags, <String>['sky', 'cloud']);
      expect(
        result.items.single.sourcePage,
        'https://example.test/post/show/1',
      );
    });

    test('JSON 空结果复用 noImagesMessage（空态/没有更多）', () async {
      final SourceParseService service = SourceParseService(
        client: MockClient(
          (http.Request request) async => http.Response('[]', 200),
        ),
      );

      final result = await service.search(jsonConfig, keyword: 'none');

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, SourceParseService.noImagesMessage);
    });

    test('JSON 解析异常复用"解析失败"文案', () async {
      final SourceParseService service = SourceParseService(
        client: MockClient(
          (http.Request request) async => http.Response('bad{', 200),
        ),
      );

      final result = await service.search(jsonConfig, keyword: 'x');

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, startsWith('解析失败'));
    });
  });
}

/// 明确 UTF-8 的响应头：http.Response 默认按 latin1 编码 body，
/// 含非 ASCII 字符（如日文标签）的 fixture 必须携带 charset=utf-8。
const Map<String, String> _utf8Headers = <String, String>{
  'content-type': 'text/html; charset=utf-8',
};

/// 生成单 post 的 Moebooru 结构 fixture，title 可注入。
String _tagsFixture(String title) =>
    '''
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
