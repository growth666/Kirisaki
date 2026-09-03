import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 图源管理页（占位）。
///
/// 后续轮次在此实现图源列表的启用/禁用、优先级调整与自定义图源。
class SourceManagePage extends StatelessWidget {
  const SourceManagePage({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('图源管理')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.tune, size: 64, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text('图源管理功能开发中', style: theme.textTheme.titleMedium),
            const SizedBox(height: 24),
            // 导入入口（纯追加；原占位文案保留，既有测试断言不受影响）。
            FilledButton.tonalIcon(
              onPressed: () => context.push('/sources/import'),
              icon: const Icon(Icons.post_add),
              label: const Text('导入图源'),
            ),
          ],
        ),
      ),
    );
  }
}
