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
  bool _downloading = false;

  @override
  void initState() {
    super.initState();
    _service.load();
  }

  Future<void> _reDownload(ImageItem item) async {
    if (_downloading) return;
    setState(() => _downloading = true);
    ImageSaveResult result;
    try {
      result = await createImageDownloadService().saveImage(
        imageUrl: item.imageUrl,
        fileName: suggestedImageFileName(item.imageUrl),
      );
    } catch (_) {
      result = const ImageSaveResult.failure('下载失败，请检查网络或保存位置后重试');
    }
    if (!mounted) {
      return;
    }
    setState(() => _downloading = false);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            result.isSuccess
                ? (result.message ?? '已开始下载')
                : result.errorMessage!,
          ),
          action: result.isSuccess
              ? null
              : SnackBarAction(
                  label: '重试',
                  onPressed: () {
                    if (mounted) _reDownload(item);
                  },
                ),
        ),
      );
  }

  Future<void> _clearRecords() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空下载记录'),
        content: const Text('只会删除应用内的下载记录，不会删除已经保存到设备的图片。确定继续吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _service.clear();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('下载记录'),
        actions: [
          ListenableBuilder(
            listenable: _service,
            builder: (context, _) => IconButton(
              tooltip: '清空记录',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: _service.items.isEmpty ? null : _clearRecords,
            ),
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
                  Uri.tryParse(item.imageUrl)?.pathSegments.lastOrNull ??
                      item.imageUrl,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${_sourceLabel(item)} · 已下载',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: PopupMenuButton<String>(
                  tooltip: '记录操作',
                  onSelected: (value) {
                    if (value == 'download') _reDownload(item);
                    if (value == 'remove') _service.remove(item);
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'download',
                      enabled: !_downloading,
                      child: Text(_downloading ? '下载中…' : '重新下载'),
                    ),
                    const PopupMenuItem(value: 'remove', child: Text('移除记录')),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _sourceLabel(ImageItem item) {
    final host = Uri.tryParse(item.sourcePage ?? '')?.host;
    return host == null || host.isEmpty ? '未知图源' : host;
  }
}
