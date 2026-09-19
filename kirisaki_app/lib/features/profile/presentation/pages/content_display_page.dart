import 'package:flutter/material.dart';

import '../../../../core/settings/settings_service.dart';

class ContentDisplayPage extends StatefulWidget {
  const ContentDisplayPage({super.key});

  @override
  State<ContentDisplayPage> createState() => _ContentDisplayPageState();
}

class _ContentDisplayPageState extends State<ContentDisplayPage> {
  final SettingsService _settings = SettingsService.instance;

  @override
  void initState() {
    super.initState();
    _settings.load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('内容显示')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _settings,
          builder: (context, child) => ListView(
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.visibility_outlined),
                title: const Text('显示 18+ 内容'),
                subtitle: const Text('关闭时隐藏被标记为可疑或露骨的搜索与推荐图片；切换后重新加载当前结果'),
                value: _settings.showAdultContent,
                onChanged: _settings.setShowAdultContent,
              ),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  '未提供评级且没有相关标签的图片仍会显示，不代表已确认安全。过滤依赖图源信息，无法保证完全识别。开启此选项不会解除 Safe 图源自身的限制，也不会删除已有收藏或历史记录。',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
