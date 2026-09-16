import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import 'proxy_settings_service.dart';

/// 原生平台（Android/iOS/桌面）：代理启用时使用 IOClient + findProxy。
http.Client createProxiedClient({ProxySettingsService? settings}) =>
    _ConfiguredClient(settings ?? ProxySettingsService.instance);

class _ConfiguredClient extends http.BaseClient {
  _ConfiguredClient(this.settings);
  final ProxySettingsService settings;
  final Set<http.Client> _active = {};
  bool _closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (settings.enabled && !settings.isValid) {
      throw http.ClientException('代理配置无效，请检查地址和 HTTP 端口', request.url);
    }
    request.headers.putIfAbsent(
      'User-Agent',
      () => 'Kirisaki/1.0 (image search client)',
    );
    if (_closed) throw http.ClientException('Client is closed', request.url);
    final directive = settings.enabled && settings.isValid
        ? 'PROXY ${settings.host}:${settings.port}'
        : 'DIRECT';
    final inner = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15)
      ..findProxy = (_) => directive;
    final client = IOClient(inner);
    _active.add(client);
    try {
      final response = await client.send(request);
      return http.StreamedResponse(
        _body(response, client),
        response.statusCode,
        contentLength: response.contentLength,
        request: response.request,
        headers: response.headers,
        isRedirect: response.isRedirect,
        persistentConnection: response.persistentConnection,
        reasonPhrase: response.reasonPhrase,
      );
    } catch (_) {
      _release(client);
      rethrow;
    }
  }

  // Each request snapshots the current proxy; changing settings does not abort
  // earlier responses or reuse a connection through the previous proxy.
  Stream<List<int>> _body(
    http.StreamedResponse response,
    http.Client client,
  ) async* {
    try {
      yield* response.stream;
    } finally {
      _release(client);
    }
  }

  void _release(http.Client client) {
    _active.remove(client);
    client.close();
  }

  @override
  void close() {
    _closed = true;
    for (final client in _active) {
      client.close();
    }
    _active.clear();
  }
}
