import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/favorite/favorite_service.dart';
import '../../../../core/source/image_item.dart';
import '../../../search/presentation/widgets/thumbnail_image.dart';

/// 收藏页：网格展示已收藏图片（按收藏时间倒序，最新在前），
/// 顶部统计总数，支持长按多选批量删除；点击跳转复用现有大图预览页。
class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key, this.favoriteService});

  /// 注入的收藏服务（测试用），默认使用全局单例。
  final FavoriteService? favoriteService;

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage>
    with AutomaticKeepAliveClientMixin {
  late final FavoriteService _service =
      widget.favoriteService ?? FavoriteService.instance;

  /// PageView 底部导航切换时保活：不重建、不丢滚动位置。
  @override
  bool get wantKeepAlive => true;

  /// 长按多选模式开关。
  bool _selectionMode = false;

  /// 多选模式下已勾选的图片地址。
  final Set<String> _selectedUrls = <String>{};

  @override
  void initState() {
    super.initState();
    _service.load();
  }

  void _enterSelection(ImageItem item) {
    setState(() {
      _selectionMode = true;
      _selectedUrls.add(item.imageUrl);
    });
  }

  void _exitSelection() {
    setState(() {
      _selectionMode = false;
      _selectedUrls.clear();
    });
  }

  Future<void> _deleteSelected() async {
    await _service.removeAll(_selectedUrls);
    _exitSelection();
  }

  /// 复用现有预览路由：url 参数兼容保留，extra 携带完整 ImageItem。
  void _openPreview(ImageItem item) {
    context.push(
      '/preview?url=${Uri.encodeComponent(item.imageUrl)}',
      extra: item,
    );
  }

  void _onCardTap(ImageItem item) {
    if (_selectionMode) {
      // 选择模式下点击卡片 = 勾选/取消勾选。
      setState(() {
        if (!_selectedUrls.remove(item.imageUrl)) {
          _selectedUrls.add(item.imageUrl);
        }
      });
      return;
    }
    _openPreview(item);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: _selectionMode
          ? AppBar(
              leading: IconButton(
                tooltip: '取消',
                icon: const Icon(Icons.close),
                onPressed: _exitSelection,
              ),
              title: Text('已选 ${_selectedUrls.length} 张'),
              actions: [
                IconButton(
                  tooltip: '删除',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: _selectedUrls.isEmpty ? null : _deleteSelected,
                ),
              ],
            )
          : AppBar(title: const Text('我的收藏')),
      body: ListenableBuilder(
        listenable: _service,
        builder: (BuildContext context, Widget? child) {
          // 注意：必须在 builder 内实时读取（外层闭包捕获的快照会过期，
          // 导致 load() 完成后列表不刷新）。
          final List<ImageItem> items = _service.items;
          // 按收藏时间倒序（最新收藏在前）。
          final List<ImageItem> ordered = items.reversed.toList();
          if (items.isEmpty) {
            // 非选择模式下空态展示占位引导。
            return _selectionMode ? const SizedBox.shrink() : const _EmptyView();
          }
          return Column(
            children: [
              // 收藏总数统计（实时更新）。
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '共 ${ordered.length} 张',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                ),
              ),
              Expanded(
                child: LayoutBuilder(
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
                            childCount: ordered.length,
                            itemBuilder: (BuildContext context, int index) {
                              final ImageItem item = ordered[index];
                              return _FavoriteCard(
                                // 按内容匹配 Element：新收藏头插导致整体移位时，
                                // State（含缩略图）跟随 item 而非位置，避免图片错位。
                                key: ValueKey<String>(item.imageUrl),
                                item: item,
                                selectionMode: _selectionMode,
                                selected: _selectedUrls.contains(item.imageUrl),
                                onTap: () => _onCardTap(item),
                                onLongPress: () => _enterSelection(item),
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 收藏卡片：缩略图（走内存缓存）+ 标签；多选模式下显示勾选角标。
class _FavoriteCard extends StatelessWidget {
  const _FavoriteCard({
    super.key,
    required this.item,
    required this.selectionMode,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
  });

  final ImageItem item;
  final bool selectionMode;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

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
        onLongPress: onLongPress,
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 140),
                  child: AspectRatio(
                    aspectRatio: aspectRatio,
                    child: ThumbnailImage(url: thumbnail, useProxy: item.useProxy),
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
            // 多选模式下右上角勾选角标；选中态叠加半透明遮罩。
            if (selectionMode)
              Positioned(
                top: 6,
                right: 6,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: selected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.surface.withValues(alpha: 0.8),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    selected ? Icons.check : Icons.circle_outlined,
                    size: 22,
                    color: selected
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.outline,
                  ),
                ),
              ),
            if (selectionMode && selected)
              Positioned.fill(
                child: ColoredBox(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
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
