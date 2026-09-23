import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_constants.dart';

/// 关于页面：项目名称、版本号、简介、开源说明。
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('关于')),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.image_search,
                  size: 72,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 12),
                Text(
                  AppConstants.appName,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '版本 ${AppConstants.appVersion}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: ExpansionTile(
                    leading: const Icon(Icons.article_outlined),
                    title: const Text('版本说明'),
                    subtitle: const Text('当前版本功能与已知限制'),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Kirisaki ${AppConstants.appVersion}',
                                style: theme.textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                '• 多图源搜索、推荐流与中文标签辅助\n• 图片收藏、浏览历史与下载记录\n• 缩略图缓存、代理设置与内容显示控制\n• 数据备份与恢复\n• Android 刷新率偏好设置',
                              ),
                              const SizedBox(height: 12),
                              Text('已知限制', style: theme.textTheme.titleSmall),
                              const SizedBox(height: 4),
                              const Text(
                                '图源可用性受网络环境和站点限制影响；刷新率设置会受设备、省电模式和系统策略限制。',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.feedback_outlined),
                    title: const Text('反馈问题'),
                    subtitle: const Text('在 GitHub Issues 提交问题，开发者会在那里收到反馈'),
                    trailing: const Icon(Icons.open_in_new),
                    onTap: () async {
                      final uri = Uri.parse(
                        'https://github.com/growth666/Kirisaki/issues/new?title=%5B反馈%5D+请描述问题',
                      );
                      final opened = await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                      if (!context.mounted) return;
                      if (!opened) {
                        await Clipboard.setData(
                          ClipboardData(text: uri.toString()),
                        );
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('无法打开浏览器，反馈链接已复制')),
                        );
                      }
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '跨平台二次元图片搜图客户端：支持多图源搜索、'
                  '推荐流、图片收藏与下载。',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                Text(
                  '开源说明：本项目仅供学习交流使用，请遵守各图源站点'
                  '服务条款与当地法律法规。',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
