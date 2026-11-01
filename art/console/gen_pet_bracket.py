#!/usr/bin/env python3
"""Generate the stone trapezoid bracket texture for party pet frames.
Melded onto the bottom edge of the console under each party member.

    python3 art/console/gen_pet_bracket.py -> WoW/Interface/AddOns/Medaluin/media/pet-bracket.tga
"""
import os
import subprocess
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
ADDON = os.path.join(ROOT, "WoW", "Interface", "AddOns", "Medaluin")
MEDIA = os.path.join(ADDON, "media")
OUT_TGA = os.path.join(MEDIA, "pet-bracket.tga")
OUT_PNG = os.path.join(HERE, "render", "pet-bracket.png")


def generate():
    W, H = 129, 18
    tex_w, tex_h = 256, 32
    img = Image.new("RGBA", (tex_w, tex_h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    # Base stone trapezoid:
    # Top: (0, 0) to (W-1, 0)
    # Bottom: (14, H-1) to (W-15, H-1)
    poly = [(0, 0), (W - 1, 0), (W - 15, H - 1), (14, H - 1)]
    d.polygon(poly, fill=(37, 41, 53, 255))

    # Left wing outer highlight \ (light from top-left)
    d.line([(0, 0), (14, H - 1)], fill=(160, 145, 100, 255), width=1)
    d.line([(1, 0), (15, H - 1)], fill=(120, 110, 80, 255), width=1)

    # Right wing outer shadow / (shadow side)
    d.line([(W - 1, 0), (W - 15, H - 1)], fill=(55, 52, 48, 255), width=1)
    d.line([(W - 2, 0), (W - 16, H - 1)], fill=(45, 42, 38, 255), width=1)

    # Bottom rim bevels
    d.line([(14, H - 1), (W - 15, H - 1)], fill=(145, 130, 90, 255), width=1)
    d.line([(15, H - 2), (W - 16, H - 2)], fill=(95, 88, 70, 255), width=1)

    # Top seam connection (smooth transition into console art at y=136)
    d.line([(0, 0), (W - 1, 0)], fill=(37, 41, 53, 255), width=1)

    # Cutout window for the pet status bar (x = 14..114, y = 3..14, height 12)
    for y in range(3, 15):
        for x in range(14, W - 14):
            img.putpixel((x, y), (0, 0, 0, 0))

    # Inner window border (dark ink bevel around cutout)
    d.rectangle((13, 2, W - 14, 15), outline=(22, 22, 26, 255))
    d.line([(13, 15), (W - 14, 15)], fill=(80, 75, 60, 200), width=1)

    # Save PNG preview
    os.makedirs(os.path.dirname(OUT_PNG), exist_ok=True)
    img.save(OUT_PNG)
    print("Saved preview:", OUT_PNG)

    # Convert to 32-bit uncompressed TGA via magick
    tmp_png = OUT_TGA + ".tmp.png"
    img.save(tmp_png)
    os.makedirs(os.path.dirname(OUT_TGA), exist_ok=True)
    subprocess.run([
        "magick", tmp_png, "-define", "tga:compression=none",
        "-depth", "8", "-type", "TrueColorAlpha", OUT_TGA
    ], check=True)
    os.remove(tmp_png)
    print("Saved TGA:", OUT_TGA)


if __name__ == "__main__":
    generate()
