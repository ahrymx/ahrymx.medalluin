#!/usr/bin/env python3
"""Generate crisp UI icons for party frames:
1. ready-status.tga (128x32): checkmark (ready), cross (not ready), dash (undecided)
2. role-icons.tga (128x32): tank (shield), healer (cross), damager (sword)
(The resurrect icon is gen_wings.py's dead-wings.tga.)
"""
import os
import math
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
MEDIA = os.path.join(HERE, "..", "..", "WoW", "Interface", "AddOns", "Medalluin", "media")
RENDER = os.path.join(HERE, "render")

os.makedirs(MEDIA, exist_ok=True)
os.makedirs(RENDER, exist_ok=True)

SS = 8  # 8x supersampling for ultra smooth anti-aliased rendering


def gen_ready_status():
    tex_w, tex_h = 128, 32
    bw, bh = tex_w * SS, tex_h * SS
    img = Image.new("RGBA", (bw, bh), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    cell_w = 32 * SS
    cell_h = 32 * SS

    # Dark ink circle background helper
    def draw_disc(cx, cy, r):
        # Outer gold/bronze rim
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(22, 24, 30, 240), outline=(152, 138, 96, 255), width=int(1.2 * SS))

    # Slot 0: Ready (Green Checkmark)
    cx0, cy0 = cell_w // 2, cell_h // 2
    draw_disc(cx0, cy0, int(13 * SS))
    # Draw checkmark: points (cx - 6, cy), (cx - 1.5, cy + 5), (cx + 6.5, cy - 5.5)
    chk_pts = [
        (cx0 - int(6.0 * SS), cy0 + int(0.0 * SS)),
        (cx0 - int(1.5 * SS), cy0 + int(4.8 * SS)),
        (cx0 + int(6.5 * SS), cy0 - int(5.2 * SS)),
    ]
    # Draw dark backing shadow
    d.line([(p[0], p[1] + int(0.8 * SS)) for p in chk_pts], fill=(10, 10, 12, 220), width=int(3.2 * SS), joint="curve")
    # Draw vibrant green check
    d.line(chk_pts, fill=(46, 204, 113, 255), width=int(2.8 * SS), joint="curve")
    # Inner bright highlight
    d.line([(chk_pts[0][0] + int(0.4 * SS), chk_pts[0][1] - int(0.4 * SS)),
            (chk_pts[1][0], chk_pts[1][1] - int(0.4 * SS)),
            (chk_pts[2][0] - int(0.4 * SS), chk_pts[2][1] + int(0.4 * SS))],
           fill=(120, 240, 170, 255), width=int(1.2 * SS), joint="curve")

    # Slot 1: Not Ready (Red Cross)
    cx1, cy1 = cell_w + cell_w // 2, cell_h // 2
    draw_disc(cx1, cy1, int(13 * SS))
    arm = int(5.5 * SS)
    # Dark shadow
    d.line([(cx1 - arm, cy1 - arm + int(0.8 * SS)), (cx1 + arm, cy1 + arm + int(0.8 * SS))], fill=(10, 10, 12, 220), width=int(3.2 * SS))
    d.line([(cx1 - arm, cy1 + arm + int(0.8 * SS)), (cx1 + arm, cy1 - arm + int(0.8 * SS))], fill=(10, 10, 12, 220), width=int(3.2 * SS))
    # Red cross
    d.line([(cx1 - arm, cy1 - arm), (cx1 + arm, cy1 + arm)], fill=(231, 76, 60, 255), width=int(2.8 * SS))
    d.line([(cx1 - arm, cy1 + arm), (cx1 + arm, cy1 - arm)], fill=(231, 76, 60, 255), width=int(2.8 * SS))
    # Highlight
    d.line([(cx1 - arm + int(0.4 * SS), cy1 - arm), (cx1 + arm - int(0.4 * SS), cy1 + arm)], fill=(255, 140, 130, 255), width=int(1.2 * SS))
    d.line([(cx1 - arm + int(0.4 * SS), cy1 + arm), (cx1 + arm - int(0.4 * SS), cy1 - arm)], fill=(255, 140, 130, 255), width=int(1.2 * SS))

    # Slot 2: Undecided (Amber Dash)
    cx2, cy2 = cell_w * 2 + cell_w // 2, cell_h // 2
    draw_disc(cx2, cy2, int(13 * SS))
    dh = int(2.4 * SS)
    dw = int(6.5 * SS)
    # Dark shadow
    d.rounded_rectangle([cx2 - dw, cy2 - dh + int(0.8 * SS), cx2 + dw, cy2 + dh + int(0.8 * SS)], radius=dh, fill=(10, 10, 12, 220))
    # Gold/amber dash
    d.rounded_rectangle([cx2 - dw, cy2 - dh, cx2 + dw, cy2 + dh], radius=dh, fill=(241, 196, 15, 255))
    # Subtle top highlight
    d.line([(cx2 - dw + int(1.5 * SS), cy2 - dh + int(0.7 * SS)), (cx2 + dw - int(1.5 * SS), cy2 - dh + int(0.7 * SS))], fill=(255, 240, 150, 255), width=int(0.9 * SS))

    res = img.resize((tex_w, tex_h), Image.Resampling.LANCZOS)
    res.save(os.path.join(MEDIA, "ready-status.tga"))
    res.save(os.path.join(RENDER, "ready-status.png"))
    print("Generated ready-status.tga")


