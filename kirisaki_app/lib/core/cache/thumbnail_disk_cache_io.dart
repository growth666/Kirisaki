import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

class ThumbnailDiskCache {
  ThumbnailDiskCache({this.maxBytes = 120 * 1024 * 1024});
  static final ThumbnailDiskCache instance = ThumbnailDiskCache();
  final int maxBytes;
  Directory? _directory;
  Future<Directory> _dir() async => _directory ??= Directory(
    '${(await getTemporaryDirectory()).path}${Platform.pathSeparator}kirisaki_thumbnails',
  )..createSync(recursive: true);
  String _name(String key) =>
      base64Url.encode(utf8.encode(key)).replaceAll('=', '');
  Future<Uint8List?> get(String key) async {
    try {
      final file = File(
        '${(await _dir()).path}${Platform.pathSeparator}${_name(key)}',
      );
      if (!await file.exists()) return null;
      return await file.readAsBytes();
    } catch (_) {
      return null;
    }
  }

  Future<void> put(String key, Uint8List bytes) async {
    try {
      final file = File(
        '${(await _dir()).path}${Platform.pathSeparator}${_name(key)}',
      );
      await file.writeAsBytes(bytes, flush: false);
      final files = (await _dir()).listSync().whereType<File>().toList()
        ..sort(
          (a, b) => a.statSync().modified.compareTo(b.statSync().modified),
        );
      var total = files.fold<int>(0, (sum, f) => sum + f.lengthSync());
      for (final old in files) {
        if (total <= maxBytes) {
          break;
        }
        total -= old.lengthSync();
        try {
          old.deleteSync();
        } catch (_) {}
      }
    } catch (_) {}
  }

  Future<void> clear() async {
    try {
      if (await (await _dir()).exists()) {
        await (await _dir()).delete(recursive: true);
      }
    } catch (_) {}
  }

  Future<int> get sizeBytes async {
    try {
      var total = 0;
      for (final file in (await _dir()).listSync().whereType<File>()) {
        total += await file.length();
      }
      return total;
    } catch (_) {
      return 0;
    }
  }
}
