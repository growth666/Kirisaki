import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/source/source_json_importer.dart';

/// 图源导入页：粘贴 JSON 文本导入自定义图源。
///
/// 失败 → 页面内红色错误文本展示明确提示（格式错误/字段缺失），不崩溃；
/// 成功 → SnackBar 提示并返回上一页；导入结果自动持久化（App 重启不丢失）。
class SourceImportPage extends StatefulWidget {
  const SourceImportPage({super.key, this.importer});

  /// 注入的导入器（测试用），默认使用真实导入器。
  final SourceJsonImporter? importer;

  @override
  State<SourceImportPage> createState() => _SourceImportPageState();
}

class _SourceImportPageState extends State<SourceImportPage> {
  late final SourceJsonImporter _importer =
      widget.importer ?? SourceJsonImporter();
  final TextEditingController _controller = TextEditingController();

  String? _error; // 校验失败提示（页面内红色文本）
  bool _importing = false; // 导入中请求锁

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _import() async {
    // 请求锁：导入中禁止重复触发。
    if (_importing) {
      return;
    }
    setState(() {
      _error = null;
      _importing = true;
    });
    final SourceImportResult result =
        await _importer.importAndSave(_controller.text);
    if (!mounted) {
      return;
    }
    setState(() => _importing = false);
    if (result.isSuccess) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('图源「${result.config!.name}」导入成功')),
        );
      context.pop();
    } else {
      setState(() => _error = result.errorMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('导入图源')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '粘贴图源配置 JSON（必填：id / name / baseUrl / '
              'searchUrlTemplate / extractRule.listSelector / '
              'extractRule.imageUrl）',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: TextField(
                key: const Key('sourceJsonInput'),
                controller: _controller,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(
                  hintText: '{\n  "id": "my_source",\n  ...\n}',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              // 导入失败：红色错误文本展示明确提示，不崩溃。
              Text(
                _error!,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.error),
              ),
            ],
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _importing ? null : _import,
              icon: _importing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.file_download_outlined),
              label: const Text('导入'),
            ),
          ],
        ),
      ),
    );
  }
}
