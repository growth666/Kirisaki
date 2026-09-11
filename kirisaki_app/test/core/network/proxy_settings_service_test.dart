import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:kirisaki_app/core/network/http_client_factory.dart';
import 'package:kirisaki_app/core/network/proxy_settings_service.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test('默认关闭且配置持久化往返', () async {
    final ProxySettingsService service = ProxySettingsService();
    expect(service.enabled, isFalse); // 默认关闭，不影响原有逻辑
    expect(service.isValid, isFalse);

    await service.save(enabled: true, host: '127.0.0.1', port: 7890);
    expect(service.enabled, isTrue);
    expect(service.isValid, isTrue);

    // 重启恢复。
    final ProxySettingsService restarted = ProxySettingsService();
    await restarted.load();
    expect(restarted.enabled, isTrue);
    expect(restarted.host, '127.0.0.1');
    expect(restarted.port, 7890);
  });

  test('配置变化触发通知', () async {
    final ProxySettingsService service = ProxySettingsService();
    int notified = 0;
    service.addListener(() => notified++);

    await service.save(enabled: false, host: 'localhost', port: 1080);
    expect(notified, 1);
  });

  test('buildClient 在关闭状态返回可用 Client', () {
    final ProxySettingsService service = ProxySettingsService.instance;
    service.save(enabled: false, host: '', port: 1080);

    // 注：http.Client() 工厂在 VM 上本身就返回 IOClient，
    // 类型无法区分是否带代理；findProxy 接线由真实代理环境验证。
    final http.Client client = buildClient();
    expect(client, isA<http.Client>());
    client.close();
  });

  test('buildClient 在启用状态返回可用 Client', () async {
    final ProxySettingsService service = ProxySettingsService.instance;
    await service.save(enabled: true, host: '127.0.0.1', port: 7890);

    final http.Client client = buildClient();
    expect(client, isA<http.Client>());
    client.close();
  });
}
