import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart'
    show PointerScrollEvent, PointerSignalEvent;
import 'package:flutter/material.dart';

import '../../../../core/download/image_downloader.dart';
import '../../../../core/network/original_image.dart';
import '../../../../core/favorite/favorite_service.dart';
import '../../../../core/profile/download_service.dart';
import '../../../../core/profile/history_service.dart';
import '../../../../core/source/image_item.dart';
import '../../../../core/source/source_parse_service.dart';

/// 以 [focal]（视口坐标）为焦点，对 [current] 应用 [factor] 倍缩放，
/// 并将缩放夹在 [minScale]~[maxScale] 区间（默认 1~8）。
///
/// 抽为顶层纯函数便于单测；矩阵运算顺序：
/// 新矩阵 = T(focal) · S(clamped) · T(-focal) · current。
Matrix4 zoomMatrixAt(
  Matrix4 current,
  double factor, {
  required Offset focal,
  double minScale = 1.0,
  double maxScale = 8.0,
}) {
  final double currentScale = current.getMaxScaleOnAxis();
  if (currentScale <= 0 || factor <= 0) {
    return current;
  }
  final double target = (currentScale * factor).clamp(minScale, maxScale);
  final double clamped = target / currentScale;
  final Matrix4 next = Matrix4.identity()
    ..translateByDouble(focal.dx, focal.dy, 0, 1)
    ..scaleByDouble(clamped, clamped, 1, 1)
    ..translateByDouble(-focal.dx, -focal.dy, 0, 1);
  return next * current;
}

/// 大图预览页：展示原图与标签列表，支持双指/滚轮缩放，AppBar 返回上一页。
///
/// 下载保存、收藏等功能留给后续轮次。
class ImagePreviewPage extends StatelessWidget {
  const ImagePreviewPage({
    super.key,
    this.imageUrl,
    this.item,
    this.favoriteService,
    this.downloadService,
  });

  /// 兼容旧路由参数：仅图片地址（测试与深链场景使用）。
  final String? imageUrl;

  /// 完整图片数据（含标签等），由搜索页经路由 extra 传入。
  final ImageItem? item;

  /// 注入的收藏服务（测试用），默认使用全局单例。
  final FavoriteService? favoriteService;
  final ImageSaveService? downloadService;

  @override
  Widget build(BuildContext context) {
    final ImageItem? resolved =
        item ??
        (imageUrl != null && imageUrl!.isNotEmpty
            ? ImageItem(imageUrl: imageUrl!)
            : null);
    return Scaffold(
      appBar: AppBar(
        title: const Text('图片预览'),
        actions: [
          // 下载入口：所有图片（含推荐流）通用，走平台下载服务。
          if (resolved != null)
            _DownloadButton(item: resolved, service: downloadService),
          if (resolved != null)
            _FavoriteButton(
              item: resolved,
              service: favoriteService ?? FavoriteService.instance,
            ),
        ],
      ),
      body: resolved == null
          ? const _MissingView()
          : _PreviewBody(item: resolved),
    );
  }
}

/// 下载按钮：调用平台下载服务（Web 浏览器下载 / 其他平台 stub）。
class _DownloadButton extends StatefulWidget {
  const _DownloadButton({required this.item, this.service});

  final ImageItem item;
  final ImageSaveService? service;

  @override
  State<_DownloadButton> createState() => _DownloadButtonState();
}

class _DownloadButtonState extends State<_DownloadButton> {
  bool _downloading = false;

  Future<void> _download() async {
    if (_downloading) return;
    setState(() => _downloading = true);
    final ImageSaveResult result =
        await (widget.service ?? createImageDownloadService()).saveImage(
          imageUrl: widget.item.imageUrl,
          fileName: suggestedImageFileName(
            widget.item.imageUrl,
            sourceName: Uri.tryParse(widget.item.sourcePage ?? '')?.host,
          ),
        );
    if (!mounted) return;
    setState(() => _downloading = false);
    if (result.isSuccess) {
      await DownloadService.instance.record(widget.item);
    }
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            result.isSuccess
                ? (result.message ?? '已保存下载文件')
                : (result.errorMessage ?? '下载失败'),
          ),
          action: result.isSuccess
              ? null
              : SnackBarAction(label: '重试', onPressed: _download),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: _downloading ? '下载中' : '下载',
      icon: _downloading
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.download_outlined),
      onPressed: _downloading ? null : _download,
    );
  }
}

/// 收藏/取消收藏按钮：每按钮独立 ValueNotifier 局部刷新——
/// 收藏状态变化只重建本按钮，不随全局 service 通知触发无关重建。
class _FavoriteButton extends StatefulWidget {
  const _FavoriteButton({required this.item, required this.service});

  final ImageItem item;
  final FavoriteService service;

