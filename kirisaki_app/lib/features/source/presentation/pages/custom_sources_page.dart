import 'package:flutter/material.dart';

import '../../../../core/source/custom_source_store.dart';
import '../../../../core/source/source_config.dart';

/// 我的图源页：展示用户导入的自定义图源，支持删除。
/// （内置图源不展示、不可在此编辑删除。）
class CustomSourcesPage extends StatefulWidget {
  const CustomSourcesPage({super.key, this.store});

  /// 注入的仓库（测试用），默认使用真实仓库。
  final CustomSourceStore? store;

  @override
  State<CustomSourcesPage> createState() => _CustomSourcesPageState();
}

class _CustomSourcesPageState extends State<CustomSourcesPage> {
  late final CustomSourceStore _store = widget.store ?? CustomSourceStore();
  List<SourceConfig>? _sources;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final List<SourceConfig> sources = await _store.load();
    if (!mounted) {
      return;
    }
    setState(() => _sources = sources);
  }

  Future<void> _remove(SourceConfig source) async {
    await _store.removeById(source.id);
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<SourceConfig>? sources = _sources;
    return Scaffold(
      appBar: AppBar(title: const Text('我的图源')),
      body: sources == null
          ? const Center(child: CircularProgressIndicator())
          : sources.isEmpty
              ? Center(
                  child: Text(
                    '暂无自定义图源',
                    style: TextStyle(color: theme.colorScheme.outline),
                  ),
                )
              : ListView.builder(
                  itemCount: sources.length,
                  itemBuilder: (BuildContext context, int index) {
                    final SourceConfig source = sources[index];
                    return ListTile(
                      leading: Icon(
                        source.sourceType == SourceType.json
                            ? Icons.data_object
                            : Icons.language,
                      ),
                      title: Text(source.name),
                      subtitle: Text(
                        source.baseUrl,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: IconButton(
                        tooltip: '删除图源',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _remove(source),
                      ),
                    );
                  },
                ),
    );
  }
}
