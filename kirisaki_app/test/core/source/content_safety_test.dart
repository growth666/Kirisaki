import 'package:flutter_test/flutter_test.dart';
import 'package:kirisaki_app/core/source/content_safety.dart';
import 'package:kirisaki_app/core/source/image_item.dart';
import 'package:kirisaki_app/core/source/moebooru_json_parser.dart';

void main() {
  test(
    'ratings survive parsing and persistence and hide questionable/explicit',
    () {
      for (final rating in ['e', 'q', 'explicit', 'questionable', 'E']) {
        final item = MoebooruJsonParser.parse(
          '[{"file_url":"/a.jpg","rating":"$rating"}]',
          baseUri: Uri.parse('https://example.test'),
        ).single;
        expect(isAdultImage(ImageItem.fromJson(item.toJson())), isTrue);
      }
    },
  );
  test('legacy records and safe or unknown ratings remain visible', () {
    for (final rating in [null, 's', 'g', 'safe', 'general', 'unknown']) {
      expect(isAdultImage(ImageItem(imageUrl: 'a', rating: rating)), isFalse);
    }
    expect(ImageItem.fromJson({'imageUrl': 'a'}).rating, isNull);
  });
  test('exact tags avoid matching adult characters or negated nsfw tags', () {
    for (final tag in [
      'adult',
      'nsfw',
      'rating:q',
      'rating:explicit',
      'R-18',
    ]) {
      expect(isAdultImage(ImageItem(imageUrl: 'a', tags: [tag])), isTrue);
    }
    for (final tag in ['adult_character', 'not_nsfw', 'sfw']) {
      expect(isAdultImage(ImageItem(imageUrl: 'a', tags: [tag])), isFalse);
    }
  });
}
