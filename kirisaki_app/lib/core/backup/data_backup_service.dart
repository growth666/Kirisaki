import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Export/import user data only. Image files and cache contents are excluded.
class DataBackupService {
  static const schemaVersion = 1;
  static const _keys = <String>[
    'favorite_images',
    'browse_history',
    'search_history',
    'download_records',
    'custom_sources',
    'builtin_source_enabled',
    'confirmed_search_tags_v1',
    'theme_mode',
    'download_dir',
    'show_adult_content',
    'refresh_rate_mode',
  ];

  Future<Map<String, Object?>> createBackup() async {
    final prefs = SharedPreferencesAsync();
    final data = <String, Object?>{};
    for (final key in _keys) {
      final value = _booleanKeys.contains(key)
          ? await prefs.getBool(key)
          : await prefs.getString(key);
      if (value != null) data[key] = value;
    }
    return {
      'schema': schemaVersion,
      'app': 'Kirisaki',
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'data': data,
    };
  }

  static const _booleanKeys = {'show_adult_content'};

  Future<String?> exportToFile() async {
    final location = await getSaveLocation(
      suggestedName: 'kirisaki-backup.json',
      acceptedTypeGroups: [
        XTypeGroup(label: 'JSON', extensions: ['json']),
      ],
    );
    if (location == null) return null;
    final file = XFile.fromData(
      utf8.encode(
        const JsonEncoder.withIndent('  ').convert(await createBackup()),
      ),
      name: 'kirisaki-backup.json',
      mimeType: 'application/json',
    );
    await file.saveTo(location.path);
    return location.path;
  }

  Future<bool> restoreFromFile() async {
    final file = await openFile(
      acceptedTypeGroups: [
        XTypeGroup(label: 'JSON', extensions: ['json']),
      ],
    );
    if (file == null) return false;
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map ||
        decoded['schema'] != schemaVersion ||
        decoded['data'] is! Map) {
      throw const FormatException('不是受支持的 Kirisaki 备份文件');
    }
    final data = (decoded['data'] as Map).cast<String, Object?>();
    final prefs = SharedPreferencesAsync();
    for (final key in _keys) {
      if (!data.containsKey(key)) continue;
      final value = data[key];
      if (value is bool) {
        await prefs.setBool(key, value);
      } else if (value is String) {
        await prefs.setString(key, value);
      } else if (value is List || value is Map) {
        await prefs.setString(key, jsonEncode(value));
      }
    }
    return true;
  }
}
