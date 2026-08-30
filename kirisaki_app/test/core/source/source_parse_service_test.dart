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
      expect(result.errorMessage, '未解析到图片，图源规则可能已失效');
    });
  });
}
