import 'source_config.dart';

/// 内置图源。
abstract final class BuiltinSources {
  /// 全部内置图源（搜索页下拉框数据源）。
  static final List<SourceConfig> all = <SourceConfig>[
    _moebooru(id: 'yande', name: 'yande.re', baseUrl: 'https://yande.re'),
    _moebooru(
      id: 'konachan',
      name: 'konachan.net',
      baseUrl: 'https://konachan.net',
    ),
    _moebooruJson(
      id: 'safebooru',
      name: 'Safebooru',
      baseUrl: 'https://safebooru.org',
    ),
    _moebooruJson(
      id: 'realbooru',
      name: 'Realbooru',
      baseUrl: 'https://realbooru.com',
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
  /// 注意：接口域名带 `Access-Control-Allow-Origin: *`，国内可直连，
  /// 故 `useWebCorsProxy: false` 跳过代理（Web 端 fetch 无 CORS 问题）；
  /// 图片同样位于 t.alcy.cc（同源），但响应不带 CORS 头，
  /// Web 端缩略图仍受浏览器限制，桌面/移动端直连可完整显示。
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
    extractRule: const ExtractRule(
      listSelector: 'li',
      imageUrl: FieldRule(),
    ),
  );

  /// Moebooru 引擎（yande.re / konachan.net）通用配置。
  ///
  /// 选择器按 Moebooru 官方模板核实：
  /// - 列表容器 `ul#post-list-posts > li`（注意不是 `li.post`，那是 Danbooru 系）
  /// - 缩略图 `a.thumb img.preview`（src；width/height 属性为预览等比尺寸）
  /// - 原图 `a.directlink`（href）
  /// - 标签不在独立节点里，藏在 `img.preview` 的 title 属性中：
  ///   `Rating: safe Score: 12 Tags: a b c User: x` → 正则切出后按空白拆分
  static SourceConfig _moebooru({
    required String id,
    required String name,
    required String baseUrl,
  }) {
    return SourceConfig(
      id: id,
      name: name,
      baseUrl: baseUrl,
      // Moebooru 支持 limit 参数（每页条数），一次多拉减少分页请求次数。
      searchUrlTemplate: '/post?tags={keyword}&page={page}&limit={limit}',
      perPage: 100,
      enabled: true,
      sourceType: SourceType.html,
      extractRule: ExtractRule(
        listSelector: 'ul#post-list-posts > li',
        imageUrl: const FieldRule(selector: 'a.directlink', attribute: 'href'),
        thumbnailUrl:
            const FieldRule(selector: 'a.thumb img.preview', attribute: 'src'),
        width: const FieldRule(
          selector: 'a.thumb img.preview',
          attribute: 'width',
        ),
        height: const FieldRule(
          selector: 'a.thumb img.preview',
          attribute: 'height',
        ),
        sourcePage: const FieldRule(selector: 'a.thumb', attribute: 'href'),
        tags: FieldRule(
          selector: 'a.thumb img.preview',
          attribute: 'title',
          regex: RegExp(r'Tags:\s*(.*?)(?:\s*User:.*)?$'),
        ),
      ),
    );
  }

  /// JSON 接口图源（按 Moebooru 标准 post.json 响应结构解析）。
  ///
  /// 注意：Safebooru / Realbooru 实际并非 Moebooru 引擎，
  /// 其真实接口为 dapi 且响应结构不同；上线验证若返回 404/解析失败，
  /// 只需按站点真实接口修改 searchUrlTemplate（解析器按 Moebooru 结构）。
  static SourceConfig _moebooruJson({
    required String id,
    required String name,
    required String baseUrl,
  }) {
    return SourceConfig(
      id: id,
      name: name,
      baseUrl: baseUrl,
      searchUrlTemplate: '/post.json?tags={keyword}&page={page}&limit={limit}',
      perPage: 100,
      enabled: true,
      sourceType: SourceType.json,
      // JSON 图源不使用 HTML 提取规则，占位仅为满足字段必填。
      extractRule: const ExtractRule(
        listSelector: 'li',
        imageUrl: FieldRule(),
      ),
    );
  }
}
