import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kirisaki_app/core/source/builtin_sources.dart';
import 'package:kirisaki_app/core/source/source_parse_service.dart';
import 'package:kirisaki_app/core/source/zerochan_xml_parser.dart';
import 'package:kirisaki_app/core/source/content_safety.dart';
import 'package:kirisaki_app/core/source/moebooru_json_parser.dart';
import 'package:kirisaki_app/core/source/source_config.dart';

const rss = '''<rss xmlns:media="http://search.yahoo.com/mrss/"><channel>
<item><title>Character</title><link>http://www.zerochan.net/123</link>
<media:thumbnail url="https://s3.zerochan.net/123.avif"/>
<media:content url="https://s1.zerochan.net/123.jpg" width="1000" height="2000"/>
<media:keywords>Character, Long Hair</media:keywords><media:rating>safe</media:rating>
</item></channel></rss>''';

void main() {
  final source = BuiltinSources.all.firstWhere((s) => s.id == 'zerochan');
  for (final status in [200, 500, 502]) {
    test(
      'invalid JSON $status falls back preserving keyword and page',
      () async {
        final requests = <Uri>[];
        final service = SourceParseService(
          client: MockClient((request) async {
            requests.add(request.url);
            return request.url.queryParameters.containsKey('xml')
                ? http.Response(rss, 200)
                : http.Response('{broken', status);
          }),
        );
        final result = await service.search(
          source,
          keyword: 'Rem (Re:Zero)',
          page: 2,
        );
        expect(result.items, hasLength(1));
        expect(Uri.decodeComponent(requests.last.path), '/Rem (Re:Zero)');
        expect(requests.last.queryParameters['p'], '2');
        expect(requests.last.queryParameters['l'], '24');
        expect(requests.last.queryParameters.containsKey('json'), false);
        final item = result.items.single;
        expect(item.thumbnailUrl, 'https://s3.zerochan.net/123.avif');
        expect(item.detailUrl, 'https://www.zerochan.net/123?json');
        expect(item.imageUrl, isNot(item.previewUrl));
        expect(item.tags, ['Character', 'Long Hair']);
        expect(item.width, 1000);
      },
    );
  }
  for (final status in [403, 429]) {
    test('does not retry denial $status', () async {
      var calls = 0;
      final service = SourceParseService(
        client: MockClient((request) async {
          calls++;
          return http.Response('denied', status);
        }),
      );
      final result = await service.search(source, keyword: 'NARUTO');
      expect(result.errorMessage, contains('$status'));
      expect(calls, 1);
    });
  }
  test('rejects validation HTML and preserves content rating', () {
    expect(
      () => ZerochanXmlParser.parse('<html/>', Uri.parse(source.baseUrl)),
      throwsFormatException,
    );
    final data = ZerochanXmlParser.parse(
      rss.replaceAll('>safe<', '>adult<'),
      Uri.parse(source.baseUrl),
    );
    final items = MoebooruJsonParser.parse(
      '{"items":[{"id":123,"tag":"Character","rating":"adult"}]}',
      baseUri: Uri.parse(source.baseUrl),
      format: SourceJsonFormat.zerochan,
    );
    expect((data['items'] as List).single['rating'], 'adult');
    expect(isAdultImage(items.single), true);
  });
}