  @override
  State<_FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends State<_FavoriteButton> {
  /// 本图片的收藏状态（独立于全局服务通知）。
  late final ValueNotifier<bool> _favorited = ValueNotifier<bool>(
    widget.service.contains(widget.item.imageUrl),
  );

  @override
  void initState() {
    super.initState();
    widget.service.addListener(_onServiceChanged);
  }

  @override
  void dispose() {
    widget.service.removeListener(_onServiceChanged);
    _favorited.dispose();
    super.dispose();
  }

  /// 仅当本图片收藏状态实际变化时更新 notifier，避免无关重建。
  void _onServiceChanged() {
    final bool value = widget.service.contains(widget.item.imageUrl);
    if (value != _favorited.value) {
      _favorited.value = value;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _favorited,
      builder: (BuildContext context, bool favorited, Widget? child) {
        return IconButton(
          tooltip: favorited ? '取消收藏' : '收藏',
          icon: Icon(
            favorited ? Icons.favorite : Icons.favorite_border,
            color: favorited ? Theme.of(context).colorScheme.primary : null,
          ),
          onPressed: () async {
            if (favorited) {
              await widget.service.remove(widget.item.imageUrl);
              if (context.mounted) {
                _showSnackBar(context, '已取消收藏');
              }
            } else {
              await widget.service.add(widget.item);
              if (context.mounted) {
                _showSnackBar(context, '已收藏');
              }
            }
          },
        );
      },
    );
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

/// 预览主体：可缩放原图 + 标签 + 来源地址。
class _PreviewBody extends StatefulWidget {
  const _PreviewBody({required this.item});

  final ImageItem item;

  @override
  State<_PreviewBody> createState() => _PreviewBodyState();
}

class _PreviewBodyState extends State<_PreviewBody> {
  bool _detailsExpanded = false;

  /// 缩放/平移变换控制器（双指缩放与滚轮缩放共用）。
  final TransformationController _transformationController =
      TransformationController();

  @override
  void initState() {
    super.initState();
    // 每次打开大图预览自动记录浏览历史（去重保留最新，持久化静默容错）。
    HistoryService.instance.record(widget.item);
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  /// 鼠标滚轮缩放：以光标位置为焦点，滚轮向上放大、向下缩小。
  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || event.scrollDelta.dy == 0) {
      return;
    }
    // 每 100 逻辑像素滚轮行程缩放 1.1 倍。
    final double factor = math.pow(1.1, -event.scrollDelta.dy / 100).toDouble();
    _transformationController.value = zoomMatrixAt(
      _transformationController.value,
      factor,
      focal: event.localPosition,
    );
  }

  /// Web 端原图按图源配置决定是否走 CORS 代理（国内直连图源直连加载；
  /// 开关见 [SourceParseService.webCorsProxyEnabled] 与 ImageItem.useProxy）。
  static String _displayUrl(ImageItem item) {
    if (kIsWeb && item.useProxy && SourceParseService.webCorsProxyEnabled) {
      return SourceParseService.buildProxyUri(Uri.parse(item.imageUrl))
          .toString();
    }
    return item.imageUrl;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ImageItem item = widget.item;
    final image = Listener(
      onPointerSignal: _onPointerSignal,
      child: InteractiveViewer(
        transformationController: _transformationController,
        minScale: 1.0,
        maxScale: 8.0,
        clipBehavior: Clip.hardEdge,
        child: Center(child: OriginalImage(url: _displayUrl(item))),
      ),
    );
    final details = SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('图片信息', style: theme.textTheme.titleMedium),
          const SizedBox(height: 16),
          Text('标签 · ${item.tags.length}', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          if (item.tags.isEmpty) const Text('暂无标签'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final tag in item.tags) Text('#$tag')],
          ),
          const SizedBox(height: 20),
          Text('图片地址', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          SelectableText(item.imageUrl, style: theme.textTheme.bodySmall),
        ],
      ),
    );
    return SafeArea(
      top: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 800) {
            return Row(
              children: [
                Expanded(child: image),
                const VerticalDivider(width: 1),
                SizedBox(width: 280, child: details),
              ],
            );
          }
          return Column(
            children: [
              Expanded(child: image),
              const Divider(height: 1),
              ListTile(
                dense: true,
                title: Text('图片信息 · ${item.tags.length} 个标签'),
                trailing: Icon(
                  _detailsExpanded ? Icons.expand_more : Icons.expand_less,
                ),
                onTap: () =>
                    setState(() => _detailsExpanded = !_detailsExpanded),
              ),
              if (_detailsExpanded)
                SizedBox(height: constraints.maxHeight * 0.35, child: details),
            ],
          );
        },
      ),
    );
  }
}

/// 无图片数据占位。
class _MissingView extends StatelessWidget {
  const _MissingView();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Text(
        '未找到图片信息',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.outline,
        ),
      ),
    );
  }
}
