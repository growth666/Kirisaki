import 'dart:js_interop';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:web/web.dart' as web;

import '../source/source_parse_service.dart';
import 'image_save_service.dart';

/// 创建下载服务（Web 平台分支）。
ImageSaveService createDownloadService() => WebImageDownloadService();

/// Web 浏览器下载实现：fetch → Blob → 隐藏 anchor 触发下载。
///
/// 跨域图片必须经 [SourceParseService.buildProxyUri] 代理后 fetch，
/// 否则会被浏览器 CORS 拦截（与搜索请求/图片展示共用同一代理开关）。
class WebImageDownloadService implements ImageSaveService {
  @override
  Future<ImageSaveResult> saveImage({
    required String imageUrl,
    String? fileName,
  }) async {
    try {
      final String fetchUrl = kIsWeb && SourceParseService.webCorsProxyEnabled
          ? SourceParseService.buildProxyUri(Uri.parse(imageUrl)).toString()
          : imageUrl;

      final web.Response response = await web.window.fetch(fetchUrl.toJS).toDart;
      if (!response.ok) {
        return ImageSaveResult.failure(
          '下载失败：服务器响应异常（HTTP ${response.status}）',
        );
      }

      // JSArrayBuffer 来自 dart:js_interop（本文件顶部已导入），无 web. 前缀。
      final JSArrayBuffer buffer = await response.arrayBuffer().toDart;
      final web.Blob blob = web.Blob(
        <JSArrayBuffer>[buffer].toJS,
        web.BlobPropertyBag(type: 'application/octet-stream'),
      );
      _triggerDownload(blob, fileName ?? _fileNameFromUrl(imageUrl));
      return const ImageSaveResult.success();
    } catch (e) {
      return ImageSaveResult.failure('下载失败：$e');
    }
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
