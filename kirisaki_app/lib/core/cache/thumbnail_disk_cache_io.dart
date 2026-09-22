import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

/// Serialized mutations keep eviction and clearing consistent with writes.
class ThumbnailDiskCache {
  ThumbnailDiskCache({this.maxBytes = 120 * 1024 * 1024, this.directory});
  static final ThumbnailDiskCache instance = ThumbnailDiskCache();
  final int maxBytes;
  final Directory? directory;
  Directory? _directory;
  final Map<String, int> _sizes = {};
  int _total = 0;
  bool _indexed = false;
  Future<void> _pending = Future.value();

  Future<void> _enqueue(Future<void> Function() action) {
    final next = _pending.then((_) => action());
    // Cache failures must never prevent displaying a downloaded image.
    _pending = next.catchError((Object _) {});
    return _pending;
  }

  Future<Directory> _dir() async {
    final dir = _directory ??=
        directory ??
        Directory(
          '${(await getTemporaryDirectory()).path}${Platform.pathSeparator}kirisaki_thumbnails',
        );
    await dir.create(recursive: true);
    return dir;
  }

  String _name(String key) => sha256.convert(utf8.encode(key)).toString();

  Future<void> _index(Directory dir) async {
    if (_indexed) return;
    final entries = <MapEntry<File, FileStat>>[];
    await for (final entity in dir.list()) {
      if (entity is File) entries.add(MapEntry(entity, await entity.stat()));
    }
    entries.sort((a, b) => a.value.modified.compareTo(b.value.modified));
    _sizes.clear();
    _total = 0;
    for (final entry in entries) {
      _sizes[entry.key.path] = entry.value.size;
      _total += entry.value.size;
    }
    _indexed = true;
  }

  Future<Uint8List?> get(String key) async {
    try {
      final dir = await _dir();
      return await File('${dir.path}${Platform.pathSeparator}${_name(key)}')
          .readAsBytes();
    } catch (_) {
      return null;
    }
  }

  Future<void> put(String key, Uint8List bytes) => _enqueue(() async {
    if (bytes.length > maxBytes) return;
    final dir = await _dir();
    await _index(dir);
    final file = File('${dir.path}${Platform.pathSeparator}${_name(key)}');
    // Readers see either the previous complete entry or the new complete entry.
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsBytes(bytes, flush: false);
    await temporary.rename(file.path);
    _total -= _sizes.remove(file.path) ?? 0;
    _sizes[file.path] = bytes.length;
    _total += bytes.length;
    while (_total > maxBytes && _sizes.isNotEmpty) {
      final path = _sizes.keys.first;
      final old = File(path);
      if (await old.exists()) await old.delete();
      _total -= _sizes.remove(path)!;
    }
  });

  Future<void> clear() => _enqueue(() async {
    final dir = await _dir();
    await dir.delete(recursive: true);
    _directory = null;
    _sizes.clear();
    _total = 0;
    _indexed = false;
  });

  Future<int> get sizeBytes async {
    await _enqueue(() async => _index(await _dir()));
    return _total;
  }
}
