import 'image_downloader_stub.dart'
    if (dart.library.js_interop) 'image_downloader_web.dart';
import 'image_save_service.dart';

export 'image_save_service.dart';

/// 创建当前平台的图片下载服务。
///
/// - Web 平台（`dart.library.js_interop`）：浏览器下载实现；
/// - 其他平台：stub（Android 真实存储实现留待后续轮次接入）。
ImageSaveService createImageDownloadService() => createDownloadService();
