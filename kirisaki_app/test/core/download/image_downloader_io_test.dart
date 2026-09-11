import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:kirisaki_app/core/download/image_downloader_io.dart';
import 'package:kirisaki_app/core/settings/settings_service.dart';

void main() {
  test('保存到下载目录成功（写入文件且内容一致）', () async {
    final Directory tempDir =
        await Directory.systemTemp.createTemp('kirisaki_dl_test');
    addTearDown(() => tempDir.delete(recursive: true));

    final IoImageDownloadService service = IoImageDownloadService(
      downloadDirOverride: tempDir,
      client: MockClient(
        (http.Request request) async =>
            http.Response.bytes(<int>[1, 2, 3], 200),
      ),
    );

    final result = await service.saveImage(imageUrl: 'https://x/a.jpg');

    expect(result.isSuccess, isTrue);
    expect(result.message, contains('已保存到'));
    final List<File> files =
        tempDir.listSync().whereType<File>().toList();
    expect(files, hasLength(1));
    expect(files.single.readAsBytesSync(), <int>[1, 2, 3]);
  });

  test('同名文件自动加 (1) 后缀', () async {
    final Directory tempDir =
        await Directory.systemTemp.createTemp('kirisaki_dl_dup');
    addTearDown(() => tempDir.delete(recursive: true));

    final IoImageDownloadService service = IoImageDownloadService(
      downloadDirOverride: tempDir,
      client: MockClient(
        (http.Request request) async =>
            http.Response.bytes(<int>[1], 200),
      ),
    );

    await service.saveImage(imageUrl: 'https://x/a.jpg');
    final result2 = await service.saveImage(imageUrl: 'https://x/a.jpg');

    expect(result2.isSuccess, isTrue);
    final List<File> files =
        tempDir.listSync().whereType<File>().toList();
    expect(files, hasLength(2));
  });

  test('HTTP 非 200 返回失败文案', () async {
    final IoImageDownloadService service = IoImageDownloadService(
      downloadDirOverride: Directory.systemTemp,
      client: MockClient(
        (http.Request request) async => http.Response('err', 404),
      ),
    );

    final result = await service.saveImage(imageUrl: 'https://x/a.jpg');

    expect(result.isSuccess, isFalse);
    expect(result.errorMessage, contains('HTTP 404'));
  });

  test('设置页自选的下载目录优先于系统默认', () async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final Directory customDir =
        await Directory.systemTemp.createTemp('kirisaki_custom');
    addTearDown(() => customDir.delete(recursive: true));

    // 用户自选目录（设置页持久化路径）。
    await SettingsService.instance.setDownloadDir(customDir.path);

    final IoImageDownloadService service = IoImageDownloadService(
      client: MockClient(
        (http.Request request) async =>
            http.Response.bytes(<int>[9, 9], 200),
      ),
    );

    final result = await service.saveImage(imageUrl: 'https://x/b.jpg');

    expect(result.isSuccess, isTrue);
    final List<File> files =
        customDir.listSync().whereType<File>().toList();
    expect(files, hasLength(1));
    expect(files.single.readAsBytesSync(), <int>[9, 9]);

    await SettingsService.instance.resetDownloadDir();
  });
}
