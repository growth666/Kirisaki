import 'source_config.dart';

/// Official search endpoints; live verification is recorded in docs/source-verification.md.
abstract final class BuiltinSources {
  static final List<SourceConfig> all = <SourceConfig>[
    _json(
      id: 'safebooru',
      name: 'Safebooru',
      baseUrl: 'https://safebooru.org',
      template: '/index.php?page=dapi&s=post&q=index&json=1&tags={keyword}&limit={limit}&pid={page}',
      format: SourceJsonFormat.gelbooru,
      pageOffset: -1,
    ),
    _json(
      id: 'danbooru_safe',
      name: 'Danbooru (Safe)',
      baseUrl: 'https://safebooru.donmai.us',
      template: '/posts.json?tags={keyword}&limit={limit}&page={page}',
      format: SourceJsonFormat.danbooru,
    ),
    _json(
      id: 'zerochan',
      name: 'Zerochan',
      baseUrl: 'https://www.zerochan.net',
      template: '/{keyword}?json&p={page}&l={limit}',
      format: SourceJsonFormat.zerochan,
    ),
  ];

  /// 首页推荐流图源（国内可直连的随机二次元图源）。
  ///
  /// **不加入 [all]**（不出现在搜索下拉框），仅供推荐流使用，
  /// 不影响原有图源选择逻辑。
  ///
  /// 接口实测：`https://t.alcy.cc/json?pc=N`（**注意无尾斜杠**——
  /// 源站改版后 `/json/` 路由返回 404，无斜杠路径直接 200），
  /// 返回 `{"data":[{"link":"https://t.alcy.cc/pic/..."}]}`
  /// —— 列表键 `data`、地址字段 `link`（图片与 API 同源，国内可直连）。
  /// `perPage` 即 `pc` 参数（每次返回张数），可按主页列数调整。
  /// 上拉分页 = 再次请求随机接口追加新图（接口每次随机返回，天然"下滑更新"）。
  ///
  /// 注意：
  /// - `useWebCorsProxy: false` 国内可直连（不走 Web 代理）；
  /// - **2026-09-11 实测：源站对带 Origin 的请求不再返回
  ///   Access-Control-Allow-Origin 头（已移除 CORS 支持）**，
  ///   Web 端推荐流（搜索请求与图片加载）受浏览器 CORS 限制无法使用；
  ///   桌面/移动端原生请求不受影响，直连正常。
  /// - 模板保持 `/json?pc={limit}`（无斜杠为当前唯一 200 路径，
  ///   `/json/` 已 404）。
  static final SourceConfig recommend = SourceConfig(
    id: 'alcy_recommend',
    name: '推荐',
    baseUrl: 'https://t.alcy.cc',
    searchUrlTemplate: '/json?pc={limit}',
    perPage: 18,
    enabled: true,
    useWebCorsProxy: false,
    sourceType: SourceType.json,
    requiresKeyword: false,
    jsonListKey: 'data',
    jsonFieldMapping: const <String, String>{
      'file_url': 'link',
      'preview_url': 'link',
    },
    // JSON 图源不使用 HTML 提取规则，占位仅为满足字段必填。
    extractRule: const ExtractRule(listSelector: 'li', imageUrl: FieldRule()),
  );

  static SourceConfig _json({
    required String id,
    required String name,
    required String baseUrl,
    required String template,
    required SourceJsonFormat format,
    int pageOffset = 0,
  }) => SourceConfig(
    id: id,
    name: name,
    baseUrl: baseUrl,
    searchUrlTemplate: template,
    sourceType: SourceType.json,
    jsonFormat: format,
    pageOffset: pageOffset,
    perPage: 24,
    timeout: const Duration(seconds: 20),
    userAgent: 'Kirisaki/1.0 (image search client)',
    extractRule: const ExtractRule(listSelector: 'li', imageUrl: FieldRule()),
  );
}
