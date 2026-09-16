import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:kirisaki_app/core/network/http_client_factory_io.dart';
import 'package:kirisaki_app/core/network/proxy_settings_service.dart';
import 'package:kirisaki_app/core/download/image_downloader_io.dart';
import 'package:kirisaki_app/core/source/source_parse_service.dart';
import 'package:kirisaki_app/core/source/source_config.dart';

void main() {
  test(
    'HTTPS targets use HTTP CONNECT and never fall back to direct on rejection',
    () async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      final proxy = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final requests = <String>[];
      proxy.listen((request) async {
        requests.add(request.method);
        request.response.statusCode = 502;
        await request.response.close();
      });
      final settings = ProxySettingsService();
      await settings.save(enabled: true, host: '127.0.0.1', port: proxy.port);
      final client = createProxiedClient(settings: settings);
      try {
        await expectLater(
          client.get(Uri.parse('https://example.invalid/original.jpg')),
          throwsA(isA<Exception>()),
        );
        expect(requests, ['CONNECT']);
      } finally {
        client.close();
        await proxy.close(force: true);
      }
    },
  );
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });
  test('existing clients switch proxy and direct routes, including search and saved bytes', () async {
    final first = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final second = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final origin = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final folder = await Directory.systemTemp.createTemp('kirisaki-proxy-');
    final hits = <String>[];
    void serve(HttpServer server, String label) {
      server.listen((request) async {
        hits.add('$label:${request.uri.path}');
        request.response.write(
          request.uri.path == '/search'
              ? '[{"file_url":"http://example.invalid/original.jpg"}]'
              : label,
        );
        await request.response.close();
      });
    }

    serve(first, 'first');
    serve(second, 'second');
    serve(origin, 'direct');
    final settings = ProxySettingsService();
    final client = createProxiedClient(settings: settings);
    try {
      await settings.save(enabled: true, host: '127.0.0.1', port: first.port);
      final parser = SourceParseService(client: client);
      const config = SourceConfig(
        id: 'test',
        name: 'test',
        baseUrl: 'http://example.invalid',
        searchUrlTemplate: '/search',
        sourceType: SourceType.json,
        extractRule: ExtractRule(listSelector: 'li', imageUrl: FieldRule()),
      );
      expect((await parser.search(config, keyword: 'sky')).isSuccess, true);
      expect(
        (await client.get(Uri.parse('http://example.invalid/thumbnail.jpg')))
            .body,
        'first',
      );
      await settings.save(enabled: true, host: '127.0.0.1', port: second.port);
      expect(
        (await client.get(Uri.parse('http://example.invalid/original.jpg')))
            .body,
        'second',
      );
      final saved = await IoImageDownloadService(
        downloadDirOverride: folder,
        client: client,
      ).saveImage(imageUrl: 'http://example.invalid/download.jpg');
      expect(saved.isSuccess, true);
      expect(
        await File('${folder.path}/download.jpg').readAsString(),
        'second',
      );
      await settings.save(enabled: false, host: '127.0.0.1', port: second.port);
      expect(
        (await client.get(Uri.parse('http://127.0.0.1:${origin.port}/direct')))
            .body,
        'direct',
      );
      expect(hits, [
        'first:/search',
        'first:/thumbnail.jpg',
        'second:/original.jpg',
        'second:/download.jpg',
        'direct:/direct',
      ]);
    } finally {
      client.close();
      await first.close(force: true);
      await second.close(force: true);
      await origin.close(force: true);
      await folder.delete(recursive: true);
    }
  });
}
