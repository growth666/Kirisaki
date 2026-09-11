import 'package:http/http.dart' as http;

/// Web 平台：浏览器 fetch 不支持系统代理，始终返回普通 Client
/// （跨域仍走 CORS 代理开关）。
http.Client createProxiedClient() => http.Client();
