import 'package:flutter/material.dart';

import '../../../../core/network/proxy_settings_service.dart';

/// 代理配置页：启用开关 + 地址/端口输入，即存即生效 + 本地持久化
/// （App 重启不丢失）。
///
/// 说明：海外 booru 图源需配置代理才能正常访问；
/// 国内图源（推荐流/百度/必应聚合）无需代理即可使用。
class ProxySettingsPage extends StatefulWidget {
  const ProxySettingsPage({super.key, this.service});

  /// 注入的代理配置服务（测试用），默认使用全局单例。
  final ProxySettingsService? service;

  @override
  State<ProxySettingsPage> createState() => _ProxySettingsPageState();
}

class _ProxySettingsPageState extends State<ProxySettingsPage> {
  late final ProxySettingsService _service =
      widget.service ?? ProxySettingsService.instance;
  final TextEditingController _hostController = TextEditingController();
  final TextEditingController _portController = TextEditingController();
  bool _enabled = false;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _service.load().then((_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _hostController.text = _service.host;
        _portController.text = '${_service.port}';
        _enabled = _service.enabled;
        _loading = false;
      });
    });
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || _loading) return;
    final host = _hostController.text.trim();
    final int? port = int.tryParse(_portController.text.trim());
    if (port == null || port <= 0 || port > 65535) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('端口必须是 1~65535 的整数')));
      return;
    }
    if (_enabled && (host.isEmpty || host.contains(RegExp(r'[\s/:]')))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入代理主机名或 IPv4 地址，不含协议和端口')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await _service.save(enabled: _enabled, host: host, port: port);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('保存代理失败：$error')));
      }
      return;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('代理配置已保存并生效')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('网络代理')),
      body: ListenableBuilder(
        listenable: _service,
        builder: (BuildContext context, Widget? child) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SwitchListTile(
                title: const Text('启用代理'),
                subtitle: const Text('HTTP / mixed'),
                value: _enabled,
                onChanged: _loading || _saving
                    ? null
                    : (value) => setState(() => _enabled = value),
              ),
              const SizedBox(height: 8),
              TextField(
                key: const Key('proxyHostInput'),
                controller: _hostController,
                decoration: const InputDecoration(
                  labelText: '代理地址',
                  hintText: '127.0.0.1',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                key: const Key('proxyPortInput'),
                controller: _portController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'HTTP / mixed 端口',
                  hintText: '7890',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _loading || _saving ? null : _save,
                icon: const Icon(Icons.save_outlined),
                label: const Text('保存'),
              ),
              const SizedBox(height: 16),
              Text(
                'Android 的 127.0.0.1 指向手机自身。使用电脑代理时需填写电脑的局域网地址。',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: Theme.of(context).colorScheme.outline),
              ),
            ],
          );
        },
      ),
    );
  }
}
