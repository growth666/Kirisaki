import 'image_item.dart';

bool isAdultImage(ImageItem item) {
  // Danbooru s = sensitive; legacy Moebooru s = safe. Keep s visible,
  // hide questionable/explicit consistently, without guessing unknown ratings.
  const hiddenRatings = {'q', 'e', 'questionable', 'explicit', 'adult', 'nsfw'};
  if (hiddenRatings.contains(item.rating?.trim().toLowerCase())) return true;
  return item.tags.any((tag) {
    final normalized = tag.trim().toLowerCase();
    if (normalized.startsWith('rating:')) {
      return hiddenRatings.contains(normalized.substring(7).trim());
    }
    return const {
      'explicit',
      'questionable',
      'nsfw',
      'adult',
      'r18',
      'r-18',
      '18+',
    }.contains(normalized);
  });
}
