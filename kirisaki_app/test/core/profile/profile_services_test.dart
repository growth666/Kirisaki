import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:kirisaki_app/core/profile/download_service.dart';
import 'package:kirisaki_app/core/profile/history_service.dart';
import 'package:kirisaki_app/core/profile/search_history_service.dart';
import 'package:kirisaki_app/core/source/image_item.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  group('HistoryService', () {
    test('去重保留最新、最新在前、持久化往返', () async {
      final HistoryService service = HistoryService();
      await service.record(const ImageItem(imageUrl: 'https://x/a.jpg'));
      await service.record(const ImageItem(imageUrl: 'https://x/b.jpg'));
      await service.record(const ImageItem(imageUrl: 'https://x/a.jpg'));

      // a 重新浏览 → 移到最前且不重复。
      expect(service.count, 2);
      expect(service.items.first.imageUrl, 'https://x/a.jpg');
      expect(service.items.last.imageUrl, 'https://x/b.jpg');

      // 重启恢复。
      final HistoryService restarted = HistoryService();
      await restarted.load();
      expect(restarted.count, 2);
      expect(restarted.items.first.imageUrl, 'https://x/a.jpg');
    });

    test('clear 清空', () async {
      final HistoryService service = HistoryService();
      await service.record(const ImageItem(imageUrl: 'https://x/a.jpg'));
      await service.clear();
      expect(service.count, 0);
    });
  });

  group('DownloadService', () {
    test('remove preserves other records and clear persists', () async {
      final service = DownloadService();
      const a = ImageItem(imageUrl: 'https://x/a.jpg');
      const b = ImageItem(imageUrl: 'https://x/b.jpg');
      await service.record(a);
      await service.record(b);
      await service.remove(a);
      final restarted = DownloadService();
      await restarted.load();
      expect(restarted.items.single.imageUrl, b.imageUrl);
      await restarted.clear();
      final cleared = DownloadService();
      await cleared.load();
      expect(cleared.items, isEmpty);
    });
    test('记录与持久化往返', () async {
      final DownloadService service = DownloadService();
      await service.record(const ImageItem(imageUrl: 'https://x/d.jpg'));
      expect(service.count, 1);

      final DownloadService restarted = DownloadService();
      await restarted.load();
      expect(restarted.items.single.imageUrl, 'https://x/d.jpg');
    });
  });

  group('SearchHistoryService', () {
    test('记录/去重/删除/清空', () async {
      final SearchHistoryService service = SearchHistoryService();
      await service.add('  blue_sky ');
      await service.add('cloud');
      await service.add('blue_sky'); // 去重移到最前

      expect(service.keywords, <String>['blue_sky', 'cloud']);

      await service.remove('cloud');
      expect(service.keywords, <String>['blue_sky']);

      await service.clear();
      expect(service.keywords, isEmpty);
    });

    test('持久化往返', () async {
      final SearchHistoryService service = SearchHistoryService();
      await service.add('k1');
      await service.add('k2');

      final SearchHistoryService restarted = SearchHistoryService();
      await restarted.load();
      expect(restarted.keywords, <String>['k2', 'k1']);
    });

    test('select/consumeSelection 快速搜索负载', () {
      final SearchHistoryService service = SearchHistoryService();
      expect(service.selectedKeyword, isNull);

      service.select('k1');
      expect(service.selectedKeyword, 'k1');

      service.consumeSelection();
      expect(service.selectedKeyword, isNull);
    });
  });
}
