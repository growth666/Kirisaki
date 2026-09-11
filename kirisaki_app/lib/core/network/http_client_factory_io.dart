import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import 'proxy_settings_service.dart';

/// 原生平台（Android/iOS/桌面）：代理启用时使用 IOClient + findProxy。
http.Client createProxiedClient() {
  final ProxySettingsService proxy = ProxySettingsService.instance;
  if (proxy.enabled && proxy.isValid) {
    final HttpClient inner = HttpClient()
      ..findProxy = (Uri uri) => 'PROXY ${proxy.host}:${proxy.port}';
    return IOClient(inner);
  }
  return http.Client();
}
