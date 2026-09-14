import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:kirisaki_app/core/source/builtin_sources.dart';
import 'package:kirisaki_app/core/source/custom_source_store.dart';
import 'package:kirisaki_app/core/source/source_config.dart';
import 'package:kirisaki_app/core/source/source_json_importer.dart';
import 'package:kirisaki_app/core/source/source_service.dart';

SourceConfig custom(String id) => SourceConfig(
  id: id,
  name: id,
  baseUrl: 'https://example.test',
  searchUrlTemplate: '/?q={keyword}',
  extractRule: const ExtractRule(
    listSelector: 'img',
    imageUrl: FieldRule(attribute: 'src'),
  ),
);

class FailingStore extends CustomSourceStore {
  bool fail = false;
  @override
  Future<void> save(List<SourceConfig> sources) async {
    if (fail) throw StateError('disk failure');
    await super.save(sources);
  }
}

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test(
    'legacy custom data and builtin toggles survive restart independently',
    () async {
      await CustomSourceStore().save([custom('legacy')]);
      final service = SourceService();
      await service.load();
      await service.setEnabled(BuiltinSources.all.first.id, false);
      await service.setEnabled('legacy', false);
      final restarted = SourceService();
      await restarted.load();
      expect(restarted.custom.single.enabled, false);
      expect(restarted.all.first.enabled, false);
      expect(
        restarted.all.any((s) => s.id == BuiltinSources.recommend.id),
        false,
      );
      expect(
        restarted.all.first.searchUrlTemplate,
        BuiltinSources.all.first.searchUrlTemplate,
      );
    },
  );

  test(
    'import validates all IDs, edits fixed ID and deletes persistently',
    () async {
      final service = SourceService();
      final importer = SourceJsonImporter(service: service);
      expect(
        (await importer.importAndSave(jsonEncode(custom('a').toJson())))
            .isSuccess,
        true,
      );
      expect(
        (await importer.importAndSave(jsonEncode(custom('a').toJson())))
            .isSuccess,
        false,
      );
      expect(
        (await importer.importAndSave(
          jsonEncode(custom(BuiltinSources.all.first.id).toJson()),
        )).isSuccess,
        false,
      );
      expect(
        (await importer.importAndSave(
          jsonEncode(custom(BuiltinSources.recommend.id).toJson()),
        )).isSuccess,
        false,
      );
      expect(
        (await importer.importAndSave(
          jsonEncode(custom('b').toJson()),
          editingId: 'a',
        )).isSuccess,
        false,
      );
      final edited = {...custom('a').toJson(), 'name': 'Edited'};
      expect(
        (await importer.importAndSave(
          jsonEncode(edited),
          editingId: 'a',
        )).isSuccess,
        true,
      );
      expect(service.custom.single.name, 'Edited');
      await service.remove('a');
      expect(await CustomSourceStore().load(), isEmpty);
    },
  );

  test(
    'failed writes publish nothing and queue accepts subsequent actions',
    () async {
      final store = FailingStore();
      final service = SourceService(store: store);
      await service.add(custom('a'));
      var notifications = 0;
      service.addListener(() => notifications++);
      store.fail = true;
      await expectLater(service.remove('a'), throwsStateError);
      await expectLater(service.setEnabled('a', false), throwsStateError);
      expect(service.custom.single.enabled, true);
      expect(notifications, 0);
      store.fail = false;
      await Future.wait([service.add(custom('b')), service.add(custom('c'))]);
      expect(service.custom.map((s) => s.id), ['a', 'b', 'c']);
    },
  );

  test(
    'reset restores defaults; failed reset retains prior settings',
    () async {
      final store = FailingStore();
      final service = SourceService(store: store);
      await service.add(custom('a'));
      await service.setEnabled(BuiltinSources.all.first.id, false);
      store.fail = true;
      await expectLater(service.reset(), throwsStateError);
      final restarted = SourceService();
      await restarted.load();
      expect(restarted.all.first.enabled, false);
      expect(restarted.custom, hasLength(1));
      store.fail = false;
      await service.reset();
      expect(service.custom, isEmpty);
      expect(
        service.enabled.length,
        BuiltinSources.all.where((s) => s.enabled).length,
      );
    },
  );

  test(
    'malformed toggle preferences do not hide legacy custom sources',
    () async {
      await SharedPreferencesAsync().setString(
        SourceService.enabledKey,
        'invalid',
      );
      await CustomSourceStore().save([custom('a')]);
      final service = SourceService();
      await service.load();
      expect(service.custom.single.id, 'a');
    },
  );
}
