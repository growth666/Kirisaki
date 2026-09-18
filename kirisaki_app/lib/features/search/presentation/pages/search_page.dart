import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/profile/search_history_service.dart';
import '../../../../core/source/builtin_sources.dart';
import '../../../../core/source/image_item.dart';
import '../../../../core/source/source_config.dart';
import '../../../../core/source/source_parse_result.dart';
import '../../../../core/source/source_parse_service.dart';
import '../../../../core/source/source_service.dart';
import '../widgets/thumbnail_image.dart';

/// 搜索页：关键词搜索 + 瀑布流图片列表 + 上拉分页。
class SearchPage extends StatefulWidget {
  const SearchPage({
    super.key,
    this.service,
    this.sourceService,
    this.autoLoadRecommend = true,
  });
  final SourceService? sourceService;

  /// 注入解析服务（测试用），默认使用真实网络。
  final SourceParseService? service;

  /// 是否默认进入自动加载推荐流（测试可关闭以保持既有行为）。
  final bool autoLoadRecommend;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage>
    with AutomaticKeepAliveClientMixin {
  late final SourceParseService _service =
      widget.service ?? SourceParseService();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  /// PageView 底部导航切换时保活：不重建、不丢滚动位置。
  @override
  bool get wantKeepAlive => true;

  // 搜索列表随共享图源服务刷新。
  late final SourceService _sourceService =
      widget.sourceService ?? SourceService.instance;
  List<SourceConfig> _sources = [];
  int _requestGeneration = 0;
  String? _sourceError;
  bool _sourcesReady = false;
  bool _openingPreview = false;
  SourceConfig? _selectedSource;

  final List<ImageItem> _items = <ImageItem>[];
  List<String> _suggestedTags = [];
  bool _loading = false; // 首页（重新搜索）加载中
  bool _loadingMore = false; // 分页加载中
  bool _hasMore = true;
  bool _searched = false; // 是否已发起过搜索（区分初始提示与空态）
  int _page = 1;
  String? _error; // 首页错误信息（非空时展示错误态）
  String? _lastKeyword; // 当前结果对应的关键词（分页复用）
  SourceConfig? _lastSource; // 当前结果对应的图源（分页复用）
  bool _recommendMode = false; // 当前是否处于推荐流模式

  /// 回到顶部按钮可见性（ValueNotifier 局部刷新：滚动只更新该值，
  /// 不触发整页 setState）。
  final ValueNotifier<bool> _showBackToTopNotifier = ValueNotifier<bool>(false);

  /// 回到顶部按钮显示阈值（滚动偏移超过该值显示）。
  static const double _backToTopThreshold = 600;

  @override
  void initState() {
    super.initState();
    _sources = _sourceService.enabled;
    _selectedSource = _sources.isNotEmpty ? _sources.first : null;
    _sourceService.addListener(_onSourcesChanged);
    _loadSources();
    _scrollController.addListener(_onScroll);
    if (widget.autoLoadRecommend) {
      // 默认进入自动加载推荐流（microtask 避开 initState 内 setState 限制）。
      Future<void>.microtask(_loadRecommend);
    }
    // 监听搜索历史快速搜索事件（搜索历史页点击条目触发）。
    SearchHistoryService.instance.addListener(_onHistoryQuickSearch);
  }

  @override
  void dispose() {
    if (widget.service == null) _service.close();
    _sourceService.removeListener(_onSourcesChanged);
    SearchHistoryService.instance.removeListener(_onHistoryQuickSearch);
    _showBackToTopNotifier.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadSources() async {
    try {
      await _sourceService.load();
      if (mounted) {
        setState(() {
          _sourcesReady = true;
          _sourceError = null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _sourceError = '加载图源失败：$error');
    }
  }

  void _clearSearch() {
    _requestGeneration++;
    _items.clear();
    _suggestedTags = [];
    _loading = false;
    _loadingMore = false;
    _page = 1;
    _hasMore = true;
    _error = null;
    _searched = false;
    _lastKeyword = null;
    _lastSource = null;
  }

  void _onSourcesChanged() {
    if (!mounted) return;
    final next = _sourceService.enabled;
    final old = _selectedSource;
    final matches = next.where((s) => s.id == old?.id);
    final selected = matches.isNotEmpty
        ? matches.first
        : (next.isEmpty ? null : next.first);
    final active = _lastSource;
    final activeMatches = next.where((s) => s.id == active?.id);
    final activeChanged =
        active != null &&
        !_recommendMode &&
        (activeMatches.isEmpty ||
            jsonEncode(active.toJson()) !=
                jsonEncode(activeMatches.first.toJson()));
    setState(() {
      _sources = next;
      _selectedSource = selected;
      if (activeChanged) _clearSearch();
    });
  }

  void _selectSource(SourceConfig source) {
    if (_selectedSource?.id == source.id && !_recommendMode) return;
    setState(() {
      _clearSearch();
      _selectedSource = source;
      _recommendMode = false;
    });
  }

  /// 搜索历史页点击条目 → 填入关键词并立即执行搜索。
  void _onHistoryQuickSearch() {
    final String? keyword = SearchHistoryService.instance.selectedKeyword;
    if (keyword == null) {
      return;
    }
    SearchHistoryService.instance.consumeSelection();
    _searchController.text = keyword;
    _search();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    // 距底部不足 400 逻辑像素时预加载下一页（约 1~2 屏提前量），
    // 避免滚到底部才触发加载造成等待。
    if (_scrollController.position.extentAfter < 400) {
      _loadMore();
    }
    // 回到顶部按钮：下滑超过阈值显示，到顶自动隐藏。
    // 仅更新 ValueNotifier，不触发整页 setState。
    final bool show = _scrollController.position.pixels > _backToTopThreshold;
    if (show != _showBackToTopNotifier.value) {
      _showBackToTopNotifier.value = show;
    }
  }

  Future<void> _search() async {
    _searchFocusNode.unfocus();
    if (!_sourcesReady) return;
    // 请求锁：加载中直接返回，防止连点搜索按钮重复发起请求。
    if (_loading) {
      return;
    }
    final SourceConfig? source = _selectedSource;
    // 关键词自动 trim；空关键词不发起任何请求，仅提示。
    final String keyword = _searchController.text.trim();
    if (source == null) {
      _showSnackBar('请先选择图源');
      return;
    }
    if (keyword.isEmpty) {
      _showSnackBar('请输入搜索关键词');
      return;
    }
    final generation = ++_requestGeneration;
    setState(() {
      _loading = true;
      _loadingMore = false;
      _error = null;
      _searched = true;
      _items.clear();
      _suggestedTags = [];
      _page = 1;
      _hasMore = true;
      _lastKeyword = keyword;
      _lastSource = source;
      _recommendMode = false; // 关键词搜索接管，退出推荐流模式
    });
    final SourceParseResult result = await _service.search(
      source,
      keyword: keyword,
      page: 1,
    );
    if (!mounted || generation != _requestGeneration) {
      return;
    }
    setState(() {
      _loading = false;
      if (result.isSuccess) {
        _suggestedTags = result.suggestedTags;
        _items.addAll(result.items);
        _hasMore = result.items.isNotEmpty;
      } else if (result.errorMessage == SourceParseService.noImagesMessage) {
        _error = null; // 无结果 → 空态
      } else {
        _error = result.errorMessage;
      }
    });
    // 搜索成功（关键词图源）后记录搜索历史（去重保留最新，持久化容错）。
    if (result.isSuccess && result.items.isNotEmpty) {
      SearchHistoryService.instance.add(keyword);
    }
  }

  Future<void> _loadMore() async {
    // 上拉分页请求锁：首页加载中/分页加载中/没有更多时均不重复触发。
    if (_loading || _loadingMore || !_hasMore) {
      return;
    }
    final SourceConfig? source = _lastSource;
    final String? keyword = _lastKeyword;
    // 推荐流无关键词；其余图源必须有关键词才可分页。
    if (source == null || (source.requiresKeyword && keyword == null)) {
      return;
    }
    setState(() => _loadingMore = true);
    final generation = _requestGeneration;
    final SourceParseResult result = await _service.search(
      source,
      keyword: keyword ?? '',
      page: _page + 1,
    );
    if (!mounted || generation != _requestGeneration) {
      return;
    }
    setState(() {
      _loadingMore = false;
      if (result.isSuccess) {
        _page += 1;
        _items.addAll(result.items);
        _hasMore = result.items.isNotEmpty;
      } else if (result.errorMessage == SourceParseService.noImagesMessage) {
        _hasMore = false; // 没有更多
      } else {
        _hasMore = false;
        _showSnackBar(result.errorMessage!);
      }
    });
  }

  Future<void> _openPreview(ImageItem item) async {
    if (_openingPreview) return;
    // Clear the route's focus history so popping preview cannot refocus input.
    _searchFocusNode.unfocus();
    final generation = _requestGeneration;
    setState(() => _openingPreview = true);
    try {
      final resolved = await _service.resolveImage(item);
      if (!mounted || generation != _requestGeneration) return;
      // Detail resolution may take time; dismiss any focus acquired meanwhile.
      _searchFocusNode.unfocus();
      final index = _items.indexOf(item);
      if (index >= 0) _items[index] = resolved;
      // url 参数兼容保留，extra 携带完整 ImageItem（含标签）供预览页渲染。
      context.push(
        '/preview?url=${Uri.encodeComponent(resolved.imageUrl)}',
        extra: resolved,
      );
    } catch (error) {
      if (mounted && generation == _requestGeneration) {
        _showSnackBar('获取原图失败：$error');
      }
    } finally {
      if (mounted) setState(() => _openingPreview = false);
    }
  }

  /// 加载推荐流：无需关键词，复用现有状态机/三态/分页逻辑。
  Future<void> _loadRecommend() async {
    // 请求锁复用：加载中不重复触发。
    if (_loading) {
      return;
    }
    final SourceConfig config = BuiltinSources.recommend;
    final generation = ++_requestGeneration;
    setState(() {
      _loading = true;
      _loadingMore = false;
      _error = null;
      _searched = true;
      _recommendMode = true;
      _suggestedTags = [];
      _items.clear();
      _page = 1;
      _hasMore = true;
      _lastKeyword = null;
      _lastSource = config;
    });
    final SourceParseResult result = await _service.search(config, keyword: '');
    if (!mounted || generation != _requestGeneration) {
      return;
    }
    setState(() {
      _loading = false;
      if (result.isSuccess) {
        _items.addAll(result.items);
        _hasMore = result.items.isNotEmpty;
      } else if (result.errorMessage == SourceParseService.noImagesMessage) {
        _error = null; // 空态
      } else {
        _error = result.errorMessage;
      }
    });
  }

  /// 平滑滚动回到顶部；到顶后 _onScroll 自动隐藏按钮。
  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('搜图'),
        actions: [
          // 图源管理页入口（含"导入图源"按钮）。
          IconButton(
            tooltip: '图源管理',
            icon: const Icon(Icons.tune),
            onPressed: () => context.push('/sources'),
          ),
        ],
      ),
      // 悬浮回到顶部按钮：ValueListenableBuilder 局部包裹，
      // 显隐只重建按钮本身；纯色半透明、无模糊混合。
      floatingActionButton: ValueListenableBuilder<bool>(
        valueListenable: _showBackToTopNotifier,
        builder: (BuildContext context, bool show, Widget? child) {
          if (!show) {
            return const SizedBox.shrink();
          }
          final ColorScheme colorScheme = Theme.of(context).colorScheme;
          return FloatingActionButton.small(
            tooltip: '回到顶部',
            backgroundColor: colorScheme.primary.withValues(alpha: 0.85),
            foregroundColor: colorScheme.onPrimary,
            onPressed: _scrollToTop,
            child: const Icon(Icons.keyboard_arrow_up),
          );
        },
      ),
      body: Column(
        children: [
          _buildFloatingHeader(),
          if (_openingPreview) const LinearProgressIndicator(),
          if (_sourceError != null)
            ListTile(
              title: Text(_sourceError!),
              trailing: IconButton(
                tooltip: '重试',
                onPressed: _loadSources,
                icon: const Icon(Icons.refresh),
              ),
            ),
          if (_sourcesReady && _sources.isEmpty)
            ListTile(
              title: const Text('暂无启用的搜索图源'),
              trailing: IconButton(
                tooltip: '图源管理',
                onPressed: () => context.push('/sources'),
                icon: const Icon(Icons.tune),
              ),
            ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  /// 固定悬浮导航区：搜索区 + 分类栏，列表滚动时不随动。
  /// 纯色背景（不透明 surface，无半透明效果）+ 极淡底部阴影（5% alpha）。
  Widget _buildFloatingHeader() {
    final ThemeData theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(children: [_buildSearchBar(), _buildCategoryBar()]),
    );
  }

  /// 图片分类栏：推荐 + 各内置图源（横向滚动 chips）。
  /// 高度自适应（不写死），避免窄视口下与搜索区叠加溢出。
  Widget _buildCategoryBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Row(
        children: [
          ChoiceChip(
            label: const Text('推荐'),
            selected: _recommendMode,
            onSelected: (_) => _loadRecommend(),
          ),
          for (final SourceConfig source in _sources) ...[
            const SizedBox(width: 8),
            ChoiceChip(
              label: Text(source.name),
              selected: !_recommendMode && _selectedSource?.id == source.id,
              onSelected: (_) {
                // 仅同步下拉框选中图源，不自动搜索（保持原图源选择逻辑）。
                _selectSource(source);
              },
            ),
          ],
        ],
      ),
    );
  }

  /// 顶部搜索区：关键词输入框 + 图源下拉框 + 搜索按钮。
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          Expanded(
            // 输入由 TextEditingController 局部管理，不触发整页 setState。
            child: TextField(
              key: const Key('searchInput'),
              controller: _searchController,
              focusNode: _searchFocusNode,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: const InputDecoration(
                hintText: '搜索关键词',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          DropdownMenu<SourceConfig>(
            key: ValueKey(jsonEncode(_selectedSource?.toJson())),
            enabled: _sourcesReady && _sources.isNotEmpty,
            initialSelection: _selectedSource,
            width: 140,
            requestFocusOnTap: false,
            label: const Text('图源'),
            onSelected: (SourceConfig? value) {
              if (value == null || value == _selectedSource) {
                return;
              }
              _selectSource(value);
            },
            dropdownMenuEntries: _sources
                .map(
                  (SourceConfig s) =>
                      DropdownMenuEntry<SourceConfig>(value: s, label: s.name),
                )
                .toList(),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            // 加载中禁用按钮（与 _search 入口的请求锁双保险）。
            onPressed: _loading || !_sourcesReady || _sources.isEmpty
                ? null
                : _search,
            tooltip: '搜索',
            icon: const Icon(Icons.arrow_forward),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _ErrorView(message: _error!, onRetry: _search);
    }
    if (!_searched) {
      return const _HintView(
        icon: Icons.travel_explore,
        message: '输入关键词，搜索二次元图片',
      );
    }
    if (_items.isEmpty) {
      if (_suggestedTags.isNotEmpty) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Text('该名字没有直接匹配的图片，请选择人物标签：'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final tag in _suggestedTags)
                    ActionChip(
                      label: Text(tag),
                      onPressed: () {
                        _searchController.text = tag;
                        _search();
                      },
                    ),
                ],
              ),
            ],
          ),
        );
      }
      return const _HintView(
        icon: Icons.image_not_supported_outlined,
        message: '没有找到相关图片，换个关键词试试',
      );
    }
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // 按可用宽度自适应列数（2~5 列），避免固定列数在宽屏/窄屏失衡。
        final int crossAxisCount = (constraints.maxWidth / 200).floor().clamp(
          2,
          5,
        );
        return CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              sliver: SliverMasonryGrid.count(
                crossAxisCount: crossAxisCount,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childCount: _items.length,
                itemBuilder: (BuildContext context, int index) {
                  final ImageItem item = _items[index];
                  return _ImageCard(
                    item: item,
                    onTap: () => _openPreview(item),
                    // 是否走代理随图源配置（ImageItem.useProxy）；
                    // 国内直连图源（推荐流/百度/必应）直连加载。
                    useProxy: item.useProxy,
                  );
                },
              ),
            ),
            SliverToBoxAdapter(child: _buildFooter()),
          ],
        );
      },
    );
  }

  /// 列表尾部：分页加载动画 / "没有更多了"提示。
  Widget _buildFooter() {
    final ThemeData theme = Theme.of(context);
    final Widget child;
    if (_loadingMore) {
      child = const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2.5),
      );
    } else if (!_hasMore) {
      child = Text(
        '没有更多了',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.outline,
        ),
      );
    } else {
      child = const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(child: child),
    );
  }
}

