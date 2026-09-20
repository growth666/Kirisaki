import 'package:flutter_test/flutter_test.dart';
import 'package:kirisaki_app/core/source/confirmed_tag_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  test(
    'corrupt storage reports failure and clear restores subsequent saves',
    () async {
      await SharedPreferencesAsync().setString(
        ConfirmedTagService.storageKey,
        'broken',
      );
      final service = ConfirmedTagService();
      await expectLater(service.save('s', 'a', 'A'), throwsFormatException);
      await service.clear();
      await service.save('s', 'a', 'A');
      expect(await service.lookup('s', 'a'), 'A');
    },
  );
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });
  test('choices persist across instances and remain scoped', () async {
    await ConfirmedTagService().save('zerochan-safe', 'tag', 'Canonical Tag');
    expect(
      await ConfirmedTagService().lookup('zerochan-safe', 'tag'),
      'Canonical Tag',
    );
    expect(await ConfirmedTagService().lookup('zerochan-adult', 'tag'), isNull);
    expect(await ConfirmedTagService().lookup('other', 'tag'), isNull);
    await ConfirmedTagService().clear();
    expect(await ConfirmedTagService().lookup('zerochan-safe', 'tag'), isNull);
  });
  test('concurrent saves and clear preserve write order', () async {
    final store = ConfirmedTagService();
    await Future.wait([store.save('s', 'a', 'A'), store.save('s', 'b', 'B')]);
    expect(await store.lookup('s', 'a'), 'A');
    expect(await store.lookup('s', 'b'), 'B');
    await Future.wait([store.save('s', 'c', 'C'), store.clear()]);
    expect(await store.lookup('s', 'c'), isNull);
  });
}
