import 'dart:convert';

import 'image_item.dart';

/// Moebooru 标准 `post.json` 响应解析器（纯解析工具，不做网络请求）。
///
/// 响应为 JSON 数组，元素结构示例：
/// ```json
/// {
///   "id": 403942,
///   "tags": "blue_sky cloud blue",
///   "file_url": "https://files.example/image.jpg",
///   "preview_url": "https://assets.example/data/preview/image.jpg",
///   "sample_url": "https://files.example/sample/image.jpg",
///   "jpeg_url": "https://files.example/jpeg/image.jpg",
///   "width": 1920,
///   "height": 1080
/// }
/// ```
///
/// 解析失败（JSON 结构错误）抛出 [FormatException]，由调用方
/// （SourceParseService）捕获后复用项目现有"解析失败"错误体系；
/// 超时/401/429/404/网络异常与三态 UI、重试按钮均复用现有实现。
abstract final class MoebooruJsonParser {
  /// 解析 Moebooru `post.json` 响应体为 [ImageItem] 列表。
  ///
  /// 顶层支持 JSON 数组，宽松兼容 `{"posts": [...]}` 包裹形式；
  /// 缺失关键图片地址的元素会被跳过。
  static List<ImageItem> parse(String body, {required Uri baseUri}) {
    final Object? decoded = jsonDecode(body);
    final List<Object?> posts;
    if (decoded is List<Object?>) {
      posts = decoded;
    } else if (decoded is Map<String, Object?> &&
        decoded['posts'] is List<Object?>) {
      posts = decoded['posts']! as List<Object?>;
    } else {
      throw const FormatException('JSON 顶层结构不是 post 列表');
    }

    final List<ImageItem> items = <ImageItem>[];
    for (final Object? entry in posts) {
      if (entry is! Map<String, Object?>) {
        continue;
      }
      final ImageItem? item = _mapPost(entry, baseUri);
      if (item != null) {
        items.add(item);
      }
    }
    return items;
  }

  static ImageItem? _mapPost(Map<String, Object?> post, Uri baseUri) {
    // 原图地址：file_url 优先，缺失时依次兜底 jpeg_url / sample_url。
    final String? fileUrl = _stringField(post['file_url']);
    final String? jpegUrl = _stringField(post['jpeg_url']);
    final String? sampleUrl = _stringField(post['sample_url']);
    final String imageUrl = fileUrl ?? jpegUrl ?? sampleUrl ?? '';
    if (imageUrl.isEmpty) {
      return null;
    }

    final Object? id = post['id'];
    final String? sourcePage =
        id == null ? null : baseUri.resolve('/post/show/$id').toString();

    return ImageItem(
      imageUrl: imageUrl,
      thumbnailUrl: _stringField(post['preview_url']),
      previewUrl: sampleUrl,
      width: _intField(post['width']),
      height: _intField(post['height']),
      sourcePage: sourcePage,
      tags: _parseTags(post['tags']),
    );
  }

  /// 标签：字符串按空白切分；数组形式逐元素转字符串；null/空白返回空数组。
  static List<String> _parseTags(Object? tags) {
    if (tags is List<Object?>) {
      return tags
          .map((Object? t) => '$t'.trim())
          .where((String s) => s.isNotEmpty)
          .toList();
    }
    final String? raw = _stringField(tags);
    if (raw == null || raw.trim().isEmpty) {
      return const <String>[];
    }
    return raw
        .trim()
        .split(RegExp(r'\s+'))
        .where((String s) => s.isNotEmpty)
        .toList();
  }

  static String? _stringField(Object? value) {
    if (value is String && value.trim().isNotEmpty) {
      return value;
    }
    return null;
  }

  static int? _intField(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }
}
