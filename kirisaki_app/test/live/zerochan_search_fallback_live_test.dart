import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:kirisaki_app/core/source/builtin_sources.dart';
import 'package:kirisaki_app/core/source/source_parse_service.dart';

void main() {
  test(
    'Zerochan search, paging and original through application service',
    () async {
      final service = SourceParseService();
      final client = http.Client();
      try {
        final source = BuiltinSources.all.firstWhere((s) => s.id == 'zerochan');
        final first = await service.search(source, keyword: 'NARUTO');
        expect(first.errorMessage, isNull);
        expect(first.items, isNotEmpty);
        await Future<void>.delayed(const Duration(seconds: 2));
        final second = await service.search(source, keyword: 'NARUTO', page: 2);
        expect(second.errorMessage, isNull);
        expect(second.items, isNotEmpty);
        expect(
          second.items.first.sourcePage,
          isNot(first.items.first.sourcePage),
        );
        final item = await service.resolveImage(first.items.first);
        expect(item.detailUrl, isNull);
        expect(item.imageUrl, contains('.full.'));
        for (final url in [item.thumbnailUrl!, item.imageUrl]) {
          final response = await client
              .get(Uri.parse(url))
              .timeout(const Duration(seconds: 30));
          expect(response.statusCode, 200, reason: url);
          expect(response.bodyBytes, isNotEmpty);
          expect(response.headers['content-type'], startsWith('image/'));
        }
      } finally {
        service.close();
        client.close();
      }
    },
    skip: !const bool.fromEnvironment('RUN_ZEROCHAN_FALLBACK_LIVE'),
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
