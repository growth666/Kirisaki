import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:web/web.dart' as web;

import '../source/source_parse_service.dart';
import 'image_save_service.dart';

/// 创建下载服务（Web 平台分支）。
ImageSaveService createDownloadService() => WebImageDownloadService();

/// Web 浏览器下载实现。
///
/// 自选下载位置链路（优先）：
/// 1. 浏览器支持 `showSaveFilePicker`（Chromium 系）→ 弹出系统保存
///    对话框**由用户自选位置**（需在用户点击手势内调用），随后拉取
///    图片字节写入所选文件；
/// 2. 用户取消对话框 → 返回"已取消下载"，不触发回退。
///
/// 回退链路（浏览器不支持该 API 时，原三级链路不变）：
/// 代理 URL fetch → 直连 URL fetch → 新标签页打开原图（可手动保存）。
/// 注释：Firefox/Safari 不支持 showSaveFilePicker，回退到浏览器默认
/// 下载目录行为。
class WebImageDownloadService implements ImageSaveService {
  @override
  Future<ImageSaveResult> saveImage({
    required String imageUrl,
    String? fileName,
  }) async {
    final String name = fileName ?? suggestedImageFileName(imageUrl);

    // 特性检测：支持则优先走"自选保存位置"链路。
    final JSObject windowObj = web.window as JSObject;
    if (windowObj.has('showSaveFilePicker')) {
      try {
        final web.FileSystemFileHandle handle = await _showSaveFilePicker(name);
        return await _saveToPickedHandle(handle, imageUrl);
      } catch (_) {
        // 用户取消（AbortError）或其他 JS 异常：视为取消，不回退下载。
        return const ImageSaveResult.failure('已取消下载');
      }
    }

    // —— 回退：既有三级链路（原逻辑不变）——
    final String? proxiedUrl = kIsWeb && SourceParseService.webCorsProxyEnabled
        ? SourceParseService.buildProxyUri(Uri.parse(imageUrl)).toString()
        : null;

    final List<String> candidates = <String>[?proxiedUrl, imageUrl];
    for (final String url in candidates) {
      try {
        final web.Response response = await web.window.fetch(url.toJS).toDart;
        if (!response.ok) {
          continue;
        }
        // JSArrayBuffer 来自 dart:js_interop（本文件顶部已导入），无 web. 前缀。
        final JSArrayBuffer buffer = await response.arrayBuffer().toDart;
        final web.Blob blob = web.Blob(
          <JSArrayBuffer>[buffer].toJS,
          web.BlobPropertyBag(type: 'application/octet-stream'),
        );
        _triggerDownload(blob, name);
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

  /// 弹系统保存对话框（动态调用，package:web 1.1.1 未绑定该 API；
  /// 需在用户点击手势内调用，取消会抛 JSException）。
  Future<web.FileSystemFileHandle> _showSaveFilePicker(
    String suggestedName,
  ) async {
    final JSAny? options = <String, Object?>{'suggestedName': suggestedName}
        .jsify();
    final JSPromise<JSAny?> promise = (web.window as JSObject)
        .callMethod<JSPromise<JSAny?>>('showSaveFilePicker'.toJS, options);
    final JSAny? result = await promise.toDart;
    if (result == null) {
      throw StateError('未获取到文件句柄');
    }
    return result as web.FileSystemFileHandle;
  }

  /// 用户选好位置后拉取图片字节并写入所选文件。
  Future<ImageSaveResult> _saveToPickedHandle(
    web.FileSystemFileHandle handle,
    String imageUrl,
  ) async {
    try {
      final String? proxiedUrl =
          kIsWeb && SourceParseService.webCorsProxyEnabled
          ? SourceParseService.buildProxyUri(Uri.parse(imageUrl)).toString()
          : null;
      web.Response? response;
      for (final String url in <String>[?proxiedUrl, imageUrl]) {
        try {
          final web.Response r = await web.window.fetch(url.toJS).toDart;
          if (r.ok) {
            response = r;
            break;
          }
        } catch (_) {
          // 尝试下一个候选地址。
        }
      }
      if (response == null) {
        return const ImageSaveResult.failure('下载失败：无法获取图片数据');
      }
      final JSArrayBuffer buffer = await response.arrayBuffer().toDart;
      final web.Blob blob = web.Blob(
        <JSArrayBuffer>[buffer].toJS,
        web.BlobPropertyBag(type: 'application/octet-stream'),
      );
      final web.FileSystemWritableFileStream writable = await handle
          .createWritable()
          .toDart;
      await writable.write(blob).toDart; // FileSystemWriteChunkType = JSAny
      await writable.close().toDart;
      return const ImageSaveResult.success(message: '已保存到所选位置');
    } catch (e) {
      return ImageSaveResult.failure('下载失败：$e');
    }
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
}
