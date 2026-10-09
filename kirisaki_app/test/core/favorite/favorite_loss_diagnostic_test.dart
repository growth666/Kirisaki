import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:kirisaki_app/core/favorite/favorite_service.dart';
import 'package:kirisaki_app/core/favorite/favorite_store.dart';
import 'package:kirisaki_app/core/source/image_item.dart';

// Regression coverage for cold-start data loss.
void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });
  test('pending load is shared and mutations are serialized', () async {
    final store = ControlledStore();
    final service = FavoriteService(store: store);
    final load = service.load();
    final again = service.load();
    final add = service.add(const ImageItem(imageUrl: 'new'));
    final remove = service.remove('old');
    expect(store.reads, 1);
    store.ready.complete([const ImageItem(imageUrl: 'old')]);
    await Future.wait([load, again, add, remove]);
    expect(service.items.map((e) => e.imageUrl), ['new']);
    expect(store.saved.map((e) => e.imageUrl), ['new']);
    store.fail = true;
    await expectLater(service.clearAll(), throwsStateError);
    expect(service.items.map((e) => e.imageUrl), ['new']);
    expect(store.saved.map((e) => e.imageUrl), ['new']);
    store.fail = false;
    await service.add(const ImageItem(imageUrl: 'retry'));
    expect(store.saved.map((e) => e.imageUrl), ['new', 'retry']);
  });
  test('adding before loading preserves previous favorites', () async {
    await FavoriteStore().save([
      const ImageItem(imageUrl: 'https://example.test/old.jpg'),
    ]);
    await FavoriteService().add(
      const ImageItem(imageUrl: 'https://example.test/new.jpg'),
    );
    final stored = await FavoriteStore().load();
    expect(stored.map((e) => e.imageUrl), [
      'https://example.test/old.jpg',
      'https://example.test/new.jpg',
    ]);
  });
  test('malformed data blocks writes and preserves storage', () async {
    await SharedPreferencesAsync().setString(
      FavoriteStore.storageKey,
      '[{"imageUrl":"https://example.test/old.jpg"},{"imageUrl":42}]',
    );
    final before = await SharedPreferencesAsync().getString(
      FavoriteStore.storageKey,
    );
    final service = FavoriteService();
    await service.load();
    expect(service.loadError, isNotNull);
    await expectLater(
      service.add(const ImageItem(imageUrl: 'new')),
      throwsStateError,
    );
    expect(
      await SharedPreferencesAsync().getString(FavoriteStore.storageKey),
      before,
    );
  });
}

class ControlledStore extends FavoriteStore {
  final ready = Completer<List<ImageItem>>();
  int reads = 0;
  bool fail = false;
  List<ImageItem> saved = [];
  @override
  Future<List<ImageItem>> load() {
    reads++;
    return ready.future;
  }

  @override
  Future<void> save(List<ImageItem> items) async {
    if (fail) throw StateError('disk failure');
    await Future<void>.delayed(Duration.zero);
    saved = List.of(items);
  }
}