/// 瀑布流图片卡片：缩略图 + 标签。
class _ImageCard extends StatelessWidget {
  const _ImageCard({
    required this.item,
    required this.onTap,
    this.useProxy = true,
  });

  final ImageItem item;
  final VoidCallback onTap;

  /// 缩略图是否走 Web 代理（推荐流等直连图源传 false）。
  final bool useProxy;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String thumbnail = item.thumbnailUrl ?? item.imageUrl;
    final double aspectRatio =
        item.width != null &&
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
            // 图片区最小占位高度兜底（仅极扁横图生效），
            // 减少瀑布流网格在图片尺寸变化时的重排跳动。
            // 缩略图走内存缓存组件（ThumbnailImage），原图不接入缓存。
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 140),
              child: AspectRatio(
                aspectRatio: aspectRatio,
                child: ThumbnailImage(url: thumbnail, useProxy: useProxy),
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
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
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

/// 居中图标 + 文案提示（初始提示 / 空态）。
/// 内容外包 SingleChildScrollView：窄视口/小窗下可滚动，避免溢出。
class _HintView extends StatelessWidget {
  const _HintView({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: theme.colorScheme.outline),
            const SizedBox(height: 12),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 错误态：图标 + 错误信息 + 重试按钮。
/// 内容外包 SingleChildScrollView：窄视口/小窗下可滚动，避免溢出。
class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.wifi_off_outlined,
              size: 64,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}
