import 'package:flutter/material.dart';

import '../../../../core/profile/search_history_service.dart';

/// 搜索历史页：点击条目快速搜索（触发跨页事件），
/// 支持删除单条与清空。
class SearchHistoryPage extends StatefulWidget {
  const SearchHistoryPage({super.key, this.historyService});

  /// 注入的搜索历史服务（测试用），默认使用全局单例。
  final SearchHistoryService? historyService;

  @override
  State<SearchHistoryPage> createState() => _SearchHistoryPageState();
}

class _SearchHistoryPageState extends State<SearchHistoryPage> {
  late final SearchHistoryService _service =
      widget.historyService ?? SearchHistoryService.instance;

  @override
  void initState() {
    super.initState();
    _service.load();
  }

  /// 点击快速搜索：记录选中关键词并通知（SearchPage/HomeShell 监听后
  /// 自动填入搜索框执行搜索并切回主页 tab），随后返回。
  void _select(String keyword) {
    _service.select(keyword);
    Navigator.of(context).pop();
  }

  Future<void> _clearAll() async {
    await _service.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('搜索历史'),
        actions: [
          IconButton(
            tooltip: '清空',
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: _service.keywords.isEmpty ? null : _clearAll,
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: _service,
        builder: (BuildContext context, Widget? child) {
          final List<String> keywords = _service.keywords;
          if (keywords.isEmpty) {
            return Center(
              child: Text(
                '暂无搜索历史',
                style: TextStyle(color: Theme.of(context).colorScheme.outline),
              ),
            );
          }
          return ListView.builder(
            itemCount: keywords.length,
            itemBuilder: (BuildContext context, int index) {
              final String keyword = keywords[index];
              return ListTile(
                leading: const Icon(Icons.history),
                title: Text(keyword),
                trailing: IconButton(
                  tooltip: '删除',
                  icon: const Icon(Icons.close),
                  onPressed: () => _service.remove(keyword),
                ),
                onTap: () => _select(keyword),
              );
            },
          );
        },
      ),
    );
  }
}
