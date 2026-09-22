import 'dart:typed_data';

class ThumbnailDiskCache {
  static final ThumbnailDiskCache instance = ThumbnailDiskCache();
  Future<Uint8List?> get(String key) async => null;
  Future<void> put(String key, Uint8List bytes) async {}
  Future<void> clear() async {}
  Future<int> get sizeBytes async => 0;
}
