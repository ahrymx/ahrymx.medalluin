#!/usr/bin/env python3
"""The game menu's Medallion chain bar (window/gamemenu.lua): a short metal
bar, stretched between two medallions and turned with SetRotation.

    python3 art/widgets/gen_gamemenu.py   -> media/gamemenu-bar.tga

64x16: the bar is the middle 8 rows (transparent above and below, so a
turned bar's edges stay soft), shaded across its width like round metal:
a dark edge, the gold body, a bright line just above the middle. The
columns are all alike, so it stretches to any length.
"""
import os
import subprocess

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..", "..")
MEDIA = os.path.join(ROOT, "WoW", "Interface", "AddOns", "Medalluin", "media", "gamemenu-bar.tga")
OUT = os.path.join(HERE, "render")

W, H = 64, 16
DARK, MID, HI = (60, 46, 20), (138, 112, 52), (250, 228, 160)
# the bar's rows, top to bottom: (colour, alpha), the outer rows half-covered
ROWS = [
    (DARK, 0.5), (MID, 1), (HI, 1), (HI, 1), ((196, 165, 87), 1), (MID, 1), (DARK, 1), (DARK, 0.5),
]


def bar():
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    top = (H - len(ROWS)) // 2
    for i, (c, a) in enumerate(ROWS):
        for x in range(W):
            im.putpixel((x, top + i), c + (int(255 * a),))
    return im


def main():
    os.makedirs(OUT, exist_ok=True)
    tmp = os.path.join(OUT, "gamemenu-bar.png")
    bar().save(tmp)
    subprocess.run(["magick", tmp, "-define", "tga:compression=none", MEDIA], check=True)
    print(MEDIA)


if __name__ == "__main__":
    main()
