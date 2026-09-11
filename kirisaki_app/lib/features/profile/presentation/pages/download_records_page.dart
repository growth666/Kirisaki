import 'package:flutter/material.dart';

import '../../../../core/download/image_downloader.dart';
import '../../../../core/profile/download_service.dart';
import '../../../../core/source/image_item.dart';
import '../../../search/presentation/widgets/thumbnail_image.dart';

/// 下载记录页：缩略图 + 下载状态；点击可重新下载（复用平台下载服务）。
class DownloadRecordsPage extends StatefulWidget {
  const DownloadRecordsPage({super.key, this.downloadService});

  /// 注入的下载记录服务（测试用），默认使用全局单例。
  final DownloadService? downloadService;

  @override
  State<DownloadRecordsPage> createState() => _DownloadRecordsPageState();
}

class _DownloadRecordsPageState extends State<DownloadRecordsPage> {
  late final DownloadService _service =
      widget.downloadService ?? DownloadService.instance;

  @override
  void initState() {
    super.initState();
    _service.load();
  }

  Future<void> _reDownload(ImageItem item) async {
    final ImageSaveResult result = await createImageDownloadService()
        .saveImage(imageUrl: item.imageUrl);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(
          result.isSuccess ? (result.message ?? '已开始下载') : result.errorMessage!,
        ),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('下载记录')),
      body: ListenableBuilder(
        listenable: _service,
        builder: (BuildContext context, Widget? child) {
          final List<ImageItem> items = _service.items;
          if (items.isEmpty) {
            return Center(
              child: Text(
                '暂无下载记录',
                style: TextStyle(color: theme.colorScheme.outline),
              ),
            );
          }
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (BuildContext context, int index) {
              final ImageItem item = items[index];
              return ListTile(
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
                subtitle: const Text('已下载'),
                trailing: IconButton(
                  tooltip: '重新下载',
                  icon: const Icon(Icons.download_outlined),
                  onPressed: () => _reDownload(item),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
