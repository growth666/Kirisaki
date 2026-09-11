import 'image_downloader_stub.dart'
    if (dart.library.js_interop) 'image_downloader_web.dart'
    if (dart.library.io) 'image_downloader_io.dart';
import 'image_save_service.dart';

export 'image_save_service.dart';

/// 创建当前平台的图片下载服务（业务层统一入口，不感知平台差异）。
///
/// - Web 平台（`dart.library.js_interop`）：浏览器下载实现；
/// - 原生平台（`dart.library.io`）：Windows/Linux/macOS 写系统下载目录，
///   Android 走 MediaStore 通道（基础实现）；
/// - 其他平台：stub 兜底。
ImageSaveService createImageDownloadService() => createDownloadService();
