import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

import '../settings/settings_service.dart';

/// Small, offline vocabulary. Unknown or compound queries are never translated.
class ChineseSearchEntry {
  const ChineseSearchEntry(
    this.label,
    this.aliases,
    this.booru,
    this.zerochan, {
    this.danbooru,
    this.adult = false,
  });

  final String label;
  final List<String> aliases;
  final String? booru;
  final String? zerochan;
  final String? danbooru;
  final bool adult;

  String? keywordFor(String sourceId) => switch (sourceId) {
    'safebooru' => booru,
    'danbooru_safe' => danbooru ?? booru,
    'zerochan' => zerochan ?? booru,
    _ => null,
  };
}

abstract final class ChineseSearchDictionary {
  static bool containsChinese(String text) =>
      RegExp(r'[\u3400-\u9fff]').hasMatch(text);

  static Future<List<ChineseSearchEntry>>? _cached;
  static List<ChineseSearchEntry>? _entries;
  static final _indexes = Expando<Map<int, List<int>>>();

  static Iterable<ChineseSearchEntry> _candidates(
    List<ChineseSearchEntry> entries,
    String query,
  ) {
    final index = _indexes[entries] ??= _buildIndex(entries);
    List<int>? smallest;
    for (final char in query.runes.toSet()) {
      final ids = index[char];
      if (ids == null) return const [];
      if (smallest == null || ids.length < smallest.length) smallest = ids;
    }
    return (smallest ?? const <int>[]).map((id) => entries[id]);
  }

  static Map<int, List<int>> _buildIndex(List<ChineseSearchEntry> entries) {
    final index = <int, List<int>>{};
    for (var i = 0; i < entries.length; i++) {
      for (final char
          in entries[i].aliases.expand((alias) => alias.runes).toSet()) {
        (index[char] ??= []).add(i);
      }
    }
    return index;
  }

  static Future<List<ChineseSearchEntry>> load() async {
    if (_entries != null) return _entries!;
    return _cached ??= _load();
  }

  static Future<List<ChineseSearchEntry>> _load() async {
    try {
      final curated = await rootBundle.loadString(
        'assets/search/keywords.json',
      );
      final imported = await rootBundle.loadString(
        'assets/search/danbooru_local.json',
      );
      final entries = await compute<List<String>, List<ChineseSearchEntry>>(
        _merge,
        [curated, imported],
      );
      _entries = entries;
      return entries;
    } catch (_) {
      _cached = null;
      rethrow;
    }
  }

  static List<ChineseSearchEntry> _merge(List<String> inputs) {
    final curated = parse(inputs[0]);
    final rows =
        (jsonDecode(inputs[1]) as Map<String, dynamic>)['rows'] as List;
    final byTag = {for (final entry in curated) entry.booru: entry};
    final result = <ChineseSearchEntry>[];
    final replaced = <String>{};
    for (final raw in rows) {
      final row = raw as List;
      final tag = row[0] as String;
      final aliases = (row[1] as List).cast<String>();
      final existing = byTag[tag];
      final category = switch (row[2]) {
        4 => '角色',
        3 => '作品',
        _ => '标签',
      };
      result.add(
        ChineseSearchEntry(
          existing?.label ?? '${aliases.first} · $category · $tag',
          List.unmodifiable({...?existing?.aliases, ...aliases}),
          tag,
          existing?.zerochan,
          danbooru: existing?.danbooru,
          adult: row[4] != '0',
        ),
      );
      replaced.add(tag);
    }
    // Curated corrections precede upstream entries; retain original Zerochan mappings.
    final order = {
      for (var i = 0; i < curated.length; i++) curated[i].booru: i,
    };
    final upstreamOrder = {
      for (var i = 0; i < result.length; i++) result[i]: i,
    };
    result.sort((a, b) {
      final priority = (order[a.booru] ?? curated.length).compareTo(
        order[b.booru] ?? curated.length,
      );
      return priority != 0
          ? priority
          : upstreamOrder[a]!.compareTo(upstreamOrder[b]!);
    });
    return List.unmodifiable([
      ...curated.where((entry) => !replaced.contains(entry.booru)),
      ...result,
    ]);
  }

  static List<ChineseSearchEntry> parse(String text) {
    final data = jsonDecode(text);
    if (data is! Map || data['version'] != 1 || data['entries'] is! List) {
      throw const FormatException('Invalid dictionary schema');
    }
    final labels = <String>{};
    final entries = <ChineseSearchEntry>[];
    for (final row in data['entries'] as List) {
      if (row is! Map ||
          row['label'] is! String ||
          (row['label'] as String).trim().isEmpty ||
          !labels.add(row['label'] as String) ||
          row['aliases'] is! List ||
          (row['aliases'] as List).isEmpty) {
        throw const FormatException('Invalid or duplicate dictionary entry');
      }
      final aliases = <String>[];
      for (final alias in row['aliases'] as List) {
        if (alias is! String ||
            alias.trim().isEmpty ||
            aliases.contains(alias.trim())) {
          throw const FormatException('Invalid alias');
        }
        aliases.add(alias.trim());
      }
      String? tag(String key) {
        final value = row[key];
        if (value == null) return null;
        if (value is! String ||
            value.trim().isEmpty ||
            RegExp(r'[\r\n]').hasMatch(value)) {
          throw const FormatException('Invalid source tag');
        }
        return value.trim();
      }

      final booru = tag('booru');
      final zerochan = tag('zerochan');
      if (booru == null && zerochan == null) {
        throw const FormatException('Missing source tags');
      }
      entries.add(
        ChineseSearchEntry(
          row['label'] as String,
          List.unmodifiable(aliases),
          booru,
          zerochan,
          danbooru: tag('danbooru'),
        ),
      );
    }
    return List.unmodifiable(entries);
  }

  static Future<List<ChineseSearchEntry>> lookup(
    String text,
    String sourceId,
  ) async => _candidates(await load(), text.trim())
      .where(
        (entry) =>
            entry.aliases.contains(text.trim()) &&
            (!entry.adult || SettingsService.instance.showAdultContent) &&
            entry.keywordFor(sourceId) != null,
      )
      .take(30)
      .toList();

  /// Exact aliases first, then prefixes and substrings. No network requests.
  static List<ChineseSearchEntry> suggest(
    List<ChineseSearchEntry> entries,
    String text,
    String sourceId,
  ) {
    final query = text.trim();
    if (query.isEmpty || !containsChinese(query)) return [];
    int rank(ChineseSearchEntry entry) {
      if (entry.aliases.contains(query)) return 0;
      if (entry.aliases.any((alias) => alias.startsWith(query))) return 1;
      return 2;
    }

    final matches = _candidates(entries, query)
        .where(
          (entry) =>
              entry.keywordFor(sourceId) != null &&
              (!entry.adult || SettingsService.instance.showAdultContent) &&
              entry.aliases.any((alias) => alias.contains(query)),
        )
        .toList();
    final order = {for (var i = 0; i < matches.length; i++) matches[i]: i};
    matches.sort((a, b) {
      final priority = rank(a).compareTo(rank(b));
      return priority != 0 ? priority : order[a]!.compareTo(order[b]!);
    });
    return matches.take(8).toList();
  }
}
