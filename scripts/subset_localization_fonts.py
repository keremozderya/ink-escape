"""Create compact, renamed font subsets from Google Fonts' OFL sources.

Usage: python scripts/subset_localization_fonts.py /path/to/upstream/fonts
The directory must contain NotoSansArabic/SC/JP/KR.ttf and matching -OFL.txt.
Re-run after adding translated characters. Requires fontTools.
"""
from pathlib import Path
import shutil
import sys

from fontTools import subset
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / "assets/fonts"
SUFFIXES = ["Arabic", "SC", "JP", "KR"]


def build(source_dir):
    text = (ROOT / "lib/l10n/catalog.dart").read_text() + \
        (ROOT / "lib/l10n/ink_strings.dart").read_text()
    for suffix in SUFFIXES:
        original = f"NotoSans{suffix}"
        family = f"Ink{suffix}"
        font = TTFont(source_dir / f"{original}.ttf")
        font.recalcTimestamp = False
        if "fvar" in font:
            axes = {axis.axisTag: (400 if axis.axisTag == "wght" else axis.defaultValue)
                    for axis in font["fvar"].axes}
            instantiateVariableFont(font, axes, inplace=True)
        options = subset.Options()
        options.layout_features = ["*"]
        options.name_IDs = [0, 1, 2, 3, 4, 5, 6, 13, 14, 16, 17]
        sub = subset.Subsetter(options=options)
        sub.populate(text=text)
        sub.subset(font)
        for record in font["name"].names:
            replacement = {1: family, 2: "Regular", 3: family + " Regular",
                           4: family + " Regular", 6: family + "-Regular",
                           16: family, 17: "Regular"}.get(record.nameID)
            if replacement:
                record.string = replacement.encode(record.getEncoding())
        output = DEST / f"{family}.ttf"
        font.save(output)
        shutil.copyfile(source_dir / f"{original}-OFL.txt", DEST / f"{family}-OFL.txt")
        print(f"{output.name}: {output.stat().st_size:,} bytes")


if __name__ == "__main__":
    build(Path(sys.argv[1]))
