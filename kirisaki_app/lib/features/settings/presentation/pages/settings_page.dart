import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/cache/thumbnail_memory_cache.dart';
import '../../../../core/favorite/favorite_service.dart';
import '../../../../core/profile/download_service.dart';
import '../../../../core/profile/history_service.dart';
import '../../../../core/profile/search_history_service.dart';
import '../../../../core/settings/settings_service.dart';
import '../../../../core/source/custom_source_store.dart';
import '../../../../core/source/source_config.dart';

/// 设置页面：下载设置、外观设置、缓存管理、数据管理、关于入口。
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final SettingsService _settings = SettingsService.instance;

  @override
  void initState() {
    super.initState();
    _settings.load();
  }

  /// 一键清空全部本地数据（收藏/浏览/搜索/下载/图源），带二次确认。
  Future<void> _confirmClearAllData() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('清空全部本地数据'),
        content: const Text('将清空收藏、浏览历史、搜索历史、下载记录与自定义图源，此操作不可恢复。确定继续吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    await Future.wait(<Future<void>>[
      FavoriteService.instance.clearAll(),
      HistoryService.instance.clear(),
      SearchHistoryService.instance.clear(),
      DownloadService.instance.clear(),
      CustomSourceStore().save(const <SourceConfig>[]),
    ]);
    if (mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('本地数据已清空')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListenableBuilder(
        listenable: _settings,
        builder: (BuildContext context, Widget? child) {
          return ListView(
            children: [
              // —— 下载设置 ——
              const _GroupHeader('下载设置'),
              const ListTile(
                enabled: false, // Web 端下载位置由浏览器控制 → 置灰
                leading: Icon(Icons.folder_outlined),
                title: Text('下载位置'),
                subtitle: Text('由浏览器默认下载目录控制'),
                trailing: Icon(Icons.lock_outline),
              ),
              // 注：移动端"保存位置选择"能力由 ImageSaveService 抽象接口
              // 预留，具体存储实现后续轮次接入（不新增 Android 专属代码）。
              // —— 外观设置 ——
              const _GroupHeader('外观设置'),
              RadioGroup<ThemeMode>(
                groupValue: _settings.themeMode,
                onChanged: (ThemeMode? mode) {
                  if (mode != null) {
                    _settings.setThemeMode(mode);
                  }
                },
                child: const Column(
                  children: [
                    RadioListTile<ThemeMode>(
                      title: Text('跟随系统'),
                      value: ThemeMode.system,
                    ),
                    RadioListTile<ThemeMode>(
                      title: Text('亮色'),
                      value: ThemeMode.light,
                    ),
                    RadioListTile<ThemeMode>(
                      title: Text('暗黑'),
                      value: ThemeMode.dark,
                    ),
                  ],
                ),
              ),
              // —— 缓存管理 ——
              const _GroupHeader('缓存管理'),
              ListTile(
                leading: const Icon(Icons.photo_size_select_actual_outlined),
                title: const Text('缩略图缓存'),
                subtitle: Text('${ThumbnailMemoryCache.instance.length} 项'),
                trailing: TextButton(
                  onPressed: () {
                    ThumbnailMemoryCache.instance.clear();
                    setState(() {});
                  },
                  child: const Text('清除'),
                ),
              ),
              // —— 数据管理 ——
              const _GroupHeader('数据管理'),
              ListTile(
                leading: Icon(Icons.delete_forever_outlined,
                    color: theme.colorScheme.error),
                title: Text(
                  '清空全部本地数据',
                  style: TextStyle(color: theme.colorScheme.error),
                ),
                subtitle: const Text('收藏、浏览、搜索、下载记录与自定义图源'),
                onTap: _confirmClearAllData,
              ),
              // —— 关于 ——
              const _GroupHeader('关于'),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('关于 Kirisaki'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/about'),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 分组标题。
class _GroupHeader extends StatelessWidget {
  const _GroupHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        title,
        style: theme.textTheme.labelLarge
            ?.copyWith(color: theme.colorScheme.primary),
      ),
    );
  }
}
