/// 解析出的单张图片。
class ImageItem {
  const ImageItem({
    required this.imageUrl,
    this.thumbnailUrl,
    this.previewUrl,
    this.width,
    this.height,
    this.sourcePage,
    this.tags = const <String>[],
  });

  /// 图片地址。
  final String imageUrl;

  /// 缩略图地址（网格列表展示用）。
  final String? thumbnailUrl;

  /// 预览图地址。
  final String? previewUrl;

  /// 图片宽度（像素）。
  final int? width;

  /// 图片高度（像素）。
  final int? height;

  /// 原图所在页面地址。
  final String? sourcePage;

  /// 图片标签。
  final List<String> tags;
}
