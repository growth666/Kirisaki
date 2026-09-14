import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'builtin_sources.dart';
import 'custom_source_store.dart';
import 'source_config.dart';

class SourceService extends ChangeNotifier {
  SourceService({CustomSourceStore? store, SharedPreferencesAsync? preferences})
    : _store = store ?? CustomSourceStore(),
      _preferences = preferences ?? SharedPreferencesAsync();

  static final SourceService instance = SourceService();
  static const enabledKey = 'builtin_source_enabled';
  final CustomSourceStore _store;
  final SharedPreferencesAsync _preferences;
  List<SourceConfig> _custom = [];
  Map<String, bool> _enabled = {};
  Future<void>? _loading;
  Future<void>? _queue;
  bool _loaded = false;

  List<SourceConfig> get custom => List.unmodifiable(_custom);
  List<SourceConfig> get all => [
    ...BuiltinSources.all.map(
      (s) => s.copyWith(enabled: _enabled[s.id] ?? s.enabled),
    ),
    ..._custom,
  ];
  List<SourceConfig> get enabled => all.where((s) => s.enabled).toList();
  bool isBuiltin(String id) => BuiltinSources.all.any((s) => s.id == id);

  Future<void> load() {
    if (_loaded) return Future.value();
    return _loading ??= _load().whenComplete(() => _loading = null);
  }

  Future<void> _load() async {
    final custom = await _store.load();
    final raw = await _preferences.getString(enabledKey);
    Map<String, bool> enabled = {};
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          enabled = {
            for (final entry in decoded.entries)
              if (entry.value is bool) entry.key as String: entry.value as bool,
          };
        }
      } on FormatException {
        // A damaged preference must not prevent loading custom sources.
      }
    }
    _custom = custom;
    _enabled = enabled;
    _loaded = true;
    notifyListeners();
  }

  // Serialize writes so rapid actions cannot overwrite another pending change.
  Future<void> _write(Future<void> Function() action) {
    Future<void> run() async {
      await load();
      await action();
      notifyListeners();
    }

    final result = _queue == null ? run() : _queue!.then((_) => run());
    final tail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    _queue = tail;
    tail.then((_) {
      if (identical(_queue, tail)) _queue = null;
    });
    return result;
  }

  Future<void> add(SourceConfig source) => _write(() async {
    if (source.id == BuiltinSources.recommend.id ||
        all.any((s) => s.id == source.id)) {
      throw StateError('图源 id 已存在：${source.id}');
    }
    final next = [..._custom, source];
    await _store.save(next);
    _custom = next;
  });

  Future<void> update(String id, SourceConfig source) => _write(() async {
    if (id != source.id) throw StateError('编辑时不能修改图源 id');
    if (!_custom.any((s) => s.id == id)) throw StateError('自定义图源不存在');
    final next = _custom.map((s) => s.id == id ? source : s).toList();
    await _store.save(next);
    _custom = next;
  });

  Future<void> setEnabled(String id, bool value) => _write(() async {
    if (isBuiltin(id)) {
      final next = {..._enabled, id: value};
      await _preferences.setString(enabledKey, jsonEncode(next));
      _enabled = next;
    } else {
      if (!_custom.any((s) => s.id == id)) throw StateError('自定义图源不存在');
      final next = _custom
          .map((s) => s.id == id ? s.copyWith(enabled: value) : s)
          .toList();
      await _store.save(next);
      _custom = next;
    }
  });

  Future<void> remove(String id) => _write(() async {
    if (isBuiltin(id)) throw StateError('内置图源只能禁用');
    final next = _custom.where((s) => s.id != id).toList();
    await _store.save(next);
    _custom = next;
  });

  Future<void> reset() => _write(() async {
    await _preferences.setString(enabledKey, '{}');
    try {
      await _store.save([]);
    } catch (_) {
      await _preferences.setString(enabledKey, jsonEncode(_enabled));
      rethrow;
    }
    _custom = [];
    _enabled = {};
  });
}
