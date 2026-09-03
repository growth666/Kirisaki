import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../../../core/source/image_item.dart';
import '../../../../core/source/source_parse_service.dart';

/// 大图预览页：展示原图与标签列表，AppBar 返回上一页。
///
/// 本轮仅实现原图展示；缩放、下载保存等功能留给后续轮次。
class ImagePreviewPage extends StatelessWidget {
  const ImagePreviewPage({super.key, this.imageUrl, this.item});

  /// 兼容旧路由参数：仅图片地址（测试与深链场景使用）。
  final String? imageUrl;

  /// 完整图片数据（含标签等），由搜索页经路由 extra 传入。
  final ImageItem? item;

  @override
  Widget build(BuildContext context) {
    final ImageItem? resolved = item ??
        (imageUrl != null && imageUrl!.isNotEmpty
            ? ImageItem(imageUrl: imageUrl!)
            : null);
    return Scaffold(
      appBar: AppBar(title: const Text('图片预览')),
      body: resolved == null
          ? const _MissingView()
          : _PreviewBody(item: resolved),
    );
  }
}

/// 预览主体：原图 + 标签 + 来源地址。
class _PreviewBody extends StatelessWidget {
  const _PreviewBody({required this.item});

  final ImageItem item;

  /// Web 端原图同样走 CORS 代理（与搜索页缩略图逻辑一致，
  /// 开关见 [SourceParseService.webCorsProxyEnabled]）。
  static String _displayUrl(String url) {
    if (kIsWeb && SourceParseService.webCorsProxyEnabled) {
      return SourceParseService.buildProxyUri(Uri.parse(url)).toString();
    }
    return url;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      children: [
        // 原图区域：加载中转圈占位，失败显示错误占位组件。
        Expanded(
          child: Center(
            child: CachedNetworkImage(
              imageUrl: _displayUrl(item.imageUrl),
              fit: BoxFit.contain,
              placeholder: (BuildContext context, String url) =>
                  const Center(child: CircularProgressIndicator()),
              errorWidget: (BuildContext context, String url, Object error) =>
                  const _ImageErrorPlaceholder(),
            ),
          ),
        ),
        // 标签列表（完整渲染 ImageItem.tags）。
        if (item.tags.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final String tag in item.tags)
                    Text(
                      '#$tag',
                      style: theme.textTheme.labelMedium
                          ?.copyWith(color: theme.colorScheme.primary),
                    ),
                ],
              ),
            ),
          ),
        // 底部来源地址小字（提供来源信息，兼容既有测试断言）。
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Text(
            item.imageUrl,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.outline),
          ),
        ),
      ],
    );
  }
}

/// 大图加载失败占位组件。
class _ImageErrorPlaceholder extends StatelessWidget {
  const _ImageErrorPlaceholder();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.broken_image_outlined,
          size: 64,
          color: theme.colorScheme.outline,
        ),
        const SizedBox(height: 12),
        Text(
          '图片加载失败',
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.outline),
        ),
      ],
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
        style: theme.textTheme.bodyMedium
            ?.copyWith(color: theme.colorScheme.outline),
      ),
    );
  }
}
