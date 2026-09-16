import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../network/http_client_factory.dart';
import '../network/image_response.dart';
import '../settings/settings_service.dart';
import 'image_save_service.dart';

/// 创建下载服务（原生 io 平台分支：Windows/Linux/macOS/Android）。
ImageSaveService createDownloadService() => IoImageDownloadService();

/// 原生平台下载实现。
///
/// - **Windows/Linux/macOS**：path_provider 获取系统下载目录 →
///   dart:io 写文件（同名自动加 (1) 后缀）；
/// - **Android**：经 MethodChannel 保存到公共下载目录
///   （MediaStore，原生端见 MainActivity.kt）——
///   **基础实现**，保存到相册/通知栏提示等进阶功能留待后续迭代。
///
/// 业务层统一调用 `createImageDownloadService()`，不感知平台差异。
class IoImageDownloadService implements ImageSaveService {
  IoImageDownloadService({this.downloadDirOverride, this.client});

  /// 测试注入：VM 环境拿不到真实系统下载目录。
  final Directory? downloadDirOverride;

  /// 注入的 HTTP client（默认经全局代理适配构建）。
  final http.Client? client;

  static const MethodChannel _channel = MethodChannel('kirisaki/download');

  @override
  Future<ImageSaveResult> saveImage({
    required String imageUrl,
    String? fileName,
  }) async {
    if (Platform.isAndroid) {
      return _saveAndroid(imageUrl, fileName);
    }
    return _saveToFile(imageUrl, fileName);
  }

  /// 桌面端：拉取字节 → 写系统下载目录。
  Future<ImageSaveResult> _saveToFile(String imageUrl, String? fileName) async {
    final http.Client client = this.client ?? buildClient();
    try {
      final http.Response response = await fetchImageResponse(
        client,
        Uri.parse(imageUrl),
      );
      if (response.statusCode != 200) {
        return ImageSaveResult.failure(
          '下载失败：服务器响应异常（HTTP ${response.statusCode}）',
        );
      }
      // 写入目录优先级：测试注入 > 用户自定义（设置页自选）> 系统默认。
      final Directory? baseDir =
          downloadDirOverride ??
          _customDirOrNull() ??
          await getDownloadsDirectory();
      if (baseDir == null) {
        return const ImageSaveResult.failure('无法获取系统下载目录');
      }
      await baseDir.create(recursive: true);
      final String name = fileName ?? _fileNameFromUrl(imageUrl);
      final File file = File(_uniquePath(baseDir, name));
      await file.writeAsBytes(response.bodyBytes, flush: true);
      return ImageSaveResult.success(message: '已保存到 ${file.path}');
    } catch (e) {
      return ImageSaveResult.failure('下载失败：$e');
    } finally {
      if (this.client == null) client.close();
    }
  }

  /// Android：拉取字节 → MediaStore 通道写入公共下载目录。
  Future<ImageSaveResult> _saveAndroid(
    String imageUrl,
    String? fileName,
  ) async {
    final http.Client client = this.client ?? buildClient();
    try {
      final http.Response response = await fetchImageResponse(
        client,
        Uri.parse(imageUrl),
      );
      if (response.statusCode != 200) {
        return ImageSaveResult.failure(
          '下载失败：服务器响应异常（HTTP ${response.statusCode}）',
        );
      }
      // 用户自选目录（SAF tree URI）随通道传入；未设置走 MediaStore 默认。
      final String? customDir = SettingsService.instance.downloadDir;
      final String? treeUri =
          customDir != null && customDir.startsWith('content://')
          ? customDir
          : null;
      final String? path = await _channel.invokeMethod<String>(
        'saveToDownloads',
        <String, Object?>{
          'bytes': response.bodyBytes,
          'fileName': fileName ?? _fileNameFromUrl(imageUrl),
          'treeUri': treeUri,
        },
      );
      return ImageSaveResult.success(message: '已保存到 $path');
    } on MissingPluginException {
      return const ImageSaveResult.failure('当前平台未接入下载通道（Android 原生端未就绪）');
    } catch (e) {
      return ImageSaveResult.failure('下载失败：$e');
    } finally {
      if (this.client == null) client.close();
    }
  }

  /// 读取用户在设置页自选的下载目录（未设置返回 null）。
  static Directory? _customDirOrNull() {
    final String? dir = SettingsService.instance.downloadDir;
    // Android SAF tree URI 由通道处理（不走本地文件路径）。
    if (dir == null || dir.isEmpty || dir.startsWith('content://')) {
      return null;
    }
    return Directory(dir);
  }

  /// 文件名冲突时自动加 (1)/(2) 后缀。
  static String _uniquePath(Directory dir, String name) {
    File candidate = File('${dir.path}${Platform.pathSeparator}$name');
    int i = 1;
    while (candidate.existsSync()) {
      final int dot = name.lastIndexOf('.');
      final String stem = dot > 0 ? name.substring(0, dot) : name;
      final String ext = dot > 0 ? name.substring(dot) : '';
      candidate = File('${dir.path}${Platform.pathSeparator}$stem($i)$ext');
      i++;
    }
    return candidate.path;
  }

  /// 从图片 URL 末段提取文件名；无扩展名时使用通用兜底名。
  static String _fileNameFromUrl(String url) {
    final Uri uri = Uri.parse(url);
    final String? last = uri.pathSegments.isNotEmpty
        ? uri.pathSegments.last
        : null;
    if (last == null || last.isEmpty || !last.contains('.')) {
      return 'image.jpg';
    }
    return last;
  }
}
