import 'image_save_service.dart';

/// 创建下载服务（非 Web 平台分支）。
ImageSaveService createDownloadService() => _StubImageDownloadService();

/// 非 Web 平台 stub：浏览器下载不可用。
///
/// Android 真实存储实现（基于 gallery_saver_plus 保存到系统相册）
/// 留待后续轮次接入，届时替换本 stub。
class _StubImageDownloadService implements ImageSaveService {
  @override
  Future<ImageSaveResult> saveImage({
    required String imageUrl,
    String? fileName,
  }) async {
    return const ImageSaveResult.failure(
      '当前平台不支持浏览器下载（Android 存储实现后续轮次接入）',
    );
  }
}
