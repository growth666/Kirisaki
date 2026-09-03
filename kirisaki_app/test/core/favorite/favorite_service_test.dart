import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:kirisaki_app/core/favorite/favorite_service.dart';
import 'package:kirisaki_app/core/favorite/favorite_store.dart';
import 'package:kirisaki_app/core/source/image_item.dart';

const ImageItem _itemA = ImageItem(
  imageUrl: 'https://example.test/a.jpg',
  tags: <String>['sky', 'cloud'],
);
const ImageItem _itemB = ImageItem(imageUrl: 'https://example.test/b.jpg');

void main() {
  setUp(() {
    // 用官方内存实现替换平台通道，避免依赖真实设备存储。
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  group('ImageItem 序列化', () {
    test('toJson/fromJson 往返保留关键信息', () {
      final ImageItem restored = ImageItem.fromJson(_itemA.toJson());

      expect(restored.imageUrl, _itemA.imageUrl);
      expect(restored.tags, _itemA.tags);
      expect(restored.thumbnailUrl, isNull);
    });
  });

  group('FavoriteService', () {
    test('添加/判断/去重/移除', () async {
      final FavoriteService service = FavoriteService();

      await service.add(_itemA);
      await service.add(_itemA); // 重复添加：按 imageUrl 去重
      expect(service.items, hasLength(1));
      expect(service.contains('https://example.test/a.jpg'), isTrue);

      await service.remove('https://example.test/a.jpg');
      expect(service.items, isEmpty);
      expect(service.contains('https://example.test/a.jpg'), isFalse);
    });

    test('移除不存在的收藏无操作', () async {
      final FavoriteService service = FavoriteService();
      await service.add(_itemA);
      await service.remove('https://example.test/none.jpg');
      expect(service.items, hasLength(1));
    });

    test('收藏变更触发 ChangeNotifier 通知', () async {
      final FavoriteService service = FavoriteService();
      int notified = 0;
      service.addListener(() => notified++);

      await service.add(_itemA);
      expect(notified, 1);

      await service.remove(_itemA.imageUrl);
      expect(notified, 2);
    });

    test('持久化往返：新实例 load 恢复收藏', () async {
      final FavoriteService service = FavoriteService();
      await service.add(_itemA);
      await service.add(_itemB);

      // 新实例模拟 App 重启。
      final FavoriteService restarted = FavoriteService();
      await restarted.load();

      expect(restarted.items, hasLength(2));
      expect(restarted.contains(_itemA.imageUrl), isTrue);
      expect(restarted.contains(_itemB.imageUrl), isTrue);
    });

    test('损坏数据容错返回空列表', () async {
      await SharedPreferencesAsync().setString(
        FavoriteStore.storageKey,
        'bad-json{',
      );

      final FavoriteService service = FavoriteService();
      await service.load();

      expect(service.items, isEmpty);
    });
  });
}
