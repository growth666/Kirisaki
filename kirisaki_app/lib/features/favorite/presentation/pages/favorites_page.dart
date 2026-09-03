import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/favorite/favorite_service.dart';
import '../../../../core/source/image_item.dart';
import '../../../search/presentation/widgets/thumbnail_image.dart';

/// 收藏页：网格展示已收藏图片，点击跳转复用现有大图预览页。
class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key, this.favoriteService});

  /// 注入的收藏服务（测试用），默认使用全局单例。
  final FavoriteService? favoriteService;

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  late final FavoriteService _service =
      widget.favoriteService ?? FavoriteService.instance;

  @override
  void initState() {
    super.initState();
    _service.load();
  }

  /// 复用现有预览路由：url 参数兼容保留，extra 携带完整 ImageItem。
  void _openPreview(ImageItem item) {
    context.push(
      '/preview?url=${Uri.encodeComponent(item.imageUrl)}',
      extra: item,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的收藏')),
      // 监听收藏服务：增删收藏后本页与预览页按钮状态实时同步。
      body: ListenableBuilder(
        listenable: _service,
        builder: (BuildContext context, Widget? child) {
          final List<ImageItem> items = _service.items;
          if (items.isEmpty) {
            return const _EmptyView();
          }
          return LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final int crossAxisCount =
                  (constraints.maxWidth / 200).floor().clamp(2, 5);
              return CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.all(12),
                    sliver: SliverMasonryGrid.count(
                      crossAxisCount: crossAxisCount,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childCount: items.length,
                      itemBuilder: (BuildContext context, int index) {
                        final ImageItem item = items[index];
                        return _FavoriteCard(
                          item: item,
                          onTap: () => _openPreview(item),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

/// 收藏卡片：缩略图（走内存缓存）+ 标签。
class _FavoriteCard extends StatelessWidget {
  const _FavoriteCard({required this.item, required this.onTap});

  final ImageItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String thumbnail = item.thumbnailUrl ?? item.imageUrl;
    final double aspectRatio = item.width != null &&
            item.height != null &&
            item.width! > 0 &&
            item.height! > 0
        ? item.width! / item.height!
        : 1.0;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 140),
              child: AspectRatio(
                aspectRatio: aspectRatio,
                child: ThumbnailImage(url: thumbnail),
              ),
            ),
            if (item.tags.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 2,
                  children: [
                    for (final String tag in item.tags.take(8))
                      Text(
                        '#$tag',
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: theme.colorScheme.primary),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 空态提示。
class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.favorite_border,
            size: 64,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: 12),
          Text(
            '暂无收藏',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.outline),
          ),
        ],
      ),
    );
  }
}
