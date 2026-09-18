import 'dart:convert';

import 'image_item.dart';
import 'source_config.dart';

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
  /// 顶层支持 JSON 数组；对象形式按 [listKey]（默认 'posts'，可配
  /// 'data' 等）取列表；[fieldMapping] 为「解析器标准键 → 响应键」的
  /// 字段映射（如 {'file_url': 'link'}），缺失关键图片地址的元素跳过。
  static List<ImageItem> parse(
    String body, {
    required Uri baseUri,
    String? listKey,
    Map<String, String>? fieldMapping,
    bool itemUseProxy = true,
    SourceJsonFormat format = SourceJsonFormat.moebooru,
  }) {
    final Object? decoded = jsonDecode(body);
    final List<Object?> posts;
    if (decoded is List<Object?>) {
      posts = decoded;
    } else if (decoded is Map<String, Object?>) {
      // Zerochan returns {} for tag disambiguation pages (for example Rem).
      if (format == SourceJsonFormat.zerochan && decoded.isEmpty) return [];
      final Object? list =
          decoded[listKey ??
              (format == SourceJsonFormat.zerochan ? 'items' : 'posts')];
      if (list is List<Object?>) {
        posts = list;
      } else {
        throw const FormatException('JSON 顶层结构不是 post 列表');
      }
    } else {
      throw const FormatException('JSON 顶层结构不是 post 列表');
    }

    final List<ImageItem> items = <ImageItem>[];
    for (final Object? entry in posts) {
      if (entry is! Map<String, Object?>) {
        continue;
      }
      final ImageItem? item = _mapPost(
        entry,
        baseUri,
        fieldMapping,
        itemUseProxy,
        format,
      );
      if (item != null) {
        items.add(item);
      }
    }
    return items;
  }

  static ImageItem? _mapPost(
    Map<String, Object?> post,
    Uri baseUri,
    Map<String, String>? fieldMapping,
    bool itemUseProxy,
    SourceJsonFormat format,
  ) {
    final id = post['id'];
    if (format == SourceJsonFormat.zerochan) {
      if (id is! int || post['tag'] is! String) return null;
      final thumbnail = Uri.https(
        's1.zerochan.net',
        '/${(post['tag'] as String).replaceAll(' ', '.')}.600.$id.jpg',
      ).toString();
      final page = baseUri.resolve('/$id').toString();
      return ImageItem(
        imageUrl: page,
        thumbnailUrl: thumbnail,
        detailUrl: baseUri.resolve('/$id?json').toString(),
        sourcePage: page,
        width: _intField(post['width']),
        height: _intField(post['height']),
        tags: _parseTags(post['tags']),
        useProxy: itemUseProxy,
      );
    }
    post = Map<String, Object?>.of(post);
    if (format == SourceJsonFormat.danbooru) {
      post.addAll({
        'preview_url': post['preview_file_url'],
        'sample_url': post['large_file_url'],
        'width': post['image_width'],
        'height': post['image_height'],
        'tags': post['tag_string'],
      });
    }
    if (format == SourceJsonFormat.gelbooru &&
        _stringField(post['file_url']) == null) {
      final directory = post['directory'];
      final image = _stringField(post['image']);
      if (directory != null && image != null) {
        post['file_url'] = baseUri
            .resolve('/images/$directory/$image')
            .toString();
        final stem = image.contains('.')
            ? image.substring(0, image.lastIndexOf('.'))
            : image;
        post['preview_url'] = baseUri
            .resolve('/thumbnails/$directory/thumbnail_$stem.jpg')
            .toString();
      }
    }
    // 字段映射：把映射目标（响应键）的值写入解析器标准键，
    // 例如 {'file_url': 'link'} → file_url 取 link 的值；
    // 默认无映射时行为与 Moebooru 原生结构完全一致。
    Map<String, Object?> lookup = post;
    if (fieldMapping != null && fieldMapping.isNotEmpty) {
      lookup = Map<String, Object?>.of(post);
      for (final MapEntry<String, String> m in fieldMapping.entries) {
        if (lookup.containsKey(m.value)) {
          lookup[m.key] = lookup[m.value];
        }
      }
    }

    // 原图地址：file_url 优先，缺失时依次兜底 jpeg_url / sample_url。
    final String? fileUrl = _stringField(lookup['file_url']);
    final String? jpegUrl = _stringField(lookup['jpeg_url']);
    final String? sampleUrl = _stringField(lookup['sample_url']);
    final String imageUrl = fileUrl ?? jpegUrl ?? sampleUrl ?? '';
    if (imageUrl.isEmpty) {
      return null;
    }

    final String? sourcePage = id == null
        ? null
        : baseUri.resolve(switch (format) {
            SourceJsonFormat.danbooru => '/posts/$id',
            SourceJsonFormat.gelbooru => '/index.php?page=post&s=view&id=$id',
            _ => '/post/show/$id',
          }).toString();

    return ImageItem(
      imageUrl: baseUri.resolve(imageUrl).toString(),
      thumbnailUrl: _stringField(lookup['preview_url']) == null
          ? null
          : baseUri.resolve(lookup['preview_url'] as String).toString(),
      previewUrl: sampleUrl == null
          ? null
          : baseUri.resolve(sampleUrl).toString(),
      width: _intField(lookup['width']),
      height: _intField(lookup['height']),
      sourcePage: sourcePage,
      tags: _parseTags(lookup['tags']),
      useProxy: itemUseProxy,
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
