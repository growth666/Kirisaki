import 'package:flutter/material.dart';

import '../../../../core/source/source_config.dart';
import '../../../../core/source/source_json_importer.dart';
import '../../../../core/source/source_service.dart';
import 'source_import_page.dart';

class SourceManagePage extends StatefulWidget {
  const SourceManagePage({super.key, this.service, this.customOnly = false});
  final SourceService? service;
  final bool customOnly;
  @override
  State<SourceManagePage> createState() => _SourceManagePageState();
}

class _SourceManagePageState extends State<SourceManagePage> {
  late final SourceService _service = widget.service ?? SourceService.instance;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _service.load();
    } catch (error) {
      if (mounted) _error = '加载图源失败：$error';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('保存图源失败：$error')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _edit([SourceConfig? source]) {
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SourceImportPage(
          source: source,
          importer: SourceJsonImporter(service: _service),
        ),
      ),
    );
  }

  Future<void> _delete(SourceConfig source) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除图源'),
        content: Text('删除「${source.name}」？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _run(() => _service.remove(source.id));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.customOnly ? '我的图源' : '图源管理'),
      actions: [
        IconButton(
          tooltip: '导入图源',
          onPressed: _loading || _busy || _error != null ? null : () => _edit(),
          icon: const Icon(Icons.post_add),
        ),
      ],
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
        ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error!),
                TextButton(onPressed: _load, child: const Text('重试')),
              ],
            ),
          )
        : ListenableBuilder(
            listenable: _service,
            builder: (context, _) {
              final sources = widget.customOnly
                  ? _service.custom
                  : _service.all;
              if (sources.isEmpty) return const Center(child: Text('暂无自定义图源'));
              return ListView.builder(
                itemCount: sources.length,
                itemBuilder: (context, index) {
                  final source = sources[index];
                  final builtin = _service.isBuiltin(source.id);
                  return ListTile(
                    title: Text(source.name),
                    subtitle: Text(
                      '${builtin ? '内置' : '自定义'} · ${source.baseUrl}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(
                          key: ValueKey('enabled_${source.id}'),
                          value: source.enabled,
                          onChanged: _busy
                              ? null
                              : (value) => _run(
                                  () => _service.setEnabled(source.id, value),
                                ),
                        ),
                        if (!builtin)
                          PopupMenuButton<String>(
                            tooltip: '图源操作',
                            enabled: !_busy,
                            onSelected: (action) {
                              if (action == 'edit') {
                                _edit(source);
                              } else {
                                _delete(source);
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'edit', child: Text('编辑')),
                              PopupMenuItem(value: 'delete', child: Text('删除')),
                            ],
                          ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
  );
}
