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
                subtitle: const Text('关闭时自动隐藏带有成人或露骨标签的搜索结果'),
                value: _settings.showAdultContent,
                onChanged: _settings.setShowAdultContent,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
