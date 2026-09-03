/// 图源接口类型。
enum SourceType {
  /// 抓取 HTML 页面并用 CSS 选择器解析。
  html,

  /// 请求 JSON 接口（Moebooru 标准 post.json）。
  json,
}

/// 图源配置。
///
/// 描述一个图源站点的搜索地址模板与 HTML 提取规则，
/// 供 [SourceParseService] 抓取并解析。
class SourceConfig {
  const SourceConfig({
    required this.id,
    required this.name,
    required this.baseUrl,
    required this.searchUrlTemplate,
    required this.extractRule,
    this.timeout = const Duration(seconds: 10),
    this.userAgent = defaultUserAgent,
    this.useWebCorsProxy = true,
    this.perPage,
    this.enabled = true,
    this.sourceType = SourceType.html,
  });

  /// 默认请求 UA（部分图源会拦截 Dart 默认 UA）。
  static const String defaultUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/127.0.0.0 Safari/537.36';

  /// 图源唯一标识。
  final String id;

  /// 图源名称（展示用）。
  final String name;

  /// 站点根地址，用于把提取出的相对链接解析为绝对地址。
  final String baseUrl;

  /// 搜索地址模板，支持占位符：
  /// - `{keyword}`：搜索关键词（自动 URL 编码）
  /// - `{page}`：页码
  /// - `{limit}`：每页条数（取 [perPage]，为 null 时替换为空字符串）
  final String searchUrlTemplate;

  /// HTML 图片列表提取规则。
  final ExtractRule extractRule;

  /// 请求超时时间（推荐 8~12s，默认 10s）。
  final Duration timeout;

  /// 请求 User-Agent。
  final String userAgent;

  /// Web 端是否使用 CORS 代理（仅 Web 端生效，Android 等原生平台忽略）。
  final bool useWebCorsProxy;

  /// 每页条数（对应模板 `{limit}` 占位符）；为 null 时不参与分页请求。
  final int? perPage;

  /// 图源启用开关（禁用图源不出现在搜索下拉框，图源管理页后续轮次可动态启停）。
  final bool enabled;

  /// 图源接口类型（默认 [SourceType.html]，现有配置与测试零改动）。
  final SourceType sourceType;
}

/// HTML 图片列表提取规则（CSS 选择器）。
class ExtractRule {
  const ExtractRule({
    required this.listSelector,
    required this.imageUrl,
    this.thumbnailUrl,
    this.previewUrl,
    this.width,
    this.height,
    this.sourcePage,
    this.tags,
  });

  /// 图片节点列表选择器，如 `li.post`。
  final String listSelector;

  /// 图片地址（必填，缺失该字段的节点会被跳过）。
  final FieldRule imageUrl;

  /// 缩略图地址。
  final FieldRule? thumbnailUrl;

  /// 预览图地址。
  final FieldRule? previewUrl;

  /// 图片宽度（像素）。
  final FieldRule? width;

  /// 图片高度（像素）。
  final FieldRule? height;

  /// 原图所在详情页地址。
  final FieldRule? sourcePage;

  /// 图片标签（多值规则：全部匹配节点的取值经正则后按空白切分）。
  final FieldRule? tags;
}

/// 单个字段的提取规则。
///
/// 在图片节点容器内按 [selector] 定位元素，取 [attribute] 属性值
/// 或元素文本（[useText]）；URL 类字段会按图源 baseUrl 解析相对地址。
class FieldRule {
  const FieldRule({
    this.selector,
    this.attribute,
    this.useText = false,
    this.resolveUrl = true,
    this.regex,
  });

  /// 容器内相对 CSS 选择器；为 null 时表示节点容器本身。
  final String? selector;

  /// 取值属性名（如 `data-src`、`href`）；
  /// 未指定且非文本取值时，默认依次尝试 `src`、`href`。
  final String? attribute;

  /// 为 true 时取元素文本（用于宽度/高度等数值字段）。
  final bool useText;

  /// 为 true 时按图源 baseUrl 把相对地址解析为绝对地址；
  /// 数值/文本字段应设为 false。
  final bool resolveUrl;

  /// 对取值先做正则提取（取第一个捕获组），再进入后续处理。
  /// 例如从 Moebooru 的 `title` 属性中切出 Tags 段。
  final RegExp? regex;
}
