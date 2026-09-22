/// 图片保存结果：成功或携带可展示的错误信息（风格对齐 SourceParseResult）。
class ImageSaveResult {
  const ImageSaveResult._({this.errorMessage, this.message});

  /// 保存成功（[message] 为可选附加提示，如"已在新标签页打开"）。
  const ImageSaveResult.success({String? message}) : this._(message: message);

  /// 保存失败，[errorMessage] 为可直接展示给用户的中文提示。
  const ImageSaveResult.failure(String errorMessage)
    : this._(errorMessage: errorMessage);

  /// 错误信息（成功时为 null）。
  final String? errorMessage;

  /// 成功时的附加提示（可选）。
  final String? message;

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

/// 生成跨平台安全的建议文件名。
String suggestedImageFileName(String imageUrl, {String? sourceName, int? id}) {
  final uri = Uri.tryParse(imageUrl);
  final host = (sourceName ?? uri?.host ?? 'image').replaceAll(
    RegExp(r'[^A-Za-z0-9一-龥_-]+'),
    '_',
  );
  final segments =
      uri?.pathSegments.where((s) => s.isNotEmpty).toList() ?? const <String>[];
  final last = segments.isEmpty ? null : segments.last;
  final pathId = id?.toString() ?? (last ?? 'image').split('.').first;
  final safeId = pathId.replaceAll(RegExp(r'[^A-Za-z0-9一-龥_-]+'), '_');
  var ext = '';
  if (last != null && last.contains('.')) {
    ext = last.substring(last.lastIndexOf('.')).toLowerCase();
  }
  if (!RegExp(r'^\.(jpe?g|png|webp|gif|bmp|avif)$').hasMatch(ext)) ext = '.jpg';
  return 'Kirisaki_${host.isEmpty ? 'image' : host}_${safeId.isEmpty ? 'image' : safeId}$ext';
}
