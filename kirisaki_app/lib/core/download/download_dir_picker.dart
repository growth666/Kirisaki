import 'download_dir_picker_stub.dart'
    if (dart.library.io) 'download_dir_picker_io.dart'
    if (dart.library.js_interop) 'download_dir_picker_web.dart';

/// 弹出平台目录选择器（条件导入分平台）。
///
/// - 桌面：file_selector 目录选择器；
/// - Android：SAF 目录选择（通道，返回 tree URI 字符串）；
/// - Web：无目录概念（选择发生在下载时 showSaveFilePicker）→ 返回 null。
///
/// 返回 null 表示用户取消或当前平台不支持目录选择。
Future<String?> pickDownloadDirectory() => pickDirectory();
