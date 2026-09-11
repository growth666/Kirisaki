import 'package:flutter_test/flutter_test.dart';

import 'package:kirisaki_app/core/source/builtin_sources.dart';
import 'package:kirisaki_app/core/source/source_config.dart';

void main() {
  test('国内直连图源（百度/必应/推荐）不走 Web CORS 代理', () {
    // 防回归：国内图源必须直连，否则 Web 端会命中不可用代理导致 401。
    expect(BuiltinSources.recommend.useWebCorsProxy, isFalse);

    for (final String id in <String>['baidu_aggregate', 'bing_aggregate']) {
      final SourceConfig config =
          BuiltinSources.all.firstWhere((SourceConfig s) => s.id == id);
      expect(config.useWebCorsProxy, isFalse, reason: '$id 必须直连');
      expect(config.sourceType, SourceType.json);
      expect(config.jsonListKey, 'data');
    }
  });

  test('海外 booru 图源保持代理语义（useWebCorsProxy 默认 true）', () {
    final SourceConfig yande =
        BuiltinSources.all.firstWhere((SourceConfig s) => s.id == 'yande');
    expect(yande.useWebCorsProxy, isTrue);
  });
}
