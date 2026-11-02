#!/usr/bin/env python3
"""Generate the stone trapezoid bracket texture for party pet frames.
Melded onto the bottom edge of the console under each party member,
with a pill-shaped cutout window in the trapezoid stone surface.

    python3 art/console/gen_pet_bracket.py -> WoW/Interface/AddOns/Medalluin/media/pet-bracket.tga
"""
import os
import subprocess
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
ADDON = os.path.join(ROOT, "WoW", "Interface", "AddOns", "Medalluin")
MEDIA = os.path.join(ADDON, "media")
OUT_TGA = os.path.join(MEDIA, "pet-bracket.tga")
OUT_PNG = os.path.join(HERE, "render", "pet-bracket.png")


def create_trapezoid_pill(W=129, H=18, pill_h=12, pill_pad=12):
    tex_w, tex_h = 256, 32
    ss = 8
    bw, bh = tex_w * ss, tex_h * ss
    img = Image.new("RGBA", (bw, bh), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    s_w, s_h = W * ss, H * ss
    slope_x = pill_pad * ss

    poly = [
        (0, 0),
        (s_w - 1, 0),
        (s_w - 1 - slope_x, s_h - 1),
        (slope_x, s_h - 1)
    ]

    # 1. Slate stone body fill
    d.polygon(poly, fill=(37, 41, 53, 255))

    # 2. Outer gold/bronze bevels along slopes and bottom rim
    gold = (152, 138, 96, 255)
    gold_hi = (175, 162, 118, 255)

    line_w = int(1.4 * ss)
    # Left wing bevel
    d.line([(0, 0), (slope_x, s_h - 1)], fill=gold_hi, width=line_w)
    # Right wing bevel
    d.line([(s_w - 1, 0), (s_w - 1 - slope_x, s_h - 1)], fill=gold, width=line_w)
    # Bottom rim bevel
    d.line([(slope_x, s_h - 1), (s_w - 1 - slope_x, s_h - 1)], fill=gold, width=line_w)

    # Inner subtle stone highlight along slopes
    d.line([(int(1.2 * ss), 0), (slope_x + int(1.2 * ss), s_h - 1 - int(1.2 * ss))],
           fill=(48, 54, 68, 200), width=int(0.8 * ss))
    d.line([(s_w - 1 - int(1.2 * ss), 0), (s_w - 1 - slope_x - int(1.2 * ss), s_h - 1 - int(1.2 * ss))],
           fill=(48, 54, 68, 200), width=int(0.8 * ss))

    # Top connection seam (flush into console bottom stone)
    d.line([(0, 0), (s_w - 1, 0)], fill=(42, 46, 58, 255), width=int(1.0 * ss))

    # 3. Pill-shaped cutout window inside the trapezoid surface
    cut_y0 = int(((H - pill_h) / 2) * ss)
    cut_y1 = cut_y0 + int(pill_h * ss) - 1
    cut_x0 = slope_x + int(1.2 * ss)
    cut_x1 = s_w - 1 - slope_x - int(1.2 * ss)
    cut_r = int((pill_h / 2) * ss)

    # Dark ink bevel around cutout window
    d.rounded_rectangle((cut_x0, cut_y0, cut_x1, cut_y1), radius=cut_r, outline=(20, 20, 24, 255), width=int(1.1 * ss))

    # Cutout hole (transparent where health bar and text show through)
    hole_x0 = cut_x0 + int(0.9 * ss)
    hole_y0 = cut_y0 + int(0.9 * ss)
    hole_x1 = cut_x1 - int(0.9 * ss)
    hole_y1 = cut_y1 - int(0.9 * ss)
    hole_r = cut_r - int(0.9 * ss)

    hole_mask = Image.new("L", (bw, bh), 0)
    hmd = ImageDraw.Draw(hole_mask)
    hmd.rounded_rectangle((hole_x0, hole_y0, hole_x1, hole_y1), radius=hole_r, fill=255)

    for y in range(hole_y0, hole_y1 + 1):
        for x in range(hole_x0, hole_x1 + 1):
            if hole_mask.getpixel((x, y)) > 0:
                img.putpixel((x, y), (0, 0, 0, 0))

    res = img.resize((tex_w, tex_h), Image.Resampling.LANCZOS)
    # Clear any Lanczos ringing outside [0..W-1, 0..H-1]
    px = res.load()
    for y in range(tex_h):
        for x in range(tex_w):
            if x >= W or y >= H:
                px[x, y] = (0, 0, 0, 0)
    return res


def generate():
    W, H = 129, 18
    img = create_trapezoid_pill(W, H, pill_h=12, pill_pad=12)

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
