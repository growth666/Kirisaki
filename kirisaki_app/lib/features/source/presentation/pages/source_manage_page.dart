import 'package:flutter/material.dart';

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
          ],
        ),
      ),
    );
  }
}
