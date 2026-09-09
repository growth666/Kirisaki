import 'dart:js_interop';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:web/web.dart' as web;

import '../source/source_parse_service.dart';
import 'image_save_service.dart';

/// 创建下载服务（Web 平台分支）。
ImageSaveService createDownloadService() => WebImageDownloadService();

/// Web 浏览器下载实现：fetch → Blob → 隐藏 anchor 触发下载。
///
/// 下载链路依次尝试：
/// 1. 代理 URL fetch（跨域图片必须经 [SourceParseService.buildProxyUri]，
///    与搜索请求/图片展示共用同一代理开关）；
/// 2. 直连 URL fetch（国内可直连且带 CORS 头的图源，如推荐图源）；
/// 3. 兜底：新标签页打开原图（页面导航不受 CORS 限制，可手动保存）。
class WebImageDownloadService implements ImageSaveService {
  @override
  Future<ImageSaveResult> saveImage({
    required String imageUrl,
    String? fileName,
  }) async {
    final String? proxiedUrl =
        kIsWeb && SourceParseService.webCorsProxyEnabled
            ? SourceParseService.buildProxyUri(Uri.parse(imageUrl)).toString()
            : null;

    final List<String> candidates = <String>[?proxiedUrl, imageUrl];
    for (final String url in candidates) {
      try {
        final web.Response response =
            await web.window.fetch(url.toJS).toDart;
        if (!response.ok) {
          continue;
        }
        // JSArrayBuffer 来自 dart:js_interop（本文件顶部已导入），无 web. 前缀。
        final JSArrayBuffer buffer = await response.arrayBuffer().toDart;
        final web.Blob blob = web.Blob(
          <JSArrayBuffer>[buffer].toJS,
          web.BlobPropertyBag(type: 'application/octet-stream'),
        );
        _triggerDownload(blob, fileName ?? _fileNameFromUrl(imageUrl));
        return const ImageSaveResult.success();
      } catch (_) {
        // 尝试下一个候选地址。
      }
    }

    // 兜底：图片源站不带 CORS 头时浏览器无法 fetch，
    // 改为新标签页打开（页面导航不受 CORS 限制），用户可手动保存。
    _openInNewTab(imageUrl);
    return const ImageSaveResult.success(
      message: '已在新标签页打开原图（浏览器限制无法直接下载），可手动保存',
    );
  }

  /// 新标签页打开原图。
  void _openInNewTab(String url) {
    web.window.open(url, '_blank');
  }

  /// 创建隐藏 anchor 触发浏览器下载，随后释放 object URL。
  void _triggerDownload(web.Blob blob, String name) {
    final String objectUrl = web.URL.createObjectURL(blob);
    web.HTMLAnchorElement()
      ..href = objectUrl
      ..download = name
      ..click();
    web.URL.revokeObjectURL(objectUrl);
  }

  /// 从图片 URL 末段提取文件名；无扩展名时使用通用兜底名。
  static String _fileNameFromUrl(String url) {
    final Uri uri = Uri.parse(url);
    final String? last =
        uri.pathSegments.isNotEmpty ? uri.pathSegments.last : null;
    if (last == null || last.isEmpty || !last.contains('.')) {
      return 'image.bin';
    }
    return last;
  }
}
