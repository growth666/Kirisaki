import 'dart:convert';

import 'custom_source_store.dart';
import 'source_config.dart';
import 'source_service.dart';

/// 图源 JSON 导入结果：成功携带配置，失败携带明确错误信息。
class SourceImportResult {
  const SourceImportResult._({this.config, this.errorMessage});

  /// 解析校验成功。
  const SourceImportResult.success(SourceConfig config)
    : this._(config: config);

  /// 失败，[errorMessage] 为可直接展示的中文提示。
  const SourceImportResult.failure(String errorMessage)
    : this._(errorMessage: errorMessage);

  /// 解析出的图源配置（失败时为 null）。
  final SourceConfig? config;

  /// 错误信息（成功时为 null）。
  final String? errorMessage;

  /// 是否成功。
  bool get isSuccess => errorMessage == null;
}

/// 自定义图源 JSON 导入器：解析校验 JSON 文本，并持久化到自定义图源仓库。
///
/// - 仅接受字段完整、格式合法的配置；
/// - 导入成功后自动写入 [CustomSourceStore]（App 重启不丢失）；
/// - 内置图源列表不参与导入（只写 custom key）。
class SourceJsonImporter {
  SourceJsonImporter({CustomSourceStore? store, SourceService? service})
    : _service =
          service ??
          (store == null
              ? SourceService.instance
              : SourceService(store: store));

  final SourceService _service;

  /// 解析并校验 JSON 文本；失败返回明确中文提示（不抛异常）。
  SourceImportResult parseAndValidate(String jsonText) {
    if (jsonText.trim().isEmpty) {
      return const SourceImportResult.failure('请输入图源配置 JSON');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(jsonText);
    } on FormatException catch (e) {
      return SourceImportResult.failure('JSON 格式错误：$e');
    }
    if (decoded is! Map<String, Object?>) {
      return const SourceImportResult.failure('JSON 内容必须是图源配置对象');
    }

    final String? missing = _firstMissingField(decoded);
    if (missing != null) {
      return SourceImportResult.failure('缺少必填字段：$missing');
    }
    final Object? sourceType = decoded['sourceType'];
    if (sourceType != null &&
        !SourceType.values.any((SourceType t) => t.name == sourceType)) {
      return SourceImportResult.failure(
        'sourceType 取值非法：$sourceType（可选值：html/json）',
      );
    }
    final Object? perPage = decoded['perPage'];
    final jsonFormat = decoded['jsonFormat'];
    if (jsonFormat != null &&
        !SourceJsonFormat.values.any((v) => v.name == jsonFormat)) {
      return const SourceImportResult.failure('jsonFormat 取值非法');
    }
    if (decoded['pageOffset'] != null &&
        (decoded['pageOffset'] is! int ||
            (decoded['pageOffset'] as int) < -1)) {
      return const SourceImportResult.failure('pageOffset 必须是大于等于 -1 的整数');
    }
    if (perPage != null && (perPage is! int || perPage <= 0)) {
      return SourceImportResult.failure('perPage 必须是正整数');
    }

    try {
      return SourceImportResult.success(SourceConfig.fromJson(decoded));
    } on TypeError catch (e) {
      return SourceImportResult.failure('字段类型错误：$e');
    } on ArgumentError catch (e) {
      return SourceImportResult.failure('字段取值非法：$e');
    }
  }

  /// 解析校验通过后去重（id 唯一）并持久化。
  Future<SourceImportResult> importAndSave(
    String jsonText, {
    String? editingId,
  }) async {
    final SourceImportResult parsed = parseAndValidate(jsonText);
    if (!parsed.isSuccess) {
      return parsed;
    }
    final SourceConfig config = parsed.config!;
    try {
      if (editingId == null) {
        await _service.add(config);
      } else {
        await _service.update(editingId, config);
      }
      return parsed;
    } on StateError catch (error) {
      return SourceImportResult.failure(error.message);
    } catch (error) {
      return SourceImportResult.failure('保存图源失败：$error');
    }
  }

  /// 必填字段检查：返回首个缺失字段名，完整则返回 null。
  static String? _firstMissingField(Map<String, Object?> json) {
    const List<String> requiredTopLevel = <String>[
      'id',
      'name',
      'baseUrl',
      'searchUrlTemplate',
    ];
    for (final String field in requiredTopLevel) {
      final Object? value = json[field];
      if (value is! String || value.trim().isEmpty) {
        return field;
      }
    }
    final Object? extractRule = json['extractRule'];
    if (extractRule is! Map<String, Object?>) {
      return 'extractRule';
    }
    final Object? listSelector = extractRule['listSelector'];
    if (listSelector is! String || listSelector.trim().isEmpty) {
      return 'extractRule.listSelector';
    }
    if (extractRule['imageUrl'] is! Map<String, Object?>) {
      return 'extractRule.imageUrl';
    }
    return null;
  }
}
