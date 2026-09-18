import 'image_item.dart';

/// 一次图源解析的结果：成功携带图片列表，失败携带可展示的错误信息。
class SourceParseResult {
  const SourceParseResult._({
    this.items = const <ImageItem>[],
    this.errorMessage,
    this.suggestedTags = const <String>[],
  });

  /// 解析成功。
  const SourceParseResult.success(List<ImageItem> items) : this._(items: items);

  /// 解析失败，[errorMessage] 为可直接展示给用户的中文提示。
  const SourceParseResult.failure(String errorMessage)
    : this._(errorMessage: errorMessage);

  const SourceParseResult.suggestions(List<String> tags)
    : this._(suggestedTags: tags);

  final List<String> suggestedTags;

  /// 解析出的图片列表（失败时为空）。
  final List<ImageItem> items;

  /// 错误信息（成功时为 null）。
  final String? errorMessage;

  /// 是否解析成功。
  bool get isSuccess => errorMessage == null;
}
