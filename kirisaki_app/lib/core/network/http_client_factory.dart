import 'package:http/http.dart' as http;

import 'http_client_factory_stub.dart'
    if (dart.library.io) 'http_client_factory_io.dart';

/// 构建网络请求 client（全局代理适配，条件导入分平台）。
///
/// - 代理启用且配置有效 → 带 `findProxy` 的 IOClient（所有 HTTP 请求
///   走指定代理）；
/// - 否则返回普通 [http.Client]（默认行为不变）。
///
/// 说明：
/// - **海外 booru 图源需配置代理才能正常访问；国内图源无需代理**；
/// - Web 端浏览器 fetch 不支持系统代理（仍走 CORS 代理开关，
///   见 SourceParseService.webCorsProxyEnabled）。
http.Client buildClient() => createProxiedClient();
