import 'package:flutter_test/flutter_test.dart';
import 'package:kirisaki_app/core/settings/settings_service.dart';
import 'package:kirisaki_app/core/source/chinese_search_dictionary.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'upstream-only aliases match and content switch filters candidates',
    () async {
      final entries = await ChineseSearchDictionary.load();
      final imported = entries.firstWhere((e) => e.booru == 'solo');
      expect(
        await ChineseSearchDictionary.lookup('独图', 'danbooru_safe'),
        contains(imported),
      );
      expect(imported.zerochan, isNull);
      final adult = entries.firstWhere(
        (e) =>
            e.adult && ChineseSearchDictionary.containsChinese(e.aliases.first),
      );
      final settings = SettingsService.instance;
      final original = settings.showAdultContent;
      try {
        await settings.setShowAdultContent(false);
        expect(
          ChineseSearchDictionary.suggest(
            [adult],
            adult.aliases.first,
            'danbooru_safe',
          ),
          isEmpty,
        );
        await settings.setShowAdultContent(true);
        expect(
          ChineseSearchDictionary.suggest(
            [adult],
            adult.aliases.first,
            'danbooru_safe',
          ),
          contains(adult),
        );
      } finally {
        await settings.setShowAdultContent(original);
      }
    },
  );
  test(
    'Naruto uses verified Danbooru override without changing other sites',
    () async {
      final entry = (await ChineseSearchDictionary.lookup(
        '火影忍者',
        'danbooru_safe',
      )).first;
      expect(entry.keywordFor('danbooru_safe'), 'naruto_(series)');
      expect(entry.keywordFor('safebooru'), 'naruto');
      expect(entry.keywordFor('zerochan'), 'NARUTO');
    },
  );
  test(
    'partial names rank exact aliases first and respect source support',
    () async {
      final entries = await ChineseSearchDictionary.load();
      expect(
        ChineseSearchDictionary.suggest(entries, '中野', 'zerochan'),
        hasLength(8),
      );
      expect(
        ChineseSearchDictionary.suggest(entries, '小樱', 'zerochan'),
        hasLength(2),
      );
      expect(
        ChineseSearchDictionary.suggest(entries, '花', 'safebooru').first.label,
        '花朵',
      );
      expect(ChineseSearchDictionary.suggest(entries, '中野', 'custom'), isEmpty);
      expect(ChineseSearchDictionary.suggest(entries, '', 'zerochan'), isEmpty);
    },
  );
  test('Chinese aliases resolve to source-specific character tags', () async {
    final entry = (await ChineseSearchDictionary.lookup(
      ' 雷姆 ',
      'zerochan',
    )).first;
    expect(entry.keywordFor('zerochan'), 'Rem (Re:Zero)');
    expect(entry.keywordFor('danbooru_safe'), 'rem_(re:zero)');
  });
  test(
    'bundled vocabulary contains basic terms and preserves source differences',
    () async {
      expect((await ChineseSearchDictionary.load()).length, greaterThan(53000));
      expect(
        (await ChineseSearchDictionary.lookup('樱花', 'safebooru')).first.booru,
        'cherry_blossoms',
      );
      expect(
        (await ChineseSearchDictionary.lookup('海邊', 'zerochan')).first.zerochan,
        'Beach',
      );
      expect(await ChineseSearchDictionary.lookup('女孩', 'zerochan'), isNotEmpty);
      expect(
        (await ChineseSearchDictionary.lookup(
          '女孩',
          'danbooru_safe',
        )).first.booru,
        '1girl',
      );
    },
  );
  test(
    'character nicknames, traditional names and ambiguous aliases',
    () async {
      expect(
        (await ChineseSearchDictionary.lookup('炮姐', 'safebooru')).first.booru,
        'misaka_mikoto',
      );
      expect(
        (await ChineseSearchDictionary.lookup(
          '亞絲娜',
          'zerochan',
        )).first.zerochan,
        'Yuuki Asuna',
      );
      final sakura = await ChineseSearchDictionary.lookup('小樱', 'zerochan');
      expect(
        sakura.map((entry) => entry.zerochan),
        containsAll(['Haruno Sakura', 'Kinomoto Sakura']),
      );
      expect(sakura, hasLength(2));
    },
  );
  test('reject malformed schema, missing tags and duplicate entries', () {
    for (final json in [
      '{}',
      '{"version":2,"entries":[]}',
      '{"version":1,"entries":[{"label":"a","aliases":["a"]}]}',
      '{"version":1,"entries":[{"label":"a","aliases":[1],"booru":"a"}]}',
      '{"version":1,"entries":[{"label":"a","aliases":["a"],"booru":"a"},{"label":"a","aliases":["b"],"booru":"b"}]}',
    ]) {
      expect(() => ChineseSearchDictionary.parse(json), throwsFormatException);
    }
  });
  test('unknown, compound and custom-source queries are not guessed', () async {
    expect(await ChineseSearchDictionary.lookup('蕾姆 女仆', 'zerochan'), isEmpty);
    expect(await ChineseSearchDictionary.lookup('未收录人物', 'safebooru'), isEmpty);
    expect(await ChineseSearchDictionary.lookup('蕾姆', 'custom'), isEmpty);
    expect(ChineseSearchDictionary.containsChinese('rem_(re:zero)'), isFalse);
  });
}
