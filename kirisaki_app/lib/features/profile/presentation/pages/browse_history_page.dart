import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/profile/history_service.dart';
import '../../../../core/source/image_item.dart';
import '../../../search/presentation/widgets/thumbnail_image.dart';

/// 浏览历史页：列表展示历史浏览图片（最新在前），
/// 点击跳转复用现有大图预览页；支持清空。
class BrowseHistoryPage extends StatefulWidget {
  const BrowseHistoryPage({super.key, this.historyService});

  /// 注入的浏览历史服务（测试用），默认使用全局单例。
  final HistoryService? historyService;

  @override
  State<BrowseHistoryPage> createState() => _BrowseHistoryPageState();
}

class _BrowseHistoryPageState extends State<BrowseHistoryPage> {
  late final HistoryService _service =
      widget.historyService ?? HistoryService.instance;

  @override
  void initState() {
    super.initState();
    _service.load();
  }

  Future<void> _clearAll() async {
    await _service.clear();
  }

  void _openPreview(ImageItem item) {
    context.push(
      '/preview?url=${Uri.encodeComponent(item.imageUrl)}',
      extra: item,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('浏览历史'),
        actions: [
          IconButton(
            tooltip: '清空',
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: _service.items.isEmpty ? null : _clearAll,
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: _service,
        builder: (BuildContext context, Widget? child) {
          final List<ImageItem> items = _service.items;
          if (items.isEmpty) {
            return Center(
              child: Text(
                '暂无浏览历史',
                style: TextStyle(color: Theme.of(context).colorScheme.outline),
              ),
            );
          }
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (BuildContext context, int index) {
              final ImageItem item = items[index];
              return ListTile(
                // key 保证缩略图 State 跟随 item（头插移位不错位）。
                key: ValueKey<String>(item.imageUrl),
                leading: SizedBox(
                  width: 56,
                  height: 56,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: ThumbnailImage(
                      url: item.thumbnailUrl ?? item.imageUrl,
                      useProxy: item.useProxy,
                    ),
                  ),
                ),
                title: Text(
                  item.tags.isNotEmpty
                      ? item.tags.take(4).join(' ')
                      : item.imageUrl,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _openPreview(item),
              );
            },
          );
        },
      ),
    );
  }
}
