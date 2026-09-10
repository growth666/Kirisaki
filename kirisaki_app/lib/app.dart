import 'package:flutter/material.dart';

import 'core/constants/app_constants.dart';
import 'core/router/app_router.dart';
import 'core/settings/settings_service.dart';
import 'core/theme/app_theme.dart';

/// 应用根组件：监听设置服务，主题模式全局生效（亮色/暗黑/跟随系统）。
class KirisakiApp extends StatefulWidget {
  const KirisakiApp({super.key});

  @override
  State<KirisakiApp> createState() => _KirisakiAppState();
}

class _KirisakiAppState extends State<KirisakiApp> {
  @override
  void initState() {
    super.initState();
    SettingsService.instance.load();
    SettingsService.instance.addListener(_onSettingsChanged);
  }

  @override
  void dispose() {
    SettingsService.instance.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      // 主题模式由设置页切换（亮色/暗黑/跟随系统），持久化并全页面生效。
      themeMode: SettingsService.instance.themeMode,
      routerConfig: appRouter,
    );
  }
}
