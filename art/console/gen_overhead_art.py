#!/usr/bin/env python3
"""Generate the slate-and-gold textures for the top-of-screen trapezoid console:
1. overhead-left.tga (64x32): Left wing terminal cap with sloped gold bevel
2. overhead-right.tga (64x32): Right wing terminal cap with sloped gold bevel
3. overhead-mid.tga (32x32): Center stone bridge piece with bottom gold bevel
4. overhead-seam.tga (16x32): Vertical stone divider seam between columns
5. overhead-boss-plate.tga (64x32): Stackable boss frame plate
"""
import os
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
MEDIA = os.path.join(HERE, "..", "..", "WoW", "Interface", "AddOns", "Medaluin", "media")
RENDER = os.path.join(HERE, "render")

os.makedirs(MEDIA, exist_ok=True)
os.makedirs(RENDER, exist_ok=True)

SS = 8
H_BASE = 28
SLOPE_BASE = 14


def gen_left_cap():
    W, H = 64, 32
    bw, bh = W * SS, H * SS
    img = Image.new("RGBA", (bw, bh), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    h_ss = H_BASE * SS
    slope_ss = SLOPE_BASE * SS

    # Polygon points: (0, 0) -> (bw - 1, 0) -> (bw - 1, h_ss - 1) -> (slope_ss, h_ss - 1) -> (0, 0)
    poly = [
        (0, 0),
        (bw - 1, 0),
        (bw - 1, h_ss - 1),
        (slope_ss, h_ss - 1)
    ]

    # 1. Slate stone body fill
    d.polygon(poly, fill=(37, 41, 53, 255))

    # 2. Outer gold/bronze bevel on sloped wing and bottom rim
    gold = (152, 138, 96, 255)
    gold_hi = (175, 162, 118, 255)
    line_w = int(1.4 * SS)

    # Sloped left edge
    d.line([(0, 0), (slope_ss, h_ss - 1)], fill=gold_hi, width=line_w)
    # Bottom rim
    d.line([(slope_ss, h_ss - 1), (bw - 1, h_ss - 1)], fill=gold, width=line_w)

    # Inner subtle stone highlight along slope
    d.line([(int(1.2 * SS), 0), (slope_ss + int(1.2 * SS), h_ss - 1 - int(1.2 * SS))],
           fill=(48, 54, 68, 200), width=int(0.8 * SS))

    # Top edge flush into screen top
    d.line([(0, 0), (bw - 1, 0)], fill=(42, 46, 58, 255), width=int(1.0 * SS))

    res = img.resize((W, H), Image.Resampling.LANCZOS)
    # Clear any pixels outside [0..W-1, 0..H_BASE-1]
    px = res.load()
    for y in range(H):
        for x in range(W):
            if y >= H_BASE:
                px[x, y] = (0, 0, 0, 0)

    res.save(os.path.join(MEDIA, "overhead-left.tga"))
    res.save(os.path.join(RENDER, "overhead-left.png"))
    print("Generated overhead-left.tga")


def gen_right_cap():
    W, H = 64, 32
    bw, bh = W * SS, H * SS
    img = Image.new("RGBA", (bw, bh), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    h_ss = H_BASE * SS
    slope_ss = SLOPE_BASE * SS

    # Polygon: (0, 0) -> (bw - 1, 0) -> (bw - 1 - slope_ss, h_ss - 1) -> (0, h_ss - 1)
    poly = [
        (0, 0),
        (bw - 1, 0),
        (bw - 1 - slope_ss, h_ss - 1),
        (0, h_ss - 1)
    ]

    # 1. Slate stone body fill
    d.polygon(poly, fill=(37, 41, 53, 255))

    gold = (152, 138, 96, 255)
    line_w = int(1.4 * SS)

    # Sloped right edge
    d.line([(bw - 1, 0), (bw - 1 - slope_ss, h_ss - 1)], fill=gold, width=line_w)
    # Bottom rim
    d.line([(0, h_ss - 1), (bw - 1 - slope_ss, h_ss - 1)], fill=gold, width=line_w)

    # Inner subtle stone highlight along slope
    d.line([(bw - 1 - int(1.2 * SS), 0), (bw - 1 - slope_ss - int(1.2 * SS), h_ss - 1 - int(1.2 * SS))],
           fill=(48, 54, 68, 200), width=int(0.8 * SS))

    # Top edge flush into screen top
    d.line([(0, 0), (bw - 1, 0)], fill=(42, 46, 58, 255), width=int(1.0 * SS))

    res = img.resize((W, H), Image.Resampling.LANCZOS)
    px = res.load()
    for y in range(H):
        for x in range(W):
            if y >= H_BASE:
                px[x, y] = (0, 0, 0, 0)

    res.save(os.path.join(MEDIA, "overhead-right.tga"))
    res.save(os.path.join(RENDER, "overhead-right.png"))
    print("Generated overhead-right.tga")


def gen_mid_piece():
    W, H = 32, 32
    bw, bh = W * SS, H * SS
    img = Image.new("RGBA", (bw, bh), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    h_ss = H_BASE * SS

    # Rectangle: (0, 0) to (bw - 1, h_ss - 1)
    d.rectangle([0, 0, bw - 1, h_ss - 1], fill=(37, 41, 53, 255))

    gold = (152, 138, 96, 255)
    line_w = int(1.4 * SS)

    # Bottom rim bevel
    d.line([(0, h_ss - 1), (bw - 1, h_ss - 1)], fill=gold, width=line_w)
    # Top seam
    d.line([(0, 0), (bw - 1, 0)], fill=(42, 46, 58, 255), width=int(1.0 * SS))

    res = img.resize((W, H), Image.Resampling.LANCZOS)
    px = res.load()
    for y in range(H):
        for x in range(W):
            if y >= H_BASE:
                px[x, y] = (0, 0, 0, 0)

    res.save(os.path.join(MEDIA, "overhead-mid.tga"))
    res.save(os.path.join(RENDER, "overhead-mid.png"))
    print("Generated overhead-mid.tga")


def gen_seam_divider():
    W, H = 16, 32
    bw, bh = W * SS, H * SS
    img = Image.new("RGBA", (bw, bh), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    h_ss = H_BASE * SS
    cx = bw // 2

    # Vertical divider: dark cleft on left, gold/stone seam in center
    d.line([(cx - int(1.5 * SS), 0), (cx - int(1.5 * SS), h_ss - 1)], fill=(18, 20, 26, 230), width=int(1.6 * SS))
    d.line([(cx, 0), (cx, h_ss - 1)], fill=(145, 130, 90, 255), width=int(1.2 * SS))
    d.line([(cx + int(1.5 * SS), 0), (cx + int(1.5 * SS), h_ss - 1)], fill=(48, 54, 68, 180), width=int(1.0 * SS))

    # Bottom seam join
    d.line([(0, h_ss - 1), (bw - 1, h_ss - 1)], fill=(152, 138, 96, 255), width=int(1.4 * SS))

    res = img.resize((W, H), Image.Resampling.LANCZOS)
    px = res.load()
    for y in range(H):
        for x in range(W):
            if y >= H_BASE:
                px[x, y] = (0, 0, 0, 0)

    res.save(os.path.join(MEDIA, "overhead-seam.tga"))
    res.save(os.path.join(RENDER, "overhead-seam.png"))
    print("Generated overhead-seam.tga")


def gen_boss_plate():
    # Stackable rectangular plate with gold bevels on left, right, and bottom edges
    W, H = 64, 32
    bw, bh = W * SS, H * SS
    img = Image.new("RGBA", (bw, bh), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    h_ss = H_BASE * SS
    d.rectangle([0, 0, bw - 1, h_ss - 1], fill=(37, 41, 53, 255))

    gold = (152, 138, 96, 255)
    line_w = int(1.4 * SS)

    # Left edge
    d.line([(0, 0), (0, h_ss - 1)], fill=gold, width=line_w)
    # Right edge
    d.line([(bw - 1, 0), (bw - 1, h_ss - 1)], fill=gold, width=line_w)
    # Bottom edge
    d.line([(0, h_ss - 1), (bw - 1, h_ss - 1)], fill=gold, width=line_w)
    # Top seam
    d.line([(0, 0), (bw - 1, 0)], fill=(42, 46, 58, 255), width=int(1.0 * SS))

    res = img.resize((W, H), Image.Resampling.LANCZOS)
    px = res.load()
    for y in range(H):
        for x in range(W):
            if y >= H_BASE:
                px[x, y] = (0, 0, 0, 0)

    res.save(os.path.join(MEDIA, "overhead-boss-plate.tga"))
    res.save(os.path.join(RENDER, "overhead-boss-plate.png"))
    print("Generated overhead-boss-plate.tga")


if __name__ == "__main__":
    gen_left_cap()
    gen_right_cap()
    gen_mid_piece()
    gen_seam_divider()
    gen_boss_plate()
