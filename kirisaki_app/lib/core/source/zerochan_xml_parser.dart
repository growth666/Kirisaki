import 'package:xml/xml.dart';

/// Convert the official RSS response to the same fields as the JSON endpoint.
/// Keep the sample separate from the original, which still needs a detail GET.
abstract final class ZerochanXmlParser {
  static Map<String, Object?> parse(String body, Uri base) {
    final document = XmlDocument.parse(body);
    if (document.rootElement.name.local != 'rss') {
      throw const FormatException('不是 Zerochan RSS 数据');
    }
    final channel = document.rootElement.getElement('channel');
    if (channel == null) throw const FormatException('缺少 RSS channel');
    const media = 'http://search.yahoo.com/mrss/';
    final items = <Map<String, Object?>>[];
    for (final entry in channel.findElements('item')) {
      final link = Uri.tryParse(
        entry.getElement('link')?.innerText.trim() ?? '',
      );
      final id = link == null
          ? null
          : int.tryParse(link.path.replaceFirst('/', ''));
      if (link == null || link.host != base.host || id == null) {
        throw const FormatException('RSS 图片链接无效');
      }
      final content = entry.getElement('content', namespace: media);
      items.add({
        'id': id,
        'tag': entry.getElement('title')?.innerText ?? '',
        'thumbnail': entry
            .getElement('thumbnail', namespace: media)
            ?.getAttribute('url'),
        'sample': content?.getAttribute('url'),
        'width': content?.getAttribute('width'),
        'height': content?.getAttribute('height'),
        'tags':
            (entry.getElement('keywords', namespace: media)?.innerText ?? '')
                .split(',')
                .map((tag) => tag.trim())
                .where((tag) => tag.isNotEmpty)
                .toList(),
        'rating': entry
            .getElement('rating', namespace: media)
            ?.innerText
            .trim(),
      });
    }
    return {'items': items};
  }
}
