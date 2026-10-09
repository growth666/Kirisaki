import 'image_save_service.dart';

/// 创建不支持下载的平台兜底服务。
ImageSaveService createDownloadService() => _StubImageDownloadService();

/// 无可用平台实现时返回明确的失败提示。
///
/// Android、桌面端和其他非 Web 平台的实现通过条件导入提供；
/// 此 stub 仅用于没有可用平台实现的目标。
class _StubImageDownloadService implements ImageSaveService {
  @override
  Future<ImageSaveResult> saveImage({
    required String imageUrl,
    String? fileName,
  }) async {
    return const ImageSaveResult.failure(
      '当前平台不支持图片下载',
    );
  }
}
