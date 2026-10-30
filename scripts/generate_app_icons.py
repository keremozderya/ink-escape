"""Generate native launcher icons from assets/icon/app_icon.png.

Run from any directory with Python 3 and Pillow installed.
"""

import json
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/icon/app_icon.png"
ANDROID_RES = ROOT / "android/app/src/main/res"
IOS_ICONS = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
DENSITIES = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}
PAPER_COLOR = "#F3E2C4"


def save_png(image, path):
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, format="PNG", optimize=True)


def main():
    with Image.open(SOURCE) as source:
        if source.size != (1024, 1024) or source.mode != "RGB":
            raise ValueError("app_icon.png must be an opaque 1024 x 1024 RGB image")
        artwork = source.copy()

    for density, scale in DENSITIES.items():
        directory = ANDROID_RES / f"mipmap-{density}"
        size = round(48 * scale)
        save_png(artwork.resize((size, size), Image.Resampling.LANCZOS),
                 directory / "ic_launcher.png")

        # The complete supplied artwork sits in the 66 dp safe area of a
        # 108 dp layer. Android applies its own circle/squircle mask.
        layer_size = round(108 * scale)
        artwork_size = round(66 * scale)
        foreground = Image.new("RGBA", (layer_size, layer_size), (0, 0, 0, 0))
        offset = (layer_size - artwork_size) // 2
        foreground.paste(
            artwork.resize((artwork_size, artwork_size), Image.Resampling.LANCZOS),
            (offset, offset),
        )
        save_png(foreground, directory / "ic_launcher_foreground.png")

    adaptive_dir = ANDROID_RES / "mipmap-anydpi-v26"
    adaptive_dir.mkdir(parents=True, exist_ok=True)
    (adaptive_dir / "ic_launcher.xml").write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@color/ic_launcher_background" />\n'
        '    <foreground android:drawable="@mipmap/ic_launcher_foreground" />\n'
        '</adaptive-icon>\n',
        encoding="utf-8",
    )
    (ANDROID_RES / "values/ic_launcher_colors.xml").write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<resources>\n'
        f'    <color name="ic_launcher_background">{PAPER_COLOR}</color>\n'
        '</resources>\n',
        encoding="utf-8",
    )

    catalog = json.loads((IOS_ICONS / "Contents.json").read_text(encoding="utf-8"))
    generated = set()
    for entry in catalog["images"]:
        filename = entry["filename"]
        if filename in generated:
            continue
        width, height = (float(part) for part in entry["size"].split("x"))
        scale = float(entry["scale"].removesuffix("x"))
        size = (round(width * scale), round(height * scale))
        # iOS applies rounded corners; keep all pixels opaque and square.
        save_png(artwork.resize(size, Image.Resampling.LANCZOS), IOS_ICONS / filename)
        generated.add(filename)

    windows_icon = ROOT / "windows/runner/resources/app_icon.ico"
    artwork.save(windows_icon, format="ICO", sizes=[
        (16, 16), (24, 24), (32, 32), (48, 48),
        (64, 64), (128, 128), (256, 256),
    ])
    print(f"Generated 10 Android PNGs, adaptive resources, {len(generated)} iOS PNGs and Windows ICO.")


if __name__ == "__main__":
    main()
