import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
                const SizedBox(height: 24),
                const Text(
                  '本地中文标签词库：DanbooruSearchOnline\nSuzumiyaAkizuki · GPL-3.0',
                  textAlign: TextAlign.center,
                ),
                const SelectableText(
                  'https://github.com/SuzumiyaAkizuki/DanbooruSearchOnline',
                  textAlign: TextAlign.center,
                ),
                TextButton(
                  onPressed: () async {
                    final text = await rootBundle.loadString(
                      'assets/search/DanbooruSearchOnline-LICENSE.txt',
                    );
                    if (!context.mounted) return;
                    showDialog<void>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('词库许可证 · GPL-3.0'),
                        content: SingleChildScrollView(
                          child: SelectableText(text),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('关闭'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: const Text('查看词库许可证'),
                ),
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
