import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';

const MethodChannel _downloadChannel = MethodChannel('kirisaki/download');

/// 原生平台目录选择。
///
/// - 桌面（Windows/Linux/macOS）：file_selector 目录选择器；
/// - Android：SAF 目录选择通道（返回 tree URI 字符串；
///   原生端见 MainActivity.kt，基础实现）。
Future<String?> pickDirectory() async {
  if (Platform.isAndroid) {
    try {
      return await _downloadChannel.invokeMethod<String>(
        'pickDownloadDirectory',
      );
    } on MissingPluginException {
      return null; // 原生端未就绪：按取消处理。
    }
  }
  // 桌面端：系统目录选择对话框（用户取消时返回 null）。
  return getDirectoryPath(
    confirmButtonText: '选择下载位置',
    canCreateDirectories: true,
  );
}
