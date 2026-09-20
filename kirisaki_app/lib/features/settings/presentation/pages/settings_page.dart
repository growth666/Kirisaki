import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/cache/thumbnail_memory_cache.dart';
import '../../../../core/download/download_dir_picker.dart';
import '../../../../core/favorite/favorite_service.dart';
import '../../../../core/profile/download_service.dart';
import '../../../../core/profile/history_service.dart';
import '../../../../core/profile/search_history_service.dart';
import '../../../../core/settings/settings_service.dart';
import '../../../../core/source/source_service.dart';
import '../../../../core/source/confirmed_tag_service.dart';

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
        content: const Text('将清空收藏、浏览历史、搜索历史、下载记录、自定义图源与已确认标签，此操作不可恢复。确定继续吗？'),
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
    try {
      await SourceService.instance.reset();
      await ConfirmedTagService().clear();
      await Future.wait(<Future<void>>[
        FavoriteService.instance.clearAll(),
        HistoryService.instance.clear(),
        SearchHistoryService.instance.clear(),
        DownloadService.instance.clear(),
      ]);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('清空失败：$error')));
      }
      return;
    }
    if (mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('本地数据已清空')));
    }
  }

  /// 下载位置当前状态描述（各平台语义）。
  Future<void> _clearConfirmedTags() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清除已确认标签'),
        content: const Text('下次搜索对应词条时，将重新查询并选择 Zerochan 标签。内置词库不会被删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('清除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ConfirmedTagService().clear();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('已确认标签已清除')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('清除失败，请重试')));
      }
    }
  }

  String _downloadDirDescription() {
    final String? dir = _settings.downloadDir;
    if (dir == null) {
      // Web 端：下载时弹系统保存对话框自选位置；
      // 原生端：系统默认下载目录。
      return '系统默认（Web 下载时弹保存对话框自选位置）';
    }
    // Android SAF tree URI 不友好，显示说明文字。
    if (dir.startsWith('content://')) {
      return '已选自定义目录';
    }
    // 桌面路径过长时截断显示。
    return dir.length > 40 ? '${dir.substring(0, 40)}…' : dir;
  }

  /// 弹出平台目录选择器并持久化（取消不报错）。
  Future<void> _changeDownloadDir() async {
    final String? picked = await pickDownloadDirectory();
    if (!mounted) {
      return;
    }
    if (picked == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('未选择目录')));
      return;
    }
    await _settings.setDownloadDir(picked);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('下载位置已更新')));
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
              ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: const Text('下载位置'),
                subtitle: Text(_downloadDirDescription()),
                trailing: const Icon(Icons.chevron_right),
                onTap: _changeDownloadDir,
              ),
              if (_settings.downloadDir != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: TextButton(
                      onPressed: () {
                        _settings.resetDownloadDir();
                      },
                      child: const Text('重置为默认'),
                    ),
                  ),
                ),
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
              // —— 网络代理 ——
              const _GroupHeader('网络代理'),
              ListTile(
                leading: const Icon(Icons.lan_outlined),
                title: const Text('网络代理'),
                subtitle: const Text('配置代理地址与端口（海外图源需代理）'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/proxy'),
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
                leading: const Icon(Icons.translate),
                title: const Text('已确认标签'),
                subtitle: const Text('记住 Zerochan 标签选择；清除后可重新选择'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _clearConfirmedTags,
              ),
              ListTile(
                leading: Icon(
                  Icons.delete_forever_outlined,
                  color: theme.colorScheme.error,
                ),
                title: Text(
                  '清空全部本地数据',
                  style: TextStyle(color: theme.colorScheme.error),
                ),
                subtitle: const Text('收藏、浏览、搜索、下载记录、自定义图源与已确认标签'),
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
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}
