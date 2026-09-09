import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

import 'image_item.dart';
import 'moebooru_json_parser.dart';
import 'source_config.dart';
import 'source_parse_result.dart';

/// 图源解析服务：抓取图源搜索页 HTML，按 CSS 选择器规则解析出图片列表。
///
/// 任何失败（配置错误/超时/网络/解析）都会以 [SourceParseResult.failure]
/// 返回，不抛异常，UI 可直接展示 [SourceParseResult.errorMessage]。
///
/// 网络说明：海外 booru 站点（无论 HTML 还是 JSON 接口）从国内网络
/// 裸请求极易触发 Cloudflare 拦截（401/403）；Web 端正常访问必须依赖
/// [webCorsProxyEnabled]/[webCorsProxyPrefix] 的代理转发。
class SourceParseService {
  /// 使用注入的 [client] 便于测试（默认使用真实 [http.Client]）。
  SourceParseService({http.Client? client}) : _client = client ?? http.Client();

  /// 未解析到图片时的错误信息（分页时可用作"没有更多"的判断）。
  static const String noImagesMessage = '未解析到图片，图源规则可能已失效';

  // =================== Web CORS 代理开关 ===================
  // Web 端浏览器受同源策略限制，直连图源会被 CORS 拦截；
  // Android/iOS/桌面等原生平台不受此限制，直接请求。
  //
  // webCorsProxyEnabled —— Web 端代理总开关，置 false 整体停用；
  // webCorsProxyPrefix  —— 代理服务前缀，可替换为自建代理。
  // ==========================================================
  /// Web 端 CORS 代理总开关。
  static const bool webCorsProxyEnabled = true;

  /// Web 端 CORS 代理前缀。
  static const String webCorsProxyPrefix = 'https://corsproxy.io/?url=';

  final http.Client _client;

  /// 按图源配置搜索 [keyword]（第 [page] 页）并解析图片列表。
  Future<SourceParseResult> search(
    SourceConfig config, {
    required String keyword,
    int page = 1,
  }) async {
    // 默认图源要求非空关键词；requiresKeyword=false 的图源（推荐流等）跳过。
    if (config.requiresKeyword && keyword.trim().isEmpty) {
      return const SourceParseResult.failure('请输入搜索关键词');
    }
    if (config.baseUrl.trim().isEmpty) {
      return const SourceParseResult.failure('图源配置错误：缺少站点地址');
    }
    if (config.searchUrlTemplate.trim().isEmpty) {
      return const SourceParseResult.failure('图源配置错误：缺少搜索地址模板');
    }
    // 列表选择器仅 HTML 图源需要；JSON 图源走 post.json 结构，无需该规则。
    if (config.sourceType == SourceType.html &&
        config.extractRule.listSelector.trim().isEmpty) {
      return const SourceParseResult.failure('图源配置错误：缺少图片列表选择器');
    }

    final Uri searchUri;
    try {
      searchUri = buildSearchUri(config, keyword, page);
    } on FormatException {
      return const SourceParseResult.failure('图源配置错误：搜索地址模板无效');
    }

    // 仅 Web 端自动拼接 CORS 代理前缀，Android 等原生平台直接请求。
    final Uri requestUri = _applyWebCorsProxy(config, searchUri);

    final http.Response response;
    try {
      response = await _client
          .get(requestUri, headers: <String, String>{'User-Agent': config.userAgent})
          .timeout(config.timeout);
    } on TimeoutException {
      return const SourceParseResult.failure('网络超时，请稍后重试');
    } on http.ClientException {
      return const SourceParseResult.failure('网络连接失败，请检查网络');
    } catch (e) {
      return SourceParseResult.failure('网络请求异常：$e');
    }

    if (response.statusCode == 401) {
      return const SourceParseResult.failure(
        '未授权访问（401），图源可能需要登录凭证或反爬校验',
      );
    }
    if (response.statusCode == 429) {
      return const SourceParseResult.failure(
        '请求过于频繁，已被图源限流（429），请稍后再试',
      );
    }
    if (response.statusCode == 404) {
      return const SourceParseResult.failure('页面不存在（404），请检查图源地址配置');
    }
    if (response.statusCode != 200) {
      return SourceParseResult.failure(
        '服务器响应异常（HTTP ${response.statusCode}）',
      );
    }

    try {
      // 按图源类型分流：JSON 图源走 post.json 解析器，
      // HTML 图源沿用原 CSS 选择器解析逻辑（原代码不变）。
      final List<ImageItem> items = config.sourceType == SourceType.json
          ? MoebooruJsonParser.parse(
              response.body,
              baseUri: Uri.parse(config.baseUrl),
              listKey: config.jsonListKey,
              fieldMapping: config.jsonFieldMapping,
            )
          : parseHtml(response.body, config);
      if (items.isEmpty) {
        return const SourceParseResult.failure(noImagesMessage);
      }
      return SourceParseResult.success(items);
    } catch (e) {
      return SourceParseResult.failure('解析失败：$e');
    }
  }

