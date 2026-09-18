import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:kirisaki_app/core/download/image_downloader_io.dart';
import 'package:kirisaki_app/core/network/http_client_factory.dart';
import 'package:kirisaki_app/core/source/builtin_sources.dart';
import 'package:kirisaki_app/core/source/source_config.dart';
import 'package:kirisaki_app/core/source/source_parse_service.dart';

// Explicit opt-in: normal test runs never contact third-party sites.
void main() {
  const enabled = bool.fromEnvironment('RUN_SOURCE_LIVE');
  test(
    'live Zerochan rem disambiguation and naruto regression',
    () async {
      final service = SourceParseService();
      addTearDown(service.close);
      final source = BuiltinSources.all.firstWhere((s) => s.id == 'zerochan');
      final result = await service.search(source, keyword: 'rem');
      expect(result.suggestedTags, contains('Rem (Re:Zero)'));
      final first = await service.search(source, keyword: 'Rem (Re:Zero)');
      final second = await service.search(
        source,
        keyword: 'Rem (Re:Zero)',
        page: 2,
      );
      expect(first.items, isNotEmpty, reason: first.errorMessage);
      expect(second.items, isNotEmpty, reason: second.errorMessage);
      expect(second.items.first.imageUrl, isNot(first.items.first.imageUrl));
      final resolved = await service.resolveImage(first.items.first);
      expect(resolved.detailUrl, isNull);
      expect(Uri.parse(resolved.imageUrl).path, contains('.'));
      final naruto = await service.search(source, keyword: 'naruto');
      expect(naruto.items, isNotEmpty, reason: naruto.errorMessage);
    },
    skip: !enabled,
    timeout: const Timeout(Duration(minutes: 2)),
  );
  test(
    'live Danbooru rem suggestions and qualified search',
    () async {
      final service = SourceParseService();
      addTearDown(service.close);
      final source = BuiltinSources.all.firstWhere(
        (s) => s.id == 'danbooru_safe',
      );
      final result = await service.search(source, keyword: 'rem');
      expect(result.suggestedTags, contains('rem_(re:zero)'));
      final first = await service.search(source, keyword: 'rem_(re:zero)');
      final second = await service.search(
        source,
        keyword: 'rem_(re:zero)',
        page: 2,
      );
      expect(first.items, isNotEmpty, reason: first.errorMessage);
      expect(second.items, isNotEmpty, reason: second.errorMessage);
      expect(second.items.first.imageUrl, isNot(first.items.first.imageUrl));
    },
    skip: !enabled,
    timeout: const Timeout(Duration(minutes: 2)),
  );
  for (final builtin in BuiltinSources.all) {
    test(
      'live ${builtin.id}: two pages, thumbnail, full image and saved file',
      () async {
        final report = <String, Object?>{
          'source': builtin.id,
          'timeUtc': DateTime.now().toUtc().toIso8601String(),
          'platform': Platform.operatingSystem,
          'network': 'direct',
        };
        final folder = Directory('build/source-checks/${builtin.id}');
        await folder.create(recursive: true);
        final client = buildClient();
        final service = SourceParseService(client: client);
        try {
          final config = SourceConfig.fromJson({
            ...builtin.toJson(),
            'perPage': builtin.id == 'zerochan' ? 24 : 2,
          });
          final keyword = builtin.id == 'zerochan' ? 'Scenery' : 'scenery';
          final first = await service.search(config, keyword: keyword);
          expect(first.isSuccess, true, reason: first.errorMessage);
          report['firstPageCount'] = first.items.length;
          await Future<void>.delayed(const Duration(seconds: 1));
          final second = await service.search(
            config,
            keyword: keyword,
            page: 2,
          );
          expect(second.isSuccess, true, reason: second.errorMessage);
          expect(
            second.items
                .map((i) => i.imageUrl)
                .toSet()
                .difference(first.items.map((i) => i.imageUrl).toSet()),
            isNotEmpty,
          );
          report['secondPageCount'] = second.items.length;
          final item = await service.resolveImage(first.items.first);
          report['imageUrl'] = item.imageUrl;
          final thumb = await client
              .get(Uri.parse(item.thumbnailUrl!))
              .timeout(const Duration(seconds: 30));
          expect(thumb.statusCode, 200);
          final thumbCodec = await ui.instantiateImageCodec(thumb.bodyBytes);
          final thumbFrame = await thumbCodec.getNextFrame();
          report['thumbnailSize'] =
              '${thumbFrame.image.width}x${thumbFrame.image.height}';
          thumbFrame.image.dispose();
          thumbCodec.dispose();
          final extension = Uri.parse(item.imageUrl).pathSegments.last
              .split('.')
              .last;
          final filename = 'sample.$extension';
          final saved = await IoImageDownloadService(
            downloadDirOverride: folder,
            client: client,
          ).saveImage(imageUrl: item.imageUrl, fileName: filename);
          expect(saved.isSuccess, true, reason: saved.errorMessage);
          final bytes = await File('${folder.path}/$filename').readAsBytes();
          final codec = await ui.instantiateImageCodec(bytes);
          final frame = await codec.getNextFrame();
          report['originalSize'] = '${frame.image.width}x${frame.image.height}';
          report['savedBytes'] = bytes.length;
          frame.image.dispose();
          codec.dispose();
          report['passed'] = true;
        } catch (error) {
          report['passed'] = false;
          report['error'] = '$error';
          rethrow;
        } finally {
          client.close();
          await File(
            '${folder.path}/result.json',
          ).writeAsString(const JsonEncoder.withIndent('  ').convert(report));
        }
      },
      skip: !enabled,
      timeout: const Timeout(Duration(minutes: 8)),
    );
  }
}
