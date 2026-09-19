import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/favorite/favorite_service.dart';
import '../../../../core/profile/download_service.dart';
import '../../../../core/profile/history_service.dart';
import '../../../../core/router/route_names.dart';

/// 我的页面：数据概览卡片 + 功能列表入口。
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with AutomaticKeepAliveClientMixin {
  /// PageView 底部导航切换时保活：不重建。
  @override
  bool get wantKeepAlive => true;

  /// 概览计数变化来源（收藏/浏览/下载三个 ChangeNotifier）。
  late final Listenable _statsListenable = Listenable.merge(<Listenable>[
    FavoriteService.instance,
    HistoryService.instance,
    DownloadService.instance,
  ]);

  @override
  void initState() {
    super.initState();
    // 预热持久化数据（静默容错，加载完成后通知刷新概览）。
    FavoriteService.instance.load();
    HistoryService.instance.load();
    DownloadService.instance.load();
  }

  void _push(String path) => context.push(path);

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: ListView(
        children: [
          // 顶部数据概览卡片（三个服务任一变化即刷新）。
          ListenableBuilder(
            listenable: _statsListenable,
            builder: (BuildContext context, Widget? child) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Row(
                      children: [
                        _StatItem(
                          icon: Icons.favorite_outline,
                          label: '收藏',
                          value: '${FavoriteService.instance.items.length}',
                        ),
                        _StatItem(
                          icon: Icons.history,
                          label: '浏览',
                          value: '${HistoryService.instance.count}',
                        ),
                        _StatItem(
                          icon: Icons.download_outlined,
                          label: '下载',
                          value: '${DownloadService.instance.count}',
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 4),
          _SectionTile(
            icon: Icons.history,
            title: '浏览历史',
            onTap: () => _push('/history'),
          ),
          _SectionTile(
            icon: Icons.search,
            title: '搜索历史',
            onTap: () => _push('/search_history'),
          ),
          _SectionTile(
            icon: Icons.download_outlined,
            title: '下载记录',
            onTap: () => _push('/downloads'),
          ),
          _SectionTile(
            icon: Icons.language,
            title: '我的图源',
            onTap: () => _push('/my_sources'),
          ),
          _SectionTile(
            icon: Icons.visibility_outlined,
            title: '内容显示',
            onTap: () => _push(RouteNames.contentDisplay),
          ),
          _SectionTile(
            icon: Icons.workspace_premium_outlined,
            title: '贡献者榜单',
            onTap: () => _push('/contributors'),
          ),
          _SectionTile(
            icon: Icons.settings_outlined,
            title: '设置',
            onTap: () => _push('/settings'),
          ),
        ],
      ),
    );
  }
}

/// 概览单项：图标 + 数值 + 标签。
class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}

/// 功能列表项。
class _SectionTile extends StatelessWidget {
  const _SectionTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
