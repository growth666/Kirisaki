import 'package:flutter_test/flutter_test.dart';

import 'package:kirisaki_app/core/download/image_downloader.dart';

void main() {
  test('非 Web 平台走 stub 分支，返回不支持文案', () async {
    final ImageSaveService service = createImageDownloadService();

    final ImageSaveResult result = await service.saveImage(
      imageUrl: 'https://example.test/image/a.jpg',
    );

    expect(result.isSuccess, isFalse);
    expect(
      result.errorMessage,
      '当前平台不支持浏览器下载（Android 存储实现后续轮次接入）',
    );
  });
}
