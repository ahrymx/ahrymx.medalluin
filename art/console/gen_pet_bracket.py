#!/usr/bin/env python3
"""Generate the refined pill frame texture for party pet frames.
Sleek capsule/pill shape with rounded corners, consistent gold/bronze rim,
and dark ink bevel around the health bar cutout.

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


def create_pill(W=118, H=16, r=8):
    tex_w, tex_h = 256, 32
    ss = 8  # 8x supersampling for ultra smooth anti-aliased curves
    big_w, big_h = tex_w * ss, tex_h * ss
    img = Image.new("RGBA", (big_w, big_h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    s_w, s_h, s_r = W * ss, H * ss, r * ss

    # 1. Outer gold/bronze rim (1.5px in base coords = 12px in ss)
    # Slate stone fill
    d.rounded_rectangle(
        (0, 0, s_w - 1, s_h - 1),
        radius=s_r,
        fill=(37, 41, 53, 255),
        outline=(146, 134, 94, 255),
        width=int(1.5 * ss),
    )

    # 2. Subtle top highlight on the gold rim
    hi_mask = Image.new("L", (big_w, big_h), 0)
    hd = ImageDraw.Draw(hi_mask)
    hd.rounded_rectangle((0, 0, s_w - 1, s_h - 1), radius=s_r, outline=255, width=int(1.2 * ss))
    for y in range(s_h // 2, s_h):
        for x in range(s_w):
            hi_mask.putpixel((x, y), 0)

    hi_color = (175, 162, 118, 255)
    for y in range(0, s_h // 2):
        for x in range(0, s_w):
            if hi_mask.getpixel((x, y)) > 0:
                img.putpixel((x, y), hi_color)

    # 3. Inner stone bevel (slate highlight)
    d.rounded_rectangle(
        (int(1.5 * ss), int(1.5 * ss), s_w - 1 - int(1.5 * ss), s_h - 1 - int(1.5 * ss)),
        radius=s_r - int(1.5 * ss),
        outline=(48, 54, 68, 200),
        width=int(0.8 * ss),
    )

    # 4. Cutout window for status bar (inset 2px top/bottom, 3px left/right)
    cut_x0 = int(3.0 * ss)
    cut_y0 = int(2.0 * ss)
    cut_x1 = s_w - 1 - int(3.0 * ss)
    cut_y1 = s_h - 1 - int(2.0 * ss)
    cut_r = int((r - 2.0) * ss)

    # Dark ink bevel around cutout window
    d.rounded_rectangle(
        (cut_x0, cut_y0, cut_x1, cut_y1),
        radius=cut_r,
        outline=(20, 20, 24, 255),
        width=int(1.0 * ss),
    )

    # Cutout hole inside (transparent)
    hole_x0 = cut_x0 + int(0.9 * ss)
    hole_y0 = cut_y0 + int(0.9 * ss)
    hole_x1 = cut_x1 - int(0.9 * ss)
    hole_y1 = cut_y1 - int(0.9 * ss)
    hole_r = cut_r - int(0.9 * ss)

    hole_mask = Image.new("L", (big_w, big_h), 0)
    hmd = ImageDraw.Draw(hole_mask)
    hmd.rounded_rectangle((hole_x0, hole_y0, hole_x1, hole_y1), radius=hole_r, fill=255)

    for y in range(hole_y0, hole_y1 + 1):
        for x in range(hole_x0, hole_x1 + 1):
            if hole_mask.getpixel((x, y)) > 0:
                img.putpixel((x, y), (0, 0, 0, 0))

    # Downsample using Lanczos
    res = img.resize((tex_w, tex_h), Image.Resampling.LANCZOS)
    return res


def generate():
    W, H, r = 118, 16, 8
    img = create_pill(W, H, r)

    os.makedirs(os.path.dirname(OUT_PNG), exist_ok=True)
    img.save(OUT_PNG)
    print("Saved preview:", OUT_PNG)

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
