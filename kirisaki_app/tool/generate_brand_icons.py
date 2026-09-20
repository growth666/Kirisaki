"""Regenerate Kirisaki's cropped portrait and platform icons (Python + Pillow)."""
import json
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
BACKGROUND = '#383838'
SOURCE = ROOT / 'assets/branding/source.png'


def render(size, rounded=False, inset=1):
    source = Image.open(SOURCE).convert('RGBA')
    # Coordinates use the 1888px-wide reference preview; retain source resolution.
    scale = source.width / 1888
    left = round(480 * scale)
    side = round(920 * scale)
    crop = source.crop((left, 0, left + side, side))
    canvas = Image.new('RGBA', (size, size), BACKGROUND)
    width = round(size * inset)
    crop = crop.resize((width, width), Image.Resampling.LANCZOS)
    canvas.alpha_composite(crop, ((size-width)//2, (size-width)//2))
    if rounded:
        mask = Image.new('L', (size*4, size*4))
        ImageDraw.Draw(mask).rounded_rectangle(
            (0, 0, size*4-1, size*4-1), radius=size*4*.22, fill=255)
        canvas.putalpha(mask.resize((size, size), Image.Resampling.LANCZOS))
    return canvas


def save(image, relative):
    path = ROOT / relative
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.stem + '.tmp' + path.suffix)
    image.save(temporary)
    temporary.replace(path)


def main():
    brand = ROOT / 'assets/branding'
    brand.mkdir(parents=True, exist_ok=True)
    save(render(1024).convert('RGB'), 'assets/branding/kirisaki.png')
    save(render(512, rounded=True), 'assets/branding/preview.png')
    for density, size in [('mdpi', 48), ('hdpi', 72), ('xhdpi', 96),
                          ('xxhdpi', 144), ('xxxhdpi', 192)]:
        save(render(size, rounded=True),
             f'android/app/src/main/res/mipmap-{density}/ic_launcher.png')
    res = ROOT / 'android/app/src/main/res'
    (res / 'drawable').mkdir(exist_ok=True)
    # The adaptive layer is inset into the 108dp canvas; Android applies
    # launcher masks to the central region. Keep the original photo intact.
    save(render(1024, inset=.62),
         'android/app/src/main/res/drawable-nodpi/ic_launcher_portrait.png')
    (res / 'drawable/ic_launcher_foreground.xml').write_text(
        '<bitmap xmlns:android="http://schemas.android.com/apk/res/android" '
        'android:src="@drawable/ic_launcher_portrait" android:gravity="fill"/>\n',
        encoding='utf-8')
    (res / 'mipmap-anydpi-v26').mkdir(exist_ok=True)
    (res / 'mipmap-anydpi-v26/ic_launcher.xml').write_text(
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        f'  <background android:drawable="@color/ic_launcher_background"/>\n'
        '  <foreground android:drawable="@drawable/ic_launcher_foreground"/>\n'
        '</adaptive-icon>\n', encoding='utf-8')
    (res / 'values/ic_launcher_colors.xml').write_text(
        f'<resources><color name="ic_launcher_background">{BACKGROUND}</color></resources>\n',
        encoding='utf-8')
    for platform in ('ios', 'macos'):
        folder = f'{platform}/Runner/Assets.xcassets/AppIcon.appiconset'
        entries = json.loads((ROOT / folder / 'Contents.json').read_text())['images']
        for entry in entries:
            size = round(float(entry['size'].split('x')[0]) * float(entry['scale'][:-1]))
            image = render(size, rounded=platform == 'macos')
            save(image.convert('RGB') if platform == 'ios' else image,
                 f"{folder}/{entry['filename']}")
    render(256, rounded=True).save(ROOT / 'windows/runner/resources/app_icon.ico',
                                  sizes=[(s, s) for s in (16, 24, 32, 48, 64, 128, 256)])
    for size in (192, 512):
        save(render(size), f'web/icons/Icon-{size}.png')
        save(render(size, inset=.8), f'web/icons/Icon-maskable-{size}.png')
    save(render(32, rounded=True), 'web/favicon.png')
    print('Generated cropped portrait, preview and platform icons.')


if __name__ == '__main__':
    main()
