import 'package:flutter/material.dart';

/// 搜索页（占位）。
///
/// 后续轮次在此实现关键词/以图搜图入口与结果瀑布流。
class SearchPage extends StatelessWidget {
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('搜索')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.image_search, size: 64, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text('图片搜索功能开发中', style: theme.textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}
