import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kirisaki_app/core/source/builtin_sources.dart';
import 'package:kirisaki_app/core/source/source_parse_service.dart';

void main() {
  test(
    'Zerochan aliases and canonical tags through application client',
    () async {
      final service = SourceParseService();
      final config = BuiltinSources.all.firstWhere((s) => s.id == 'zerochan');
      final rows = <Map<String, Object?>>[];
      try {
        for (final tag in [
          'Cherry Blossoms',
          'Yor Forger',
          'Stars (Sky)',
          'Flower',
          'Cherry Blossom',
          'Twin Tails',
          'Nekomimi',
          'Maid Outfit',
          'Hyuuga Hinata',
          'Yor Briar',
        ]) {
          final result = await service.search(config, keyword: tag);
          rows.add({
            'tag': tag,
            'count': result.items.length,
            'error': result.errorMessage,
            'utc': DateTime.now().toUtc().toIso8601String(),
          });
          await Future<void>.delayed(const Duration(milliseconds: 1200));
        }
        final page = await service.search(
          config,
          keyword: 'Cherry Blossoms',
          page: 2,
        );
        rows.add({
          'tag': 'Cherry Blossoms',
          'page': 2,
          'count': page.items.length,
          'error': page.errorMessage,
        });
      } finally {
        service.close();
        Directory('build/dictionary-checks').createSync(recursive: true);
        File(
          'build/dictionary-checks/zerochan-fixed.json',
        ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(rows));
      }
      expect(
        rows.where((r) => (r['count'] as int) == 0),
        isEmpty,
        reason: jsonEncode(rows),
      );
    },
    skip: !const bool.fromEnvironment('RUN_ZEROCHAN_REDIRECT_LIVE'),
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
