import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:kirisaki_app/core/backup/data_backup_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('kirisaki/backup');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(channel, null);
  });
  test('Android exports UTF-8 JSON through native save dialog', () async {
    await SharedPreferencesAsync().setString(
      'search_history',
      jsonEncode(['蕾姆']),
    );
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'exportBackup');
      final backup = jsonDecode(call.arguments['text'] as String) as Map;
      expect(backup['app'], 'Kirisaki');
      expect(jsonDecode(backup['data']['search_history'] as String), ['蕾姆']);
      return 'content://documents/backup.json';
    });
    expect(
      await DataBackupService().exportToFile(),
      'content://documents/backup.json',
    );
  });
  test('cancel returns null instead of success', () async {
    messenger.setMockMethodCallHandler(channel, (_) async => null);
    expect(await DataBackupService().exportToFile(), isNull);
  });
  test('write errors reach the failure message handler', () async {
    messenger.setMockMethodCallHandler(channel, (_) async {
      throw PlatformException(code: 'EXPORT_FAILED');
    });
    await expectLater(
      DataBackupService().exportToFile(),
      throwsA(isA<PlatformException>()),
    );
  });
}
