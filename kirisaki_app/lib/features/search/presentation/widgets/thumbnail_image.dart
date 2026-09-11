import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../../core/cache/thumbnail_memory_cache.dart';
import '../../../../core/network/http_client_factory.dart';
import '../../../../core/source/source_parse_service.dart';

/// 带内存缓存的缩略图组件。
///
/// 首次加载：按全局代理开关转换 URL → 请求 → 成功后写入
/// [ThumbnailMemoryCache] 并展示；后续相同 URL 直接命中内存缓存，
/// 避免重复请求相同缩略资源。
///
/// **仅用于缩略图**；预览页原图继续使用 CachedNetworkImage，
/// 不接入内存缓存。
class ThumbnailImage extends StatefulWidget {
  const ThumbnailImage({
    super.key,
    required this.url,
    this.client,
    this.cache,
    this.useProxy = true,
  });

  /// 原始缩略图地址（按 [useProxy] 决定是否经全局代理开关转换）。
  final String url;

  /// 注入的 HTTP client（测试用），默认使用真实 client。
  final http.Client? client;

  /// 注入的缓存实例（测试用），默认使用全局单例。
  final ThumbnailMemoryCache? cache;

  /// Web 端是否走 CORS 代理（默认 true 沿用全局开关语义；
  /// 国内可直连的图源（如推荐流）传 false 直连）。
  final bool useProxy;

  @override
  State<ThumbnailImage> createState() => _ThumbnailImageState();
}

class _ThumbnailImageState extends State<ThumbnailImage> {
  late final http.Client _client = widget.client ?? buildClient();
  late final ThumbnailMemoryCache _cache =
      widget.cache ?? ThumbnailMemoryCache.instance;

  Uint8List? _bytes; // 已加载的图片字节（命中缓存或请求成功）
  bool _failed = false; // 请求失败标记（展示错误图标占位）

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ThumbnailImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 列表项复用（如收藏页新收藏导致整体移位）时 url 变化，
    // 必须重置图片字节并重新加载，否则会显示上一项的旧图。
    if (oldWidget.url != widget.url ||
        oldWidget.useProxy != widget.useProxy) {
      _bytes = null;
      _failed = false;
      _load();
    }
  }

  /// Web 端缩略图走全局 CORS 代理（与搜索请求一致），原生平台直连。
  /// 该开关与 SourceParseService.webCorsProxyEnabled 保持一致。
  static String _displayUrl(String url) {
    if (kIsWeb && SourceParseService.webCorsProxyEnabled) {
      return SourceParseService.buildProxyUri(Uri.parse(url)).toString();
    }
    return url;
  }

  Future<void> _load() async {
    final String key =
        widget.useProxy ? _displayUrl(widget.url) : widget.url;
    // 命中内存缓存：直接展示，不发请求。
    final Uint8List? cached = _cache.get(key);
    if (cached != null) {
      setState(() => _bytes = cached);
      return;
    }

    try {
      final http.Response response = await _client
          .get(Uri.parse(key))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        throw http.ClientException('HTTP ${response.statusCode}');
      }
      final Uint8List bytes = response.bodyBytes;
      // 仅缩略图写入内存缓存（原图不走本组件）。
      _cache.put(key, bytes);
      if (!mounted) {
        return;
      }
      setState(() => _bytes = bytes);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Uint8List? bytes = _bytes;
    if (bytes != null) {
      return Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true);
    }
    // 加载中/未开始：灰色占位；失败：错误图标占位。
    return ColoredBox(
      color: theme.colorScheme.surfaceContainerHighest,
      child: _failed
          ? Icon(
              Icons.broken_image_outlined,
              color: theme.colorScheme.outline,
            )
          : null,
    );
  }
}