def gen_role_icons():
    tex_w, tex_h = 128, 32
    bw, bh = tex_w * SS, tex_h * SS
    img = Image.new("RGBA", (bw, bh), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    cell_w = 32 * SS
    cell_h = 32 * SS

    def draw_disc(cx, cy, r):
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(24, 27, 34, 245), outline=(160, 145, 102, 255), width=int(1.3 * SS))

    # Slot 0: Tank (Shield)
    cx0, cy0 = cell_w // 2, cell_h // 2
    draw_disc(cx0, cy0, int(13.5 * SS))
    # Shield polygon: top flat, straight sides, curved to bottom point
    sw = int(6.5 * SS)
    top_y = cy0 - int(6.5 * SS)
    mid_y = cy0 + int(0.5 * SS)
    bot_y = cy0 + int(7.5 * SS)
    pts = [
        (cx0 - sw, top_y),
        (cx0 + sw, top_y),
        (cx0 + sw, mid_y),
        (cx0, bot_y),
        (cx0 - sw, mid_y)
    ]
    # Shield fill (slate blue with gold outline)
    d.polygon(pts, fill=(52, 110, 180, 255), outline=(210, 190, 130, 255))
    # Inner shield ridge
    d.line([(cx0, top_y + int(1.0 * SS)), (cx0, bot_y - int(1.5 * SS))], fill=(140, 195, 255, 255), width=int(1.1 * SS))
    # Left shade
    d.polygon([(cx0 - sw + int(1.0 * SS), top_y + int(1.0 * SS)),
               (cx0, top_y + int(1.0 * SS)),
               (cx0, bot_y - int(1.5 * SS)),
               (cx0 - sw + int(1.0 * SS), mid_y)], fill=(38, 85, 145, 180))

    # Slot 1: Healer (Emerald Cross)
    cx1, cy1 = cell_w + cell_w // 2, cell_h // 2
    draw_disc(cx1, cy1, int(13.5 * SS))
    # Medical cross
    cw = int(3.2 * SS)
    cl = int(8.0 * SS)
    # Cross vertical & horizontal
    d.rounded_rectangle([cx1 - cw, cy1 - cl, cx1 + cw, cy1 + cl], radius=int(1.0 * SS), fill=(46, 204, 113, 255), outline=(25, 110, 60, 255), width=int(0.8 * SS))
    d.rounded_rectangle([cx1 - cl, cy1 - cw, cx1 + cl, cy1 + cw], radius=int(1.0 * SS), fill=(46, 204, 113, 255), outline=(25, 110, 60, 255), width=int(0.8 * SS))
    # Highlight cross
    d.line([(cx1 - cw + int(0.8 * SS), cy1 - cl + int(1.0 * SS)), (cx1 - cw + int(0.8 * SS), cy1 + cl - int(1.0 * SS))], fill=(140, 250, 180, 220), width=int(0.8 * SS))
    d.line([(cx1 - cl + int(1.0 * SS), cy1 - cw + int(0.8 * SS)), (cx1 + cl - int(1.0 * SS), cy1 - cw + int(0.8 * SS))], fill=(140, 250, 180, 220), width=int(0.8 * SS))

    # Slot 2: Damager (Sword / Blades)
    cx2, cy2 = cell_w * 2 + cell_w // 2, cell_h // 2
    draw_disc(cx2, cy2, int(13.5 * SS))
    # Crossed twin swords or vertical sword
    # Central broadsword: blade pointing up
    tip_y = cy2 - int(8.0 * SS)
    guard_y = cy2 + int(2.5 * SS)
    pommel_y = cy2 + int(7.5 * SS)
    # Blade
    blade = [
        (cx2, tip_y),
        (cx2 + int(2.2 * SS), tip_y + int(3.5 * SS)),
        (cx2 + int(1.8 * SS), guard_y),
        (cx2 - int(1.8 * SS), guard_y),
        (cx2 - int(2.2 * SS), tip_y + int(3.5 * SS)),
    ]
    d.polygon(blade, fill=(230, 235, 245, 255), outline=(40, 40, 50, 255))
    # Blade central fuller
    d.line([(cx2, tip_y + int(2.0 * SS)), (cx2, guard_y - int(0.5 * SS))], fill=(150, 160, 180, 255), width=int(0.8 * SS))
    # Crossguard
    d.rounded_rectangle([cx2 - int(5.5 * SS), guard_y, cx2 + int(5.5 * SS), guard_y + int(1.8 * SS)], radius=int(0.8 * SS), fill=(212, 175, 55, 255), outline=(50, 40, 20, 255))
    # Grip & Pommel
    d.line([(cx2, guard_y + int(1.5 * SS)), (cx2, pommel_y)], fill=(139, 69, 19, 255), width=int(1.6 * SS))
    d.ellipse([cx2 - int(1.4 * SS), pommel_y - int(1.4 * SS), cx2 + int(1.4 * SS), pommel_y + int(1.4 * SS)], fill=(212, 175, 55, 255))

    res = img.resize((tex_w, tex_h), Image.Resampling.LANCZOS)
    res.save(os.path.join(MEDIA, "role-icons.tga"))
    res.save(os.path.join(RENDER, "role-icons.png"))
    print("Generated role-icons.tga")


if __name__ == "__main__":
    gen_ready_status()
    gen_role_icons()