  /// 拼接搜索地址：[keyword] 替换 `{keyword}`（自动 URL 编码），
  /// [page] 替换 `{page}`，`{limit}` 替换为 [SourceConfig.perPage]
  /// （为 null 时替换为空字符串），再经 baseUrl 解析相对路径。
  Uri buildSearchUri(SourceConfig config, String keyword, int page) {
    final String raw = config.searchUrlTemplate
        .replaceAll('{keyword}', Uri.encodeComponent(keyword))
        .replaceAll('{page}', '$page')
        .replaceAll('{limit}', '${config.perPage ?? ''}');
    return Uri.parse(config.baseUrl).resolveUri(Uri.parse(raw));
  }

  /// 为 [uri] 拼接 CORS 代理前缀（纯函数，便于测试与复用）。
  static Uri buildProxyUri(Uri uri) {
    return Uri.parse('$webCorsProxyPrefix${Uri.encodeComponent(uri.toString())}');
  }

  /// Web 端按开关为请求地址拼接代理前缀；原生平台（含 Android）原样返回。
  /// 注意：该开关同时控制搜索请求与 `_ImageCard._displayUrl` 的图片 URL
  /// 代理（见 search_page.dart），两者必须保持一致，否则 Web 端会出现
  /// 搜索结果可见但缩略图被 CORS 拦截的不一致现象。
  Uri _applyWebCorsProxy(SourceConfig config, Uri uri) {
    if (kIsWeb && webCorsProxyEnabled && config.useWebCorsProxy) {
      return buildProxyUri(uri);
    }
    return uri;
  }

  /// 解析 HTML 提取图片列表；缺失图片地址的节点会被跳过。
  List<ImageItem> parseHtml(String htmlBody, SourceConfig config) {
    final Document document = html_parser.parse(htmlBody);
    final List<Element> nodes =
        document.querySelectorAll(config.extractRule.listSelector);
    final Uri base = Uri.parse(config.baseUrl);
    final List<ImageItem> items = <ImageItem>[];
    for (final Element node in nodes) {
      final String? imageUrl =
          _extractField(node, config.extractRule.imageUrl, base);
      if (imageUrl == null || imageUrl.isEmpty) {
        continue;
      }
      items.add(ImageItem(
        imageUrl: imageUrl,
        thumbnailUrl:
            _extractField(node, config.extractRule.thumbnailUrl, base),
        previewUrl: _extractField(node, config.extractRule.previewUrl, base),
        width: _extractInt(node, config.extractRule.width),
        height: _extractInt(node, config.extractRule.height),
        sourcePage: _extractField(node, config.extractRule.sourcePage, base),
        tags: _extractFieldList(node, config.extractRule.tags),
      ));
    }
    return items;
  }

  String? _extractField(Element container, FieldRule? rule, Uri base) {
    if (rule == null) {
      return null;
    }
    final Element? node = rule.selector == null
        ? container
        : container.querySelector(rule.selector!);
    if (node == null) {
      return null;
    }
    final String? value = _applyRegex(rule, _readValue(node, rule));
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    final String trimmed = value.trim();
    return rule.resolveUrl ? base.resolve(trimmed).toString() : trimmed;
  }

  /// 多值提取：容器内全部匹配节点的取值经正则后按空白切分为列表。
  List<String> _extractFieldList(Element container, FieldRule? rule) {
    if (rule == null) {
      return const <String>[];
    }
    final List<Element> nodes = rule.selector == null
        ? <Element>[container]
        : container.querySelectorAll(rule.selector!).toList();
    if (nodes.isEmpty) {
      return const <String>[];
    }
    final List<String> values = <String>[];
    for (final Element node in nodes) {
      final String? value = _applyRegex(rule, _readValue(node, rule));
      if (value == null) {
        continue;
      }
      values.addAll(
        value.trim().split(RegExp(r'\s+')).where((String s) => s.isNotEmpty),
      );
    }
    return values;
  }

  /// 容错的正则提取：空值、无匹配、正则异常均返回 null，
  /// 调用方（如 [_extractFieldList]）会降级为空结果，保证解析不崩溃。
  String? _applyRegex(FieldRule rule, String? value) {
    if (value == null || rule.regex == null) {
      return value;
    }
    try {
      final RegExpMatch? match = rule.regex!.firstMatch(value);
      return match == null || match.groupCount < 1 ? null : match.group(1);
    } catch (_) {
      return null;
    }
  }

  int? _extractInt(Element container, FieldRule? rule) {
    if (rule == null) {
      return null;
    }
    final Element? node = rule.selector == null
        ? container
        : container.querySelector(rule.selector!);
    if (node == null) {
      return null;
    }
    final String? value = _readValue(node, rule);
    return value == null ? null : int.tryParse(value.trim());
  }

  String? _readValue(Element node, FieldRule rule) {
    if (rule.useText) {
      return node.text.trim();
    }
    if (rule.attribute != null) {
      return node.attributes[rule.attribute];
    }
    return node.attributes['src'] ?? node.attributes['href'];
  }
}
