import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kirisaki_app/core/source/builtin_sources.dart';
import 'package:kirisaki_app/core/source/source_config.dart';
import 'package:kirisaki_app/core/source/source_parse_service.dart';

void main() {
  test('four official sources and separate unchanged recommendation', () {
    expect(BuiltinSources.all.map((s) => s.id), [
      'safebooru',
      'danbooru_safe',
      'zerochan',
      'tbib',
    ]);
    expect(BuiltinSources.recommend.baseUrl, 'https://t.alcy.cc');
    expect(BuiltinSources.recommend.searchUrlTemplate, '/json?pc={limit}');
    expect(BuiltinSources.recommend.useWebCorsProxy, false);
    expect(BuiltinSources.recommend.requiresKeyword, false);
    expect(BuiltinSources.recommend.jsonFormat, SourceJsonFormat.moebooru);
  });

  test('Gelbooru starts at zero; Danbooru and Zerochan start at one', () {
    final service = SourceParseService();
    addTearDown(service.close);
    for (final source in BuiltinSources.all) {
      final uri = service.buildSearchUri(source, 'blue sky', 1);
      final key = source.jsonFormat == SourceJsonFormat.gelbooru
          ? 'pid'
          : source.id == 'zerochan'
          ? 'p'
          : 'page';
      expect(
        uri.queryParameters[key],
        source.jsonFormat == SourceJsonFormat.gelbooru ? '0' : '1',
      );
      expect(
        service.buildSearchUri(source, 'blue sky', 2).queryParameters[key],
        source.jsonFormat == SourceJsonFormat.gelbooru ? '1' : '2',
      );
    }
  });

  test('Danbooru field mapping and correct detail URL', () async {
    final source = BuiltinSources.all[1];
    final service = SourceParseService(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode([
            {
              'id': 10,
              'file_url': 'https://cdn.test/full.jpg',
              'preview_file_url': 'https://cdn.test/thumb.jpg',
              'image_width': 1200,
              'image_height': 800,
              'tag_string': 'blue_sky cloud',
            },
          ]),
          200,
        ),
      ),
    );
    final result = await service.search(source, keyword: 'sky');
    final item = result.items.single;
    expect(item.sourcePage, 'https://safebooru.donmai.us/posts/10');
    expect(item.thumbnailUrl, 'https://cdn.test/thumb.jpg');
    expect(item.width, 1200);
    expect(item.tags, ['blue_sky', 'cloud']);
  });

  test('TBIB legacy fields resolve full image and JPEG thumbnail', () async {
    final service = SourceParseService(
      client: MockClient(
        (_) async => http.Response(
          '[{"id":10,"directory":5,"image":"abc.png","width":800,"height":600,"tags":"sky"}]',
          200,
        ),
      ),
    );
    final result = await service.search(BuiltinSources.all[3], keyword: 'sky');
    final item = result.items.single;
    expect(item.imageUrl, 'https://tbib.org/images/5/abc.png');
    expect(
      item.thumbnailUrl,
      'https://tbib.org/thumbnails/5/thumbnail_abc.jpg',
    );
    expect(
      item.sourcePage,
      'https://tbib.org/index.php?page=post&s=view&id=10',
    );
  });

  test(
    'Zerochan obtains original from detail endpoint without guessing extension',
    () async {
      final requests = <Uri>[];
      final service = SourceParseService(
        client: MockClient((r) async {
          requests.add(r.url);
          return http.Response(
            requests.length == 1
                ? '{"items":[{"id":10,"tag":"Blue Sky","tags":["Scenery"],"width":800,"height":600}]}'
                : '{"full":"https://static.zerochan.net/Blue.Sky.full.10.png","large":"https://s1.zerochan.net/Blue.Sky.600.10.jpg"}',
            200,
          );
        }),
      );
      final result = await service.search(
        BuiltinSources.all[2],
        keyword: 'Scenery',
      );
      expect(result.items.single.detailUrl, 'https://www.zerochan.net/10?json');
      final resolved = await service.resolveImage(result.items.single);
      expect(resolved.imageUrl, endsWith('.png'));
      expect(resolved.detailUrl, isNull);
      expect(resolved.tags, ['Scenery']);
      expect(requests.last.path, '/10');
    },
  );

  for (final status in [403, 422, 429]) {
    test('HTTP $status is an actionable failure', () async {
      final service = SourceParseService(
        client: MockClient((_) async => http.Response('', status)),
      );
      final result = await service.search(
        BuiltinSources.all.first,
        keyword: 'sky',
      );
      expect(result.isSuccess, false);
      expect(result.errorMessage, contains('$status'));
    });
  }
}
