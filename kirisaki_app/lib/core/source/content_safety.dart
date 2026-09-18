import 'image_item.dart';

bool isAdultImage(ImageItem item) {
  final text = item.tags.join(' ').toLowerCase();
  return RegExp(r'(^|[ _:-])(explicit|nsfw|adult|rating:e|rating:q|rating:explicit)([ _:-]|$)').hasMatch(text);
}
