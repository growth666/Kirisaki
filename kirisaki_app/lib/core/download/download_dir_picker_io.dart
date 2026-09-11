import 'dart:io';

import 'package:file_selector/file_selector.dart';

/// 原生平台目录选择。
///
/// - 桌面（Windows/Linux/macOS）：file_selector 目录选择器；
/// - Android：SAF 目录选择通道（模块④接入，返回 tree URI 字符串）。
Future<String?> pickDirectory() async {
  if (Platform.isAndroid) {
    // 模块④接入 SAF 通道；当前返回 null（取消语义）。
    return null;
  }
  // 桌面端：系统目录选择对话框（用户取消时返回 null）。
  return getDirectoryPath(
    confirmButtonText: '选择下载位置',
    canCreateDirectories: true,
  );
}
