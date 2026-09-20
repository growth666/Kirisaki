import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Persist only explicit choices, keyed by source, content mode and dictionary tag.
class ConfirmedTagService {
  static const storageKey = 'confirmed_search_tags_v1';
  static Future<void>? _pending;

  Future<Map<String, dynamic>> _read() async {
    final raw = await SharedPreferencesAsync().getString(storageKey);
    if (raw == null) return {};
    final data = jsonDecode(raw);
    if (data is! Map<String, dynamic>) {
      throw const FormatException('标签记录格式错误');
    }
    return data;
  }

  String _key(String scope, String tag) => jsonEncode([scope, tag.trim()]);

  Future<String?> lookup(String scope, String tag) async {
    if (_pending != null) await _pending;
    final value = (await _read())[_key(scope, tag)];
    return value is String && value.trim().isNotEmpty ? value : null;
  }

  Future<void> _write(Future<void> Function() action) {
    final operation = (_pending ?? Future<void>.value()).then((_) => action());
    final settled = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    _pending = settled;
    settled.then((_) {
      if (identical(_pending, settled)) _pending = null;
    });
    return operation;
  }

  Future<void> save(String scope, String tag, String selected) =>
      _write(() async {
        if (tag.trim().isEmpty || selected.trim().isEmpty) return;
        final data = await _read();
        data[_key(scope, tag)] = selected.trim();
        await SharedPreferencesAsync().setString(storageKey, jsonEncode(data));
      });

  Future<void> clear() =>
      _write(() => SharedPreferencesAsync().remove(storageKey));
}
