import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'http_client_factory.dart';
import 'proxy_settings_service.dart';

/// Share only in-flight transfers. Each transfer owns its client, so disposing
/// one image widget cannot interrupt another widget waiting for the same URL.
class ThumbnailRequests {
  ThumbnailRequests({
    http.Client Function()? clientFactory,
    this.maxConcurrent = 6,
  }) : assert(maxConcurrent > 0),
       _clientFactory = clientFactory ?? buildClient;
  final http.Client Function() _clientFactory;
  final int maxConcurrent;
  static final instance = ThumbnailRequests();
  final _pending = <String, Future<Uint8List>>{};
  final _consumers = <String, List<bool Function()>>{};
  final _queue = Queue<void Function()>();
  int _active = 0;

  Future<Uint8List> load(String url, {bool Function()? isNeeded}) {
    final proxy = ProxySettingsService.instance;
    final key = '$url|${proxy.enabled}|${proxy.host}|${proxy.port}';
    (_consumers[key] ??= []).add(isNeeded ?? () => true);
    return _pending.putIfAbsent(key, () {
      final result = Completer<Uint8List>();
      _queue.add(() async {
        http.Client? client;
        try {
          if (!_consumers[key]!.any((needed) => needed())) {
            throw http.ClientException('Thumbnail no longer visible');
          }
          client = _clientFactory();
          final response = await client
              .get(Uri.parse(url))
              .timeout(const Duration(seconds: 10));
          if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
            throw http.ClientException('HTTP ${response.statusCode}');
          }
          result.complete(response.bodyBytes);
        } catch (error, stack) {
          result.completeError(error, stack);
        } finally {
          client?.close();
          _pending.remove(key);
          _consumers.remove(key);
          _active--;
          scheduleMicrotask(_drain);
        }
      });
      scheduleMicrotask(_drain);
      return result.future;
    });
  }

  void _drain() {
    while (_active < maxConcurrent && _queue.isNotEmpty) {
      _active++;
      _queue.removeFirst()();
    }
  }
}
