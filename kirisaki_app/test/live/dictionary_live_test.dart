import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:kirisaki_app/core/source/builtin_sources.dart';
import 'package:kirisaki_app/core/source/chinese_search_dictionary.dart';
import 'package:kirisaki_app/core/source/moebooru_json_parser.dart';
import 'package:kirisaki_app/core/source/source_config.dart';
import 'package:kirisaki_app/core/source/source_parse_service.dart';

void main() {
  test(
    'dictionary live search audit',
    () async {
      const input = String.fromEnvironment(
        'DICTIONARY_FILE',
        defaultValue: 'assets/search/keywords.json',
      );
      const output = String.fromEnvironment(
        'AUDIT_FOLDER',
        defaultValue: 'build/dictionary-checks',
      );
      final entries = ChineseSearchDictionary.parse(
        File(input).readAsStringSync(),
      );
      await Directory(output).create(recursive: true);
      await Future.wait(
        BuiltinSources.all.map((builtin) async {
          final client = http.Client();
          final service = SourceParseService(client: client);
          final config = SourceConfig.fromJson({
            ...builtin.toJson(),
            'perPage': 2,
          });
          final rows = <Map<String, Object?>>[];
          var consecutiveFailures = 0;
          try {
            for (final entry in entries) {
              final keyword = entry.keywordFor(config.id);
              if (keyword == null) continue;
              final row = <String, Object?>{
                'label': entry.label,
                'keyword': keyword,
                'timeUtc': DateTime.now().toUtc().toIso8601String(),
              };
              rows.add(row);
              if (consecutiveFailures >= 3) {
                row['result'] = 'skipped_after_three_failures';
                continue;
              }
              final uri = service.buildSearchUri(config, keyword, 1);
              row['url'] = uri.toString();
              try {
                final response = await client
                    .get(uri, headers: {'User-Agent': config.userAgent})
                    .timeout(const Duration(seconds: 15));
                row['http'] = response.statusCode;
                if (response.statusCode != 200) {
                  row['result'] = 'http_error';
                  consecutiveFailures++;
                } else {
                  final items = MoebooruJsonParser.parse(
                    utf8.decode(response.bodyBytes),
                    baseUri: Uri.parse(config.baseUrl),
                    format: config.jsonFormat,
                    listKey: config.jsonListKey,
                    fieldMapping: config.jsonFieldMapping,
                  );
                  row['result'] = items.isEmpty ? 'empty' : 'has_results';
                  row['count'] = items.length;
                  consecutiveFailures = 0;
                }
              } catch (error) {
                row['result'] = 'request_or_parse_error';
                row['error'] = error.toString();
                consecutiveFailures++;
              }
              File('$output/${config.id}.json').writeAsStringSync(
                const JsonEncoder.withIndent('  ').convert({
                  'platform': Platform.operatingSystem,
                  'network': 'direct_no_proxy',
                  'source': config.id,
                  'rows': rows,
                }),
              );
              // One request at a time per host; stop on consecutive failures.
            await Future<void>.delayed(const Duration(milliseconds: 1200));
            }
          } finally {
            client.close();
            File('$output/${config.id}.json').writeAsStringSync(
              const JsonEncoder.withIndent('  ').convert({
                'platform': Platform.operatingSystem,
                'network': 'direct_no_proxy',
                'source': config.id,
                'rows': rows,
              }),
            );
            final counts = <String, int>{};
            for (final row in rows) {
              final status = row['result'] as String;
              counts[status] = (counts[status] ?? 0) + 1;
            }
            // Audit completion is not a claim that any upstream source passed.
            debugPrint('${config.id}: $counts');
          }
        }),
      );
    },
    skip: !const bool.fromEnvironment('RUN_DICTIONARY_LIVE'),
    timeout: const Timeout(Duration(minutes: 25)),
  );
}
