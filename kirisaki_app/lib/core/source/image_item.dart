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
    this.useProxy = true,
  });

  /// 原图地址（下载能力预留字段，本轮不实现下载逻辑）。
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

  /// Web 端是否走 CORS 代理（随图源配置 useWebCorsProxy 写入；
  /// 国内直连图源为 false，其图片在 Web 端直接加载）。
  final bool useProxy;

  /// 序列化为 JSON 对象（收藏持久化用）。
  Map<String, Object?> toJson() => <String, Object?>{
        'imageUrl': imageUrl,
        'thumbnailUrl': thumbnailUrl,
        'previewUrl': previewUrl,
        'width': width,
        'height': height,
        'sourcePage': sourcePage,
        'tags': tags,
        'useProxy': useProxy,
      };

  /// 从 JSON 对象恢复；缺失字段取默认值。
  factory ImageItem.fromJson(Map<String, Object?> json) => ImageItem(
        imageUrl: json['imageUrl'] as String,
        thumbnailUrl: json['thumbnailUrl'] as String?,
        previewUrl: json['previewUrl'] as String?,
        width: json['width'] as int?,
        height: json['height'] as int?,
        sourcePage: json['sourcePage'] as String?,
        tags: (json['tags'] as List<Object?>? ?? const <Object?>[])
            .map((Object? t) => '$t')
            .toList(),
        useProxy: json['useProxy'] as bool? ?? true,
      );
}
