/// 图片保存结果：成功或携带可展示的错误信息（风格对齐 SourceParseResult）。
class ImageSaveResult {
  const ImageSaveResult._({this.errorMessage});

  /// 保存成功。
  const ImageSaveResult.success() : this._();

  /// 保存失败，[errorMessage] 为可直接展示给用户的中文提示。
  const ImageSaveResult.failure(String errorMessage)
      : this._(errorMessage: errorMessage);

  /// 错误信息（成功时为 null）。
  final String? errorMessage;

  /// 是否保存成功。
  bool get isSuccess => errorMessage == null;
}

/// 图片保存服务抽象接口（按平台实现）。
///
/// - Web 端：浏览器下载（见 image_downloader.dart 的条件导入实现）。
/// - Android：保存到系统相册（基于 gallery_saver_plus），
///   **具体存储实现留待后续轮次，本轮仅接口声明**。
abstract interface class ImageSaveService {
  /// 保存 [imageUrl] 指向的图片。
  ///
  /// [fileName] 可选；各平台实现自行处理默认文件名。
  Future<ImageSaveResult> saveImage({
    required String imageUrl,
    String? fileName,
  });
}
