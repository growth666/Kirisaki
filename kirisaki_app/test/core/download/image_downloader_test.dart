import 'package:flutter_test/flutter_test.dart';

import 'package:kirisaki_app/core/download/image_downloader.dart';

void main() {
  test('原生平台（VM）创建 io 下载服务，失败路径返回失败文案', () async {
    final ImageSaveService service = createImageDownloadService();

    // 连接拒绝的地址：快速失败，验证失败反馈链路（业务层统一入口）。
    final ImageSaveResult result = await service.saveImage(
      imageUrl: 'http://127.0.0.1:1/none.jpg',
    );

    expect(result.isSuccess, isFalse);
    expect(result.errorMessage, isNotNull);
    expect(result.errorMessage, contains('下载失败'));
  });
}
