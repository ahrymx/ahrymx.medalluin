#!/usr/bin/env python3
"""Procedural art generator and exporter for Medaluin's lightweight console profile.

Layout architecture:
  1. Action Bar 1 on TOP (`30x30` buttons, slightly smaller than the 2x5 center grid):
     - Left end panel: Minimap button drawer toggle (toolkit medal in round well)
     - Center: 12 action button slots
     - Right end panel: Bar 1 pager (up/down chevrons + page number)
     - Lower row (underneath Bar 1 buttons): Slimmer long hybrid castbar / class resource row
  2. Directly below Bar 1's hybrid castbar, FLUSH ON TOP (`FLUSH_TOP_Y = 904`):
     - Left Wing: Player Unit Frame (Health `32px` + Power `10px` = `42px`)
     - Center Bay:
       * Exploration Mode: Square Minimap (`208x156`), flush on top and extending
         down past the unit frames and lower bars.
       * Combat / Target Mode: Action Bar 7 (2x5 grid of `36x36` buttons = `208x88`),
         while Minimap relocates to top-right (`188x188`).
     - Right Wing: Target Unit Frame (Health `32px` + Power `10px` = `42px`)
  3. Exp & Rep bars (`8px` high) attached directly beneath the Player/Target unit frames
     and flush against the sides of the Minimap / Center Bay.
  4. Action Bars 2 and 3 (`30x30` buttons, `38px` frame height) attached directly below
     the Exp and Rep bars (`42 + 8 + 38 = 88px`, locking flush with the bottom of Bar 7!).
  5. Detached Vertical Party Stack on the left of the screen (`184x30` each).

Usage:
    python3 art/console/gen_light_console.py          -> render/light-console-*.png
    python3 art/console/gen_light_console.py export   -> media/*.tga, console/light_profile.lua
"""
import os
import subprocess
import sys
import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
OUT = os.path.join(HERE, "render")
BASE = os.path.join(HERE, "base-screen.png")
TOOLKIT = os.path.join(ROOT, "art", "bars", "toolkit.png")
ADDON = os.path.join(ROOT, "WoW", "Interface", "AddOns", "Medaluin")
MEDIA = os.path.join(ADDON, "media")
LUA_OUT = os.path.join(ADDON, "console", "light_profile.lua")
FONT_FILE = os.path.join(MEDIA, "fonts", "MarcellusSC-Regular.ttf")

W, H, CX = 1920, 1080, 960

# Palette
GOLD = "#c4a557"
GOLD_D = "#8a7034"
GOLD_HI = "#fff0b0"
GOLD_BRIGHT = "#e0b84a"
INK = "#121110"
WELL_BG = "#16161a"
BORDER_D = "#2a2418"


def pow2(n):
    p = 1
    while p < n:
        p *= 2
    return p


def to_tga(img, path):
    """Write 32-bit uncompressed TGA via ImageMagick."""
    pw, ph = pow2(img.width), pow2(img.height)
    padded = Image.new("RGBA", (pw, ph), (0, 0, 0, 0))
    padded.paste(img, (0, 0))
    tmp = path + ".png"
    padded.save(tmp)
    subprocess.run(["magick", tmp, "-define", "tga:compression=none",
                    "-depth", "8", "-type", "TrueColorAlpha", path], check=True)
    os.remove(tmp)
    return pw, ph


def get_font(size):
    if os.path.exists(FONT_FILE):
        return ImageFont.truetype(FONT_FILE, size)
    return ImageFont.load_default()


def rsvg(svg_text, png_path):
    subprocess.run(["rsvg-convert", "-o", png_path], input=svg_text.encode(), check=True)
    return Image.open(png_path).convert("RGBA")


def make_toolkit_icon(size=24):
    """Recolour art/bars/toolkit.png into Medaluin's navy and gold."""
    if not os.path.exists(TOOLKIT):
        return Image.new("RGBA", (size, size), (40, 48, 68, 255))
    src = np.asarray(Image.open(TOOLKIT).convert("RGBA")).astype(float)
    n = src.shape[0]
    rgb, alpha = src[..., :3], src[..., 3] / 255
    left, right = src[n // 2, n // 64, :3], src[n // 2, n - 1 - n // 64, :3]
    x = (np.arange(n) - n // 64) / (n - 1 - 2 * (n // 64))
    grad = left + np.clip(x, 0, 1)[None, :, None] * (right - left)
    mix = np.clip(((rgb - grad) / np.maximum(255 - grad, 1)).mean(axis=2), 0, 1)
    y = (np.arange(n) / (n - 1))[:, None, None]

    def lit(top, bottom):
        return np.array(top, float) + y * (np.array(bottom, float) - np.array(top, float))

    navy, gold = lit((0x3e, 0x47, 0x60), (0x1a, 0x1e, 0x2b)), lit((0xf6, 0xdc, 0x8a), (0xa8, 0x82, 0x30))
    out = navy * (1 - mix[..., None]) + gold * mix[..., None]
    yy, xx = np.mgrid[0:n, 0:n]
    d = np.hypot(xx - (n - 1) / 2, yy - (n - 1) / 2) / (n / 2)
    rim = np.clip((d - 0.86) * 40, 0, 1)[..., None]
    edge = np.clip((d - 0.96) * 40, 0, 1)[..., None]
    out = out * (1 - rim) + lit((0xe0, 0xb8, 0x4a), (0x8a, 0x6a, 0x24)) * rim
    out = out * (1 - edge) + np.array((0x1a, 0x12, 0x06), float) * edge
    img = Image.fromarray(np.dstack([out, alpha * 255]).clip(0, 255).astype(np.uint8), "RGBA")
    return img.resize((size, size), Image.LANCZOS)


# ---------------------------------------------------------------------------
# Geometry Constants (1080p design space)
# ---------------------------------------------------------------------------
# Center 2x5 Grid (Action Bar 7): prominent 36x36 combat buttons
GRID_BTN, GRID_GAP, GRID_PAD = 36, 4, 6
BAY_W = 5 * GRID_BTN + 4 * GRID_GAP + 2 * GRID_PAD  # 196 + 12 = 208
BAY_HALF = BAY_W // 2                               # 104
BAR7_H = 2 * GRID_BTN + GRID_GAP + 2 * GRID_PAD     # 76 + 12 = 88

# Action Bar 1, 2, 3 buttons: slightly smaller (30x30)
BAR_BTN, BAR_GAP = 30, 3

# Action Bar 1 on TOP (with left Drawer toggle, right Pager, and lower slim Hybrid Castbar)
END_PANEL_W = 32
BAR1_SLOTS_W = 12 * BAR_BTN + 11 * BAR_GAP          # 393
BAR1_TOP_W = BAR1_SLOTS_W + 2 * END_PANEL_W + 11    # 468 (even)
BAR1_TOP_PAD = 4
BAR1_MID_GAP = 3
HYBRID_H = 10                                       # trapezoid hybrid castbar / class power row
BAR1_BOT_PAD = 2
BAR1_H = BAR1_TOP_PAD + BAR_BTN + BAR1_MID_GAP + HYBRID_H + BAR1_BOT_PAD  # 49
SLOPE_ANGLE = 70
HYBRID_DX = HYBRID_H / np.tan(np.radians(SLOPE_ANGLE))                     # 3.6397... (70 deg slope)
HYBRID_TOP_W = 452.0                                                       # spans drawer (26) to pager (478)
HYBRID_BOT_W = HYBRID_TOP_W + 2 * HYBRID_DX                               # 459.28
HYBRID_W = HYBRID_BOT_W

# 70-degree slope between Action Bar 1 and the top of the console:
# tan(70 deg) = 2.747477... -> dx = round(49 / tan(70 deg)) = 18px per side
BAR1_DX = int(round(BAR1_H / np.tan(np.radians(SLOPE_ANGLE))))  # 18
BAR1_BOT_W = BAR1_TOP_W + 2 * BAR1_DX               # 504
BAR1_W = BAR1_BOT_W                                 # 504 total plate width

# Flush top line for Player, Minimap/Bar7, and Target
FLUSH_TOP_Y = 904
# Move Action Bar 1 down so there is NO GAP: bottom tucks 1px under console top border (bottom = -1)
BAR1_BOTTOM_GAP = -1
BAR1_Y = FLUSH_TOP_Y - BAR1_H - BAR1_BOTTOM_GAP     # 904 - 49 - (-1) = 856
HYBRID_Y = BAR1_Y + BAR1_TOP_PAD + BAR_BTN + BAR1_MID_GAP                 # 893

# Left & Right Wings: Width matches 6 buttons of Bar 2 / Bar 3
BAR23_GAP = 4
BAR23_PAD = 4
WING_W = 6 * BAR_BTN + 5 * BAR23_GAP + 2 * BAR23_PAD  # 208

# Wing vertical stack (locks to exact 88px height of Bar 7!):
# Health (32) + Power (10) + Exp/Rep (8) + Bar 2/3 (38) = 88px!
HEALTH_H = 32
POWER_H = 10
UNIT_H = HEALTH_H + POWER_H                         # 42
UNIT_Y = FLUSH_TOP_Y                                # 904
POWER_Y = UNIT_Y + HEALTH_H                         # 936

XP_H = 8
XP_Y = POWER_Y + POWER_H                            # 946

BAR23_H = BAR_BTN + 2 * BAR23_PAD                   # 38
BAR23_Y = XP_Y + XP_H                               # 954
WING_BOTTOM_Y = BAR23_Y + BAR23_H                   # 992 (904 + 88 = 992!)

# Square Minimap in Exploration Mode: flush on top at FLUSH_TOP_Y (904),
# extends down past unit frames (946) and past Bar 2/3 (992) to 904 + 156 = 1060
MINIMAP_H = 156
CONSOLE_W = 2 * WING_W + BAY_W                      # 208 + 208 + 208 = 624
CONSOLE_H = MINIMAP_H                               # 156
BOTTOM_GAP = H - (FLUSH_TOP_Y + CONSOLE_H)          # 1080 - 1060 = 20

# Top-right relocated minimap size
TR_MINIMAP_SIZE = 188
# Detached vertical party frame size
PARTY_W, PARTY_H, PARTY_GAP = 184, 30, 8


def svg_defs():
    return f'''
    <linearGradient id="goldGrad" x1="0" y1="0" x2="0" y2="1">
        <stop offset="0%" stop-color="{GOLD_HI}"/>
        <stop offset="30%" stop-color="{GOLD_BRIGHT}"/>
        <stop offset="70%" stop-color="{GOLD}"/>
        <stop offset="100%" stop-color="{GOLD_D}"/>
    </linearGradient>
    <filter id="shadow" x="-5%" y="-5%" width="110%" height="110%">
        <feDropShadow dx="0" dy="2" stdDeviation="2" flood-color="#000" flood-opacity="0.85"/>
    </filter>
    '''


def render_console_piece(mode="combat"):
    """Render the 624x156 main console plate (explore or combat mode) with
    cutout windows for units, xp/rep, and center minimap."""
    cw, ch = CONSOLE_W, CONSOLE_H
    left_x = 0
    bay_l = WING_W
    right_x = WING_W + BAY_W

    # Mask cutouts so status bars and minimap underneath show through cleanly
    mask = [f'<mask id="cut"><rect width="{cw}" height="{ch}" fill="#fff"/>']
    # Left & Right Unit windows (inset by 2px for gold frame)
    for lx in (left_x, right_x):
        mask.append(f'<rect x="{lx + 2}" y="2" width="{WING_W - 4}" height="{UNIT_H - 4}" fill="#000"/>')
        mask.append(f'<rect x="{lx + 2}" y="{UNIT_H + 1}" width="{WING_W - 4}" height="{XP_H - 2}" fill="#000"/>')
    if mode == "explore":
        mask.append(f'<rect x="{bay_l + 2}" y="2" width="{BAY_W - 4}" height="{MINIMAP_H - 4}" fill="#000"/>')
    mask.append('</mask>')

    body = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{cw}" height="{ch}">',
            f'<defs>{svg_defs()}{"".join(mask)}</defs>',
            '<g mask="url(#cut)">']

    # Left & Right Wings
    for lx in (left_x, right_x):
        # Unit frame (Health + Power seam)
        body.append(f'<rect x="{lx + 1}" y="1" width="{WING_W - 2}" height="{UNIT_H - 2}" '
                    f'fill="{INK}" stroke="url(#goldGrad)" stroke-width="2"/>')
        body.append(f'<line x1="{lx + 2}" y1="{HEALTH_H}" x2="{lx + WING_W - 2}" y2="{HEALTH_H}" '
                    f'stroke="{GOLD_D}" stroke-width="1.2"/>')
        # XP / Rep frame
        body.append(f'<rect x="{lx + 1}" y="{UNIT_H}" width="{WING_W - 2}" height="{XP_H}" '
                    f'fill="{INK}" stroke="{GOLD_D}" stroke-width="1.2"/>')

    # Center Bay
    if mode == "combat":
        body.append(f'<rect x="{bay_l + 1}" y="1" width="{BAY_W - 2}" height="{BAR7_H - 2}" '
                    f'fill="{INK}" stroke="url(#goldGrad)" stroke-width="2"/>')
        for r in range(2):
            for c in range(5):
                bx = bay_l + GRID_PAD + c * (GRID_BTN + GRID_GAP)
                by = GRID_PAD + r * (GRID_BTN + GRID_GAP)
                body.append(f'<rect x="{bx}" y="{by}" width="{GRID_BTN}" height="{GRID_BTN}" '
                            f'fill="#1a1a20" stroke="#383842" stroke-width="1"/>')
    else:
        body.append(f'<rect x="{bay_l + 1}" y="1" width="{BAY_W - 2}" height="{MINIMAP_H - 2}" '
                    f'fill="{INK}" stroke="url(#goldGrad)" stroke-width="2.4"/>')

    body.append('</g></svg>')
    tmp = os.path.join(OUT, f"_tmp_console_{mode}.png")
    img = rsvg("".join(body), tmp)
    if os.path.exists(tmp):
        os.remove(tmp)
    return img


def render_tint_piece():
    """Render an additive glow mask around the light console's borders for combat/threat."""
    cw, ch = CONSOLE_W, CONSOLE_H
    body = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{cw}" height="{ch}">',
            '<defs><filter id="blur"><feGaussianBlur stdDeviation="2.5"/></filter></defs>',
            '<g filter="url(#blur)" opacity="0.65">',
            f'<rect x="2" y="2" width="{cw - 4}" height="{BAR7_H - 4}" fill="none" stroke="#ffffff" stroke-width="3"/>',
            '</g></svg>']
    tmp = os.path.join(OUT, "_tmp_tint.png")
    img = rsvg("".join(body), tmp)
    if os.path.exists(tmp):
        os.remove(tmp)
    return img


def render_bar1_piece(bg_only=False):
    """Render the 504x49 top Action Bar 1 plate with 70-degree sloped ends (or its solid background)."""
    bw, bh = BAR1_W, BAR1_H
    cx = bw / 2
    tl_x = cx - BAR1_TOP_W / 2          # 18.0
    tr_x = cx + BAR1_TOP_W / 2          # 486.0
    bl_x = 1.0
    br_x = bw - 1.0                     # 503.0
    top_y = 1.0
    bot_y = bh - 1.0                    # 48.0

    hyb_top_y = BAR1_TOP_PAD + BAR_BTN + BAR1_MID_GAP  # 37.0
    hyb_bot_y = bot_y - 1.0                            # 47.0 (flush against console top)
    hyb_tl_x = cx - HYBRID_TOP_W / 2                   # 26.0 (aligns with drawer outer tangent)
    hyb_tr_x = cx + HYBRID_TOP_W / 2                   # 478.0 (aligns with pager outer edge)
    hyb_bl_x = hyb_tl_x - HYBRID_DX                    # 22.36 (70-deg outward slope /)
    hyb_br_x = hyb_tr_x + HYBRID_DX                    # 481.64 (70-deg outward slope \)
    hyb_poly = f"{hyb_tl_x:.1f},{hyb_top_y:.1f} {hyb_tr_x:.1f},{hyb_top_y:.1f} {hyb_br_x:.1f},{hyb_bot_y:.1f} {hyb_bl_x:.1f},{hyb_bot_y:.1f}"

    drawer_cx = tl_x + 4 + END_PANEL_W / 2         # 38.0
    drawer_cy = BAR1_TOP_PAD + BAR_BTN / 2         # 19.0
    slots_l = tl_x + 5 + END_PANEL_W               # 55.0

    trap_pts = f"{tl_x},{top_y} {tr_x},{top_y} {br_x},{bot_y} {bl_x},{bot_y}"

    if bg_only:
        svg = (f'<svg xmlns="http://www.w3.org/2000/svg" width="{bw}" height="{bh}">'
               f'<polygon points="{trap_pts}" fill="{INK}"/></svg>')
    else:
        mask = (f'<mask id="b1cut"><polygon points="{trap_pts}" fill="#fff"/>'
                f'<circle cx="{drawer_cx}" cy="{drawer_cy}" r="11" fill="#000"/>'
                f'<polygon points="{hyb_poly}" fill="#000"/>'
                + "".join(f'<rect x="{slots_l + c * (BAR_BTN + BAR_GAP)}" y="{BAR1_TOP_PAD}" '
                          f'width="{BAR_BTN}" height="{BAR_BTN}" fill="#000"/>' for c in range(12))
                + '</mask>')
        body = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{bw}" height="{bh}">',
                f'<defs>{svg_defs()}{mask}</defs>',
                '<g mask="url(#b1cut)">',
                f'<polygon points="{trap_pts}" fill="{INK}" stroke="url(#goldGrad)" stroke-width="1.8"/>',
                f'<circle cx="{drawer_cx}" cy="{drawer_cy}" r="12" fill="none" stroke="{GOLD_D}" stroke-width="1.2"/>',
                f'<line x1="{slots_l - 3}" y1="3" x2="{slots_l - 3}" y2="{BAR1_TOP_PAD + BAR_BTN + 1}" stroke="#2e2b22" stroke-width="1"/>']
        for c in range(12):
            bx = slots_l + c * (BAR_BTN + BAR_GAP)
            body.append(f'<rect x="{bx - 0.5}" y="{BAR1_TOP_PAD - 0.5}" width="{BAR_BTN + 1}" height="{BAR_BTN + 1}" '
                        f'fill="none" stroke="#32323c" stroke-width="1"/>')
        pager_l = slots_l + 12 * BAR_BTN + 11 * BAR_GAP + 3
        chev_x = pager_l + 4
        chev_w, chev_h = 13, 14
        up_y = BAR1_TOP_PAD
        dn_y = up_y + chev_h + 2
        num_x = chev_x + chev_w + 2
        num_y = up_y + 7
        num_w, num_h = 10, 16
        body.append(f'<line x1="{pager_l}" y1="3" x2="{pager_l}" y2="{BAR1_TOP_PAD + BAR_BTN + 1}" stroke="#2e2b22" stroke-width="1"/>')
        body.append(f'<rect x="{chev_x}" y="{up_y}" width="{chev_w}" height="{chev_h}" fill="#101014" stroke="{GOLD_D}" stroke-width="1"/>')
        body.append(f'<rect x="{chev_x}" y="{dn_y}" width="{chev_w}" height="{chev_h}" fill="#101014" stroke="{GOLD_D}" stroke-width="1"/>')
        body.append(f'<rect x="{num_x}" y="{num_y}" width="{num_w}" height="{num_h}" fill="#101014" stroke="{GOLD_D}" stroke-width="1"/>')
        body.append(f'<polygon points="{hyb_poly}" fill="none" stroke="{GOLD_D}" stroke-width="1.2"/>')
        body.append('</g></svg>')
        svg = "".join(body)

    tmp = os.path.join(OUT, "_tmp_bar1.png")
    img = rsvg(svg, tmp)
    if os.path.exists(tmp):
        os.remove(tmp)
    return img


def render_hybrid_piece(bg_only=False):
    """Render the 504x14 standalone trapezoid hybrid castbar/power bezel (/-------------\\)
    so it can stand alone atop the console when Action Bar 1 is hidden."""
    bw, bh = BAR1_W, 14
    cx = bw / 2
    hyb_tl_x = cx - HYBRID_TOP_W / 2                   # 26.0
    hyb_tr_x = cx + HYBRID_TOP_W / 2                   # 478.0
    hyb_bl_x = hyb_tl_x - HYBRID_DX                    # 22.36
    hyb_br_x = hyb_tr_x + HYBRID_DX                    # 481.64
    hyb_top_y = 2.0                                    # matches y=37 in 49px plate (37 - 35 = 2)
    hyb_bot_y = 12.0                                   # matches y=47 in 49px plate (47 - 35 = 12)
    hyb_poly = f"{hyb_tl_x:.1f},{hyb_top_y:.1f} {hyb_tr_x:.1f},{hyb_top_y:.1f} {hyb_br_x:.1f},{hyb_bot_y:.1f} {hyb_bl_x:.1f},{hyb_bot_y:.1f}"

    out_tl_x = hyb_tl_x - 1.5
    out_tr_x = hyb_tr_x + 1.5
    out_bl_x = hyb_bl_x - 1.5
    out_br_x = hyb_br_x + 1.5
    out_poly = f"{out_tl_x:.1f},{hyb_top_y - 1.2:.1f} {out_tr_x:.1f},{hyb_top_y - 1.2:.1f} {out_br_x:.1f},{hyb_bot_y + 1.0:.1f} {out_bl_x:.1f},{hyb_bot_y + 1.0:.1f}"

    if bg_only:
        svg = (f'<svg xmlns="http://www.w3.org/2000/svg" width="{bw}" height="{bh}">'
               f'<polygon points="{out_poly}" fill="{INK}"/></svg>')
    else:
        mask = (f'<mask id="hybcut"><rect width="{bw}" height="{bh}" fill="#fff"/>'
                f'<polygon points="{hyb_poly}" fill="#000"/></mask>')
        svg = (f'<svg xmlns="http://www.w3.org/2000/svg" width="{bw}" height="{bh}">'
               f'<defs>{svg_defs()}{mask}</defs>'
               f'<g mask="url(#hybcut)">'
               f'<polygon points="{out_poly}" fill="{INK}" stroke="url(#goldGrad)" stroke-width="1.6"/>'
               f'<polygon points="{hyb_poly}" fill="none" stroke="{GOLD_D}" stroke-width="1.2"/>'
               f'</g></svg>')

    tmp = os.path.join(OUT, "_tmp_hybrid.png")
    img = rsvg(svg, tmp)
    if os.path.exists(tmp):
        os.remove(tmp)
    return img


def render_wing_piece():
    """Render a 208x38 wing plate for Action Bar 2 or 3 (6 buttons below XP/Rep)."""
    ww, wh = WING_W, BAR23_H
    body = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{ww}" height="{wh}">',
            f'<defs>{svg_defs()}</defs>',
            f'<rect x="1" y="0" width="{ww - 2}" height="{wh - 1}" '
            f'fill="{INK}" stroke="url(#goldGrad)" stroke-width="1.6"/>']
    for c in range(6):
        bx = BAR23_PAD + c * (BAR_BTN + BAR23_GAP)
        by = BAR23_PAD
        body.append(f'<rect x="{bx}" y="{by}" width="{BAR_BTN}" height="{BAR_BTN}" '
                    f'fill="#141418" stroke="#32323c" stroke-width="1"/>')
    body.append('</svg>')
    tmp = os.path.join(OUT, "_tmp_wing.png")
    img = rsvg("".join(body), tmp)
    if os.path.exists(tmp):
        os.remove(tmp)
    return img


def render_minimap_bezel():
    """Render the 188x188 square gold bezel for the top-right relocated minimap."""
    s = TR_MINIMAP_SIZE
    svg = (f'<svg xmlns="http://www.w3.org/2000/svg" width="{s}" height="{s}">'
           f'<defs>{svg_defs()}'
           f'<mask id="mcut"><rect width="{s}" height="{s}" fill="#fff"/>'
           f'<rect x="2" y="2" width="{s - 4}" height="{s - 4}" fill="#000"/></mask></defs>'
           f'<rect x="1" y="1" width="{s - 2}" height="{s - 2}" fill="{INK}" '
           f'stroke="url(#goldGrad)" stroke-width="2.4" mask="url(#mcut)"/></svg>')
    tmp = os.path.join(OUT, "_tmp_mm.png")
    img = rsvg(svg, tmp)
    if os.path.exists(tmp):
        os.remove(tmp)
    return img


def render_party_bezel():
    """Render the 184x30 gold bezel for detached vertical party frames."""
    pw, ph = PARTY_W, PARTY_H
    svg = (f'<svg xmlns="http://www.w3.org/2000/svg" width="{pw}" height="{ph}">'
           f'<defs>{svg_defs()}'
           f'<mask id="pcut"><rect width="{pw}" height="{ph}" fill="#fff"/>'
           f'<rect x="2" y="2" width="{pw - 4}" height="{ph - 4}" fill="#000"/></mask></defs>'
           f'<rect x="1" y="1" width="{pw - 2}" height="{ph - 2}" fill="{INK}" '
           f'stroke="{GOLD_D}" stroke-width="1.6" mask="url(#pcut)"/></svg>')
    tmp = os.path.join(OUT, "_tmp_party.png")
    img = rsvg(svg, tmp)
    if os.path.exists(tmp):
        os.remove(tmp)
    return img


def export_all():
    """Export all TGA textures to media/ and generate console/light_profile.lua."""
    os.makedirs(OUT, exist_ok=True)
    os.makedirs(MEDIA, exist_ok=True)

    c_explore = render_console_piece("explore")
    c_combat = render_console_piece("combat")
    c_tint = render_tint_piece()
    b1_plate = render_bar1_piece(bg_only=False)
    b1_bg = render_bar1_piece(bg_only=True)
    hyb_plate = render_hybrid_piece(bg_only=False)
    hyb_bg = render_hybrid_piece(bg_only=True)
    wing_plate = render_wing_piece()
    mm_bezel = render_minimap_bezel()
    party_bezel = render_party_bezel()

    cw_tex, ch_tex = to_tga(c_explore, os.path.join(MEDIA, "console-light-explore.tga"))
    to_tga(c_combat, os.path.join(MEDIA, "console-light-combat.tga"))
    to_tga(c_tint, os.path.join(MEDIA, "console-light-tint.tga"))
    bw_tex, bh_tex = to_tga(b1_plate, os.path.join(MEDIA, "actionbar-light.tga"))
    to_tga(b1_bg, os.path.join(MEDIA, "actionbar-light-bg.tga"))
    _, hyb_h_tex = to_tga(hyb_plate, os.path.join(MEDIA, "hybrid-light.tga"))
    to_tga(hyb_bg, os.path.join(MEDIA, "hybrid-light-bg.tga"))
    ww_tex, wh_tex = to_tga(wing_plate, os.path.join(MEDIA, "bar-wing-light.tga"))
    mw_tex, mh_tex = to_tga(mm_bezel, os.path.join(MEDIA, "minimap-light.tga"))
    pw_tex, ph_tex = to_tga(party_bezel, os.path.join(MEDIA, "party-light.tga"))

    # Compute exact coordinates relative to console TOP-CENTER (CX = 960, FLUSH_TOP_Y = 904)
    # Bar 1 coordinates: x signed from CX, y height ABOVE FLUSH_TOP_Y (negative below)
    bar1_bottom = FLUSH_TOP_Y - (BAR1_Y + BAR1_H)  # 904 - (856 + 49) = -1
    bar1_top = FLUSH_TOP_Y - BAR1_Y                # 904 - 856 = 48
    bar1_half = BAR1_BOT_W // 2                    # 504 // 2 = 252

    # The bars are a rectangle as wide as the window's TOP, so their top
    # corners stay inside the slanted gold edge; the slivers below them,
    # where the window widens, show the ink under them.
    hyb_half = int(HYBRID_TOP_W // 2)                # 226
    hyb_top = FLUSH_TOP_Y - HYBRID_Y                # 904 - 893 = 11
    hyb_bot = FLUSH_TOP_Y - (HYBRID_Y + HYBRID_H)   # 904 - 903 = 1 (rests flush on console top)

    # The upper row buttons, drawer toggle, and pager are centered on the 468px top width
    bar1_top_l = -BAR1_TOP_W // 2                  # -234
    slots_l = bar1_top_l + 5 + END_PANEL_W         # -197
    slot_top = FLUSH_TOP_Y - (BAR1_Y + BAR1_TOP_PAD)               # 44
    slot_bot = FLUSH_TOP_Y - (BAR1_Y + BAR1_TOP_PAD + BAR_BTN)     # 14
    row1_slots = []
    for c in range(12):
        sx = slots_l + c * (BAR_BTN + BAR_GAP)
        row1_slots.append((sx, sx + BAR_BTN, slot_top, slot_bot))

    # Drawer box (left end of Bar 1)
    drawer_cx = bar1_top_l + 4 + END_PANEL_W // 2
    drawer_cy = (slot_top + slot_bot) // 2
    drawer_box = (drawer_cx - 12, drawer_cx + 12, drawer_cy + 12, drawer_cy - 12)

    # Pager boxes (right end of Bar 1)
    pager_l = slots_l + 12 * BAR_BTN + 11 * BAR_GAP + 3
    chev_x = pager_l + 4
    chev_w, chev_h = 13, 14
    up_box = (chev_x, chev_x + chev_w, slot_top, slot_top - chev_h)
    dn_box = (chev_x, chev_x + chev_w, slot_top - chev_h - 2, slot_bot)
    num_x = chev_x + chev_w + 2
    num_box = (num_x, num_x + 10, slot_top - 7, slot_top - 23)

    # Row 2 (Left wing under XP) & Row 3 (Right wing under Rep), negative y below console top!
    b23_top = -(UNIT_H + XP_H + BAR23_PAD)             # -54
    b23_bot = -(UNIT_H + XP_H + BAR23_PAD + BAR_BTN)   # -84
    row2_slots, row3_slots = [], []
    for c in range(6):
        lx = -BAY_HALF - WING_W + BAR23_PAD + c * (BAR_BTN + BAR23_GAP)
        rx = BAY_HALF + BAR23_PAD + c * (BAR_BTN + BAR23_GAP)
        row2_slots.append((lx, lx + BAR_BTN, b23_top, b23_bot))
        row3_slots.append((rx, rx + BAR_BTN, b23_top, b23_bot))

    # Action Bar 7 (2x5 grid in Center Bay, negative y below console top!)
    bar7_slots = []
    for r in range(2):
        by_top = -(GRID_PAD + r * (GRID_BTN + GRID_GAP))
        by_bot = by_top - GRID_BTN
        for c in range(5):
            bx = -BAY_HALF + GRID_PAD + c * (GRID_BTN + GRID_GAP)
            bar7_slots.append((bx, bx + GRID_BTN, by_top, by_bot))

    def fmt_slots(slist):
        return ",\n            ".join(f"{{ {a}, {b}, {c}, {d} }}" for a, b, c, d in slist)

    lua = f"""-- Generated by art/console/gen_light_console.py; do not edit.
-- Built-in "light" console profile: WeakTextures 2x5 center grid (Action Bar 7),
-- dynamic square minimap, compact Action Bar 1 on top with drawer/pager/slim hybrid
-- castbar, attached Exp/Rep bars and Bar 2/3 wings, and detached vertical party stack.
local _, ns = ...

ns.lightProfile = {{
    art = {{
        width = {CONSOLE_W}, height = {CONSOLE_H}, texWidth = {cw_tex}, texHeight = {ch_tex},
        vialWidth = 267, vialHeight = 54, vialTexWidth = 512, vialTexHeight = 64,
        bottomGap = {BOTTOM_GAP},
        exploreFile = "console-light-explore",
        combatFile = "console-light-combat",
        tintFile = "console-light-tint",
    }},
    windows = {{
        unit = {{ {BAY_HALF + 2}, {BAY_HALF + WING_W - 2}, 2, {UNIT_H - 2} }},
        xp = {{ {BAY_HALF + 2}, {BAY_HALF + WING_W - 2}, {UNIT_H + 1}, {UNIT_H + XP_H - 1} }},
        ring = {{ 0, {BAY_HALF - 2}, 2, {MINIMAP_H - 2} }},
    }},
    layout = {{
        designHeight = 1080,
        unit = {{
            power = {POWER_H - 2}, seam = 2, healthOnTop = true,
            nameSize = 13, valueSize = 11, powerSize = 9,
            textInset = 8, valueInset = 8,
        }},
        party = {{
            power = 5, seam = 1, nameSize = 11, textInset = 6,
            detached = true, width = {PARTY_W}, height = {PARTY_H}, gap = {PARTY_GAP},
            x = 36, y = -500, texWidth = {pw_tex}, texHeight = {ph_tex},
        }},
        minimapBleed = 0,
        minimap = {{
            square = true,
            relocate = true,
            topRightSize = {TR_MINIMAP_SIZE},
            topRightInset = 28,
            texWidth = {mw_tex}, texHeight = {mh_tex},
        }},
    }},
    barArt = {{
        width = {BAR1_W}, height = {BAR1_H}, texWidth = {bw_tex}, texHeight = {bh_tex},
        bottom = {bar1_bottom},
        file = "actionbar-light",
        bgFile = "actionbar-light-bg",
        hybridFile = "hybrid-light",
        hybridBgFile = "hybrid-light-bg",
        hybridHeight = 14, hybridTexHeight = {hyb_h_tex},
        wingFile = "bar-wing-light",
        wingWidth = {WING_W}, wingHeight = {BAR23_H}, wingTexWidth = {ww_tex}, wingTexHeight = {wh_tex},
        wingBoxes = {{
            {{ {-BAY_HALF - WING_W}, {-BAY_HALF}, {-(UNIT_H + XP_H)}, {-(UNIT_H + XP_H + BAR23_H)} }},
            {{ {BAY_HALF}, {BAY_HALF + WING_W}, {-(UNIT_H + XP_H)}, {-(UNIT_H + XP_H + BAR23_H)} }},
        }},
    }},
    barFrame = {{ {-bar1_half}, {bar1_half}, {bar1_top}, {bar1_bottom} }},
    barLow = {{ {-hyb_half}, {hyb_half}, {hyb_top}, {hyb_bot} }},
    barPager = {{
        up = {{ {up_box[0]}, {up_box[1]}, {up_box[2]}, {up_box[3]} }},
        down = {{ {dn_box[0]}, {dn_box[1]}, {dn_box[2]}, {dn_box[3]} }},
        number = {{ {num_box[0]}, {num_box[1]}, {num_box[2]}, {num_box[3]} }},
    }},
    barDrawer = {{ {drawer_box[0]}, {drawer_box[1]}, {drawer_box[2]}, {drawer_box[3]} }},
    barDrawerToggle = 22,
    barDrawerCell = {{ cell = 30, button = 26, pad = 2, left = {-bar1_half - 6}, up = {bar1_top + 4} }},
    barWindows = {{
        {{
            {{
            {fmt_slots(row1_slots)}
            }},
        }},
        {{
            {{
            {fmt_slots(row1_slots)}
            }},
            {{
            {fmt_slots(row2_slots)}
            }},
        }},
        {{
            {{
            {fmt_slots(row1_slots)}
            }},
            {{
            {fmt_slots(row2_slots)}
            }},
            {{
            {fmt_slots(row3_slots)}
            }},
        }},
    }},
    bar7 = {{
        basePage = 7,
        stateDriver = "[bonusbar:1] 8; [form:1] 8; [form:2] 9; [form:3] 9; [stealth] 10; 7",
        slots = {{
            {fmt_slots(bar7_slots)}
        }},
    }},
}}
"""
    with open(LUA_OUT, "w") as f:
        f.write(lua)
    print(f"Exported TGA media and wrote {LUA_OUT}")


def draw_console_svg(mode="combat", bar1_hidden=False):
    """Generate full-screen SVG markup for the preview mockup."""
    svg = []
    svg.append(f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}">')
    svg.append(f'<defs>{svg_defs()}</defs>')

    bar1_tl = CX - BAR1_TOP_W // 2
    bar1_tr = CX + BAR1_TOP_W // 2
    bar1_bl = CX - BAR1_BOT_W // 2
    bar1_br = CX + BAR1_BOT_W // 2
    bar1_top = BAR1_Y
    bar1_bot = BAR1_Y + BAR1_H

    hyb_top_screen = HYBRID_Y
    hyb_bot_screen = HYBRID_Y + HYBRID_H
    hyb_tl_screen = CX - HYBRID_TOP_W / 2
    hyb_tr_screen = CX + HYBRID_TOP_W / 2
    hyb_bl_screen = hyb_tl_screen - HYBRID_DX
    hyb_br_screen = hyb_tr_screen + HYBRID_DX
    hyb_poly_screen = f"{hyb_tl_screen:.1f},{hyb_top_screen:.1f} {hyb_tr_screen:.1f},{hyb_top_screen:.1f} {hyb_br_screen:.1f},{hyb_bot_screen:.1f} {hyb_bl_screen:.1f},{hyb_bot_screen:.1f}"

    if bar1_hidden:
        # Action Bar 1 hidden: hybrid castbar stands alone directly on top of the console as a trapezoid /-------------\
        svg.append(f'<polygon points="{hyb_poly_screen}" '
                   f'fill="{INK}" stroke="url(#goldGrad)" stroke-width="1.8" filter="url(#shadow)"/>')
    else:
        trap_pts = f"{bar1_tl},{bar1_top} {bar1_tr},{bar1_top} {bar1_br},{bar1_bot} {bar1_bl},{bar1_bot}"
        svg.append(f'<mask id="bar1Mask"><polygon points="{trap_pts}" fill="#fff"/>'
                   f'<polygon points="{hyb_poly_screen}" fill="#000"/></mask>')
        svg.append(f'<polygon points="{trap_pts}" '
                   f'fill="{INK}" stroke="url(#goldGrad)" stroke-width="1.8" mask="url(#bar1Mask)" filter="url(#shadow)"/>')

        drawer_cx = bar1_tl + 4 + END_PANEL_W // 2
        drawer_cy = BAR1_Y + BAR1_TOP_PAD + BAR_BTN // 2
        svg.append(f'<circle cx="{drawer_cx}" cy="{drawer_cy}" r="12" fill="#0d0d10" stroke="{GOLD_D}" stroke-width="1.2"/>')

        slots_l = bar1_tl + 5 + END_PANEL_W
        svg.append(f'<line x1="{slots_l - 3}" y1="{BAR1_Y + 3}" x2="{slots_l - 3}" y2="{BAR1_Y + BAR1_TOP_PAD + BAR_BTN + 1}" '
                   f'stroke="#2e2b22" stroke-width="1"/>')
        for c in range(12):
            bx = slots_l + c * (BAR_BTN + BAR_GAP)
            by = BAR1_Y + BAR1_TOP_PAD
            svg.append(f'<rect x="{bx}" y="{by}" width="{BAR_BTN}" height="{BAR_BTN}" '
                       f'fill="#141418" stroke="#32323c" stroke-width="1"/>')

        pager_l = slots_l + 12 * BAR_BTN + 11 * BAR_GAP + 3
        svg.append(f'<line x1="{pager_l}" y1="{BAR1_Y + 3}" x2="{pager_l}" y2="{BAR1_Y + BAR1_TOP_PAD + BAR_BTN + 1}" '
                   f'stroke="#2e2b22" stroke-width="1"/>')
        chev_x = pager_l + 4
        chev_w, chev_h = 13, 14
        up_y = BAR1_Y + BAR1_TOP_PAD
        dn_y = up_y + chev_h + 2
        num_x = chev_x + chev_w + 2
        num_y = up_y + 7
        num_w, num_h = 10, 16
        svg.append(f'<rect x="{chev_x}" y="{up_y}" width="{chev_w}" height="{chev_h}" fill="#101014" stroke="{GOLD_D}" stroke-width="1"/>')
        svg.append(f'<rect x="{chev_x}" y="{dn_y}" width="{chev_w}" height="{chev_h}" fill="#101014" stroke="{GOLD_D}" stroke-width="1"/>')
        svg.append(f'<rect x="{num_x}" y="{num_y}" width="{num_w}" height="{num_h}" fill="#101014" stroke="{GOLD_D}" stroke-width="1"/>')
        svg.append(f'<path d="M {chev_x + 3.5} {up_y + 9.5} L {chev_x + 6.5} {up_y + 4.5} L {chev_x + 9.5} {up_y + 9.5}" '
                   f'fill="none" stroke="{GOLD_BRIGHT}" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"/>')
        svg.append(f'<path d="M {chev_x + 3.5} {dn_y + 4.5} L {chev_x + 6.5} {dn_y + 9.5} L {chev_x + 9.5} {dn_y + 4.5}" '
                   f'fill="none" stroke="{GOLD_BRIGHT}" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"/>')
        svg.append(f'<polygon points="{hyb_poly_screen}" fill="none" stroke="{GOLD_D}" stroke-width="1.2"/>')

    left_x = CX - BAY_HALF - WING_W
    right_x = CX + BAY_HALF
    svg.append(f'<rect x="{left_x}" y="{UNIT_Y}" width="{WING_W}" height="{HEALTH_H}" '
               f'fill="none" stroke="url(#goldGrad)" stroke-width="1.8" filter="url(#shadow)"/>')
    svg.append(f'<rect x="{left_x}" y="{POWER_Y}" width="{WING_W}" height="{POWER_H}" '
               f'fill="none" stroke="url(#goldGrad)" stroke-width="1.4"/>')
    svg.append(f'<rect x="{right_x}" y="{UNIT_Y}" width="{WING_W}" height="{HEALTH_H}" '
               f'fill="none" stroke="url(#goldGrad)" stroke-width="1.8" filter="url(#shadow)"/>')
    svg.append(f'<rect x="{right_x}" y="{POWER_Y}" width="{WING_W}" height="{POWER_H}" '
               f'fill="none" stroke="url(#goldGrad)" stroke-width="1.4"/>')
    svg.append(f'<rect x="{left_x}" y="{XP_Y}" width="{WING_W}" height="{XP_H}" '
               f'fill="none" stroke="{GOLD_D}" stroke-width="1.2"/>')
    svg.append(f'<rect x="{right_x}" y="{XP_Y}" width="{WING_W}" height="{XP_H}" '
               f'fill="none" stroke="{GOLD_D}" stroke-width="1.2"/>')

    svg.append(f'<rect x="{left_x}" y="{BAR23_Y}" width="{WING_W}" height="{BAR23_H}" '
               f'fill="{INK}" stroke="url(#goldGrad)" stroke-width="1.6" filter="url(#shadow)"/>')
    for c in range(6):
        bx = left_x + BAR23_PAD + c * (BAR_BTN + BAR23_GAP)
        by = BAR23_Y + BAR23_PAD
        svg.append(f'<rect x="{bx}" y="{by}" width="{BAR_BTN}" height="{BAR_BTN}" '
                   f'fill="#141418" stroke="#32323c" stroke-width="1"/>')

    svg.append(f'<rect x="{right_x}" y="{BAR23_Y}" width="{WING_W}" height="{BAR23_H}" '
               f'fill="{INK}" stroke="url(#goldGrad)" stroke-width="1.6" filter="url(#shadow)"/>')
    for c in range(6):
        bx = right_x + BAR23_PAD + c * (BAR_BTN + BAR23_GAP)
        by = BAR23_Y + BAR23_PAD
        svg.append(f'<rect x="{bx}" y="{by}" width="{BAR_BTN}" height="{BAR_BTN}" '
                   f'fill="#141418" stroke="#32323c" stroke-width="1"/>')

    bay_l = CX - BAY_HALF
    if mode == "combat":
        svg.append(f'<rect x="{bay_l}" y="{FLUSH_TOP_Y}" width="{BAY_W}" height="{BAR7_H}" '
                   f'fill="{INK}" stroke="url(#goldGrad)" stroke-width="2" filter="url(#shadow)"/>')
        for r in range(2):
            for c in range(5):
                bx = bay_l + GRID_PAD + c * (GRID_BTN + GRID_GAP)
                by = FLUSH_TOP_Y + GRID_PAD + r * (GRID_BTN + GRID_GAP)
                svg.append(f'<rect x="{bx}" y="{by}" width="{GRID_BTN}" height="{GRID_BTN}" '
                           f'fill="#1a1a20" stroke="#383842" stroke-width="1"/>')
        tr_size = TR_MINIMAP_SIZE
        tr_r = W - 28
        tr_l = tr_r - tr_size
        tr_top = 28
        svg.append(f'<rect x="{tr_l}" y="{tr_top}" width="{tr_size}" height="{tr_size}" '
                   f'fill="none" stroke="url(#goldGrad)" stroke-width="2.5" filter="url(#shadow)"/>')
    else:
        svg.append(f'<rect x="{bay_l}" y="{FLUSH_TOP_Y}" width="{BAY_W}" height="{MINIMAP_H}" '
                   f'fill="none" stroke="url(#goldGrad)" stroke-width="2.5" filter="url(#shadow)"/>')

    party_l = 36
    party_start_y = 500
    for p in range(4):
        py = party_start_y + p * (PARTY_H + PARTY_GAP)
        svg.append(f'<rect x="{party_l}" y="{py}" width="{PARTY_W}" height="{PARTY_H}" '
                   f'fill="none" stroke="{GOLD_D}" stroke-width="1.4" filter="url(#shadow)"/>')

    svg.append('</svg>')
    return "".join(svg)


def composite_mockup(mode="combat", bar1_hidden=False):
    """Render full mockup with status bar fills, toolkit icon, text, and buttons."""
    if os.path.exists(BASE):
        canvas = Image.open(BASE).convert("RGBA").crop((0, 0, W, H))
        ground_patch = canvas.crop((0, 750, W, 790)).resize((W, H - 800), Image.BILINEAR)
        canvas.paste(ground_patch, (0, 800))
    else:
        canvas = Image.new("RGBA", (W, H), (20, 22, 28, 255))

    draw = ImageDraw.Draw(canvas)
    left_x = CX - BAY_HALF - WING_W
    right_x = CX + BAY_HALF
    bay_l = CX - BAY_HALF
    bar1_top_l = CX - BAR1_TOP_W // 2

    hyb_top = HYBRID_Y
    hyb_bot = HYBRID_Y + HYBRID_H
    hyb_tl = CX - HYBRID_TOP_W / 2
    hyb_tr = CX + HYBRID_TOP_W / 2
    hyb_bl = hyb_tl - HYBRID_DX
    hyb_br = hyb_tr + HYBRID_DX

    # Trapezoid ink background / well
    draw.polygon([(hyb_bl, hyb_bot), (hyb_tl, hyb_top), (hyb_tr, hyb_top), (hyb_br, hyb_bot)], fill=(12, 12, 16, 255))
    if mode == "combat":
        n_segs = 5
        seg_gap = 3
        seg_w = (HYBRID_TOP_W - (n_segs - 1) * seg_gap) / n_segs
        for i in range(n_segs):
            sx0 = hyb_tl + i * (seg_w + seg_gap)
            sx1 = sx0 + seg_w
            col = (232, 198, 92, 255) if i < 4 else (55, 48, 30, 255)
            if i == 0:
                draw.polygon([(sx0 - HYBRID_DX, hyb_bot - 1), (sx0, hyb_top + 1), (sx1, hyb_top + 1), (sx1, hyb_bot - 1)], fill=col)
            elif i == n_segs - 1:
                draw.polygon([(sx0, hyb_top + 1), (sx1, hyb_top + 1), (sx1 + HYBRID_DX, hyb_bot - 1), (sx0, hyb_bot - 1)], fill=col)
            else:
                draw.rectangle([sx0, hyb_top + 1, sx1, hyb_bot - 1], fill=col)
    else:
        n_segs = 6
        seg_gap = 3
        seg_w = (HYBRID_TOP_W - (n_segs - 1) * seg_gap) / n_segs
        for i in range(n_segs):
            sx0 = hyb_tl + i * (seg_w + seg_gap)
            sx1 = sx0 + seg_w
            col = (50, 178, 242, 230)
            if i == 0:
                draw.polygon([(sx0 - HYBRID_DX, hyb_bot - 1), (sx0, hyb_top + 1), (sx1, hyb_top + 1), (sx1, hyb_bot - 1)], fill=col)
            elif i == n_segs - 1:
                draw.polygon([(sx0, hyb_top + 1), (sx1, hyb_top + 1), (sx1 + HYBRID_DX, hyb_bot - 1), (sx0, hyb_bot - 1)], fill=col)
            else:
                draw.rectangle([sx0, hyb_top + 1, sx1, hyb_bot - 1], fill=col)

    draw.rectangle([left_x, UNIT_Y, left_x + WING_W, UNIT_Y + HEALTH_H], fill=(16, 16, 20, 255))
    hp_fill_w = int(WING_W * 0.85)
    for x_i in range(hp_fill_w):
        t = x_i / WING_W
        draw.line([(left_x + x_i, UNIT_Y + 1), (left_x + x_i, UNIT_Y + HEALTH_H - 1)],
                  fill=(int(210 + 35 * t), int(90 + 30 * t), 10, 255))

    draw.rectangle([left_x, POWER_Y, left_x + WING_W, POWER_Y + POWER_H], fill=(14, 14, 18, 255))
    draw.rectangle([left_x + 1, POWER_Y + 1, left_x + int(WING_W * 0.72), POWER_Y + POWER_H - 1],
                   fill=(0, 150, 245, 255))

    draw.rectangle([left_x, XP_Y, left_x + WING_W, XP_Y + XP_H], fill=(12, 12, 16, 255))
    draw.rectangle([left_x + 1, XP_Y + 1, left_x + int(WING_W * 0.64), XP_Y + XP_H - 1],
                   fill=(148, 60, 210, 255))

    draw.rectangle([right_x, UNIT_Y, right_x + WING_W, UNIT_Y + HEALTH_H], fill=(16, 16, 20, 255))
    draw.rectangle([right_x, POWER_Y, right_x + WING_W, POWER_Y + POWER_H], fill=(14, 14, 18, 255))
    if mode == "combat":
        thp_fill_w = int(WING_W * 0.60)
        draw.rectangle([right_x + WING_W - thp_fill_w, UNIT_Y + 1, right_x + WING_W - 1, UNIT_Y + HEALTH_H - 1],
                       fill=(196, 36, 28, 255))
        tpow_fill_w = int(WING_W * 0.80)
        draw.rectangle([right_x + WING_W - tpow_fill_w, POWER_Y + 1, right_x + WING_W - 1, POWER_Y + POWER_H - 1],
                       fill=(188, 28, 28, 255))

    draw.rectangle([right_x, XP_Y, right_x + WING_W, XP_Y + XP_H], fill=(12, 12, 16, 255))
    rep_w = int(WING_W * 0.48)
    draw.rectangle([right_x + WING_W - rep_w, XP_Y + 1, right_x + WING_W - 1, XP_Y + XP_H - 1],
                   fill=(40, 175, 80, 255))

    tr_size = TR_MINIMAP_SIZE
    tr_r = W - 28
    tr_l = tr_r - tr_size
    tr_top = 28
    if mode == "explore":
        draw.rectangle([bay_l, FLUSH_TOP_Y, bay_l + BAY_W, FLUSH_TOP_Y + MINIMAP_H], fill=(32, 46, 42, 255))
        draw.line([(bay_l + 25, FLUSH_TOP_Y + 45), (bay_l + BAY_W - 30, FLUSH_TOP_Y + 120)], fill=(90, 85, 70, 255), width=3)
        draw.line([(bay_l + 95, FLUSH_TOP_Y + 20), (bay_l + 80, FLUSH_TOP_Y + MINIMAP_H - 20)], fill=(90, 85, 70, 255), width=2)
    else:
        draw.rectangle([tr_l, tr_top, tr_r, tr_top + tr_size], fill=(32, 46, 42, 255))
        draw.line([(tr_l + 25, tr_top + 45), (tr_l + tr_size - 30, tr_top + 130)], fill=(90, 85, 70, 255), width=3)

    party_l = 36
    party_start_y = 500
    party_colors = [(255, 255, 255), (199, 156, 110), (64, 199, 235), (255, 245, 105)]
    party_hps = [0.95, 0.78, 1.0, 0.88]
    for p in range(4):
        py = party_start_y + p * (PARTY_H + PARTY_GAP)
        draw.rectangle([party_l, py, party_l + PARTY_W, py + PARTY_H], fill=(16, 16, 20, 255))
        pw_fill = int((PARTY_W - 4) * party_hps[p])
        draw.rectangle([party_l + 2, py + 2, party_l + 2 + pw_fill, py + PARTY_H - 6], fill=party_colors[p] + (220,))
        draw.rectangle([party_l + 2, py + PARTY_H - 5, party_l + int((PARTY_W - 4) * 0.7), py + PARTY_H - 2], fill=(0, 120, 220, 255))

    svg_str = draw_console_svg(mode=mode, bar1_hidden=bar1_hidden)
    png_tmp = os.path.join(OUT, f"temp_frame_{mode}_{bar1_hidden}.png")
    frame_img = rsvg(svg_str, png_tmp)
    if os.path.exists(png_tmp):
        os.remove(png_tmp)

    canvas.alpha_composite(frame_img)

    f_large = get_font(19)
    f_med = get_font(12)
    f_small = get_font(9)
    f_bind = get_font(9)

    draw = ImageDraw.Draw(canvas)
    if not bar1_hidden:
        tk_icon = make_toolkit_icon(size=22)
        drawer_cx = bar1_top_l + 4 + END_PANEL_W // 2
        drawer_cy = BAR1_Y + BAR1_TOP_PAD + BAR_BTN // 2
        canvas.alpha_composite(tk_icon, (drawer_cx - 11, drawer_cy - 11))

        slots_l = bar1_top_l + 5 + END_PANEL_W
        pager_l = slots_l + 12 * BAR_BTN + 11 * BAR_GAP + 3
        num_cx = pager_l + 4 + 13 + 2 + 5
        num_cy = BAR1_Y + BAR1_TOP_PAD + 15
        draw.text((num_cx, num_cy), "1", font=f_small, fill=(224, 184, 74), anchor="mm")

        bar1_binds = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "="]
        bar1_hues = [(160, 50, 40), (50, 110, 170), (170, 130, 40), (50, 150, 80), (130, 60, 160), (180, 90, 30)]
        for c in range(12):
            bx = slots_l + c * (BAR_BTN + BAR_GAP)
            by = BAR1_Y + BAR1_TOP_PAD
            if c < 7:
                draw.rectangle([bx + 1, by + 1, bx + BAR_BTN - 1, by + BAR_BTN - 1],
                               fill=bar1_hues[c % len(bar1_hues)] + (220,))
            draw.text((bx + BAR_BTN - 2, by + 2), bar1_binds[c], font=f_bind, fill=(230, 230, 230), anchor="rt")

    if mode == "combat":
        binds_row1 = ["S2", "SX", "SC", "SV", "SB"]
        binds_row2 = ["2", "X", "C", "V", "B"]
        hues = [(190, 55, 45), (45, 125, 190), (190, 145, 45), (65, 165, 85), (145, 65, 170)]
        for c in range(5):
            bx = bay_l + GRID_PAD + c * (GRID_BTN + GRID_GAP)
            by1 = FLUSH_TOP_Y + GRID_PAD
            by2 = FLUSH_TOP_Y + GRID_PAD + GRID_BTN + GRID_GAP
            draw.rectangle([bx + 1, by1 + 1, bx + GRID_BTN - 1, by1 + GRID_BTN - 1], fill=hues[c] + (255,))
            draw.text((bx + GRID_BTN - 3, by1 + 3), binds_row1[c], font=f_bind, fill=(255, 255, 255), anchor="rt")
            draw.rectangle([bx + 1, by2 + 1, bx + GRID_BTN - 1, by2 + GRID_BTN - 1], fill=hues[(c + 2) % 5] + (255,))
            draw.text((bx + GRID_BTN - 3, by2 + 3), binds_row2[c], font=f_bind, fill=(255, 255, 255), anchor="rt")

        draw.text((tr_l + tr_size // 2, tr_top + 16), "DUN MOROGH", font=f_small, fill=(242, 234, 210), anchor="mm")
        draw.ellipse([tr_l + tr_size // 2 - 3, tr_top + tr_size // 2 - 3,
                      tr_l + tr_size // 2 + 3, tr_top + tr_size // 2 + 3], fill=(255, 255, 255, 255))
    else:
        draw.text((CX, FLUSH_TOP_Y + 14), "STORMWIND CITY", font=f_small, fill=(242, 234, 210), anchor="mm")
        draw.ellipse([CX - 3, FLUSH_TOP_Y + MINIMAP_H // 2 - 3,
                      CX + 3, FLUSH_TOP_Y + MINIMAP_H // 2 + 3], fill=(255, 255, 255, 255))

    b2_binds = ["s1", "s2", "s3", "s4", "s5", "s6"]
    b3_binds = ["c1", "c2", "c3", "c4", "c5", "c6"]
    for c in range(6):
        bx2 = left_x + BAR23_PAD + c * (BAR_BTN + BAR23_GAP)
        draw.text((bx2 + BAR_BTN - 2, BAR23_Y + BAR23_PAD + 2), b2_binds[c], font=f_bind, fill=(170, 170, 170), anchor="rt")
        bx3 = right_x + BAR23_PAD + c * (BAR_BTN + BAR23_GAP)
        draw.text((bx3 + BAR_BTN - 2, BAR23_Y + BAR23_PAD + 2), b3_binds[c], font=f_bind, fill=(170, 170, 170), anchor="rt")

    party_names = ["Eleni", "Kragor", "Mirabelle", "Sly"]
    party_roles = ["H", "T", "D", "D"]
    for p in range(4):
        py = party_start_y + p * (PARTY_H + PARTY_GAP)
        draw.rectangle([party_l + 4, py + 4, party_l + 18, py + 18], fill=(30, 30, 35, 255), outline=(180, 150, 60))
        draw.text((party_l + 11, py + 11), party_roles[p], font=f_bind, fill=(240, 240, 240), anchor="mm")
        draw.text((party_l + 24, py + 12), party_names[p], font=f_small, fill=(20, 20, 20), anchor="lm")
        draw.text((party_l + PARTY_W - 8, py + 12), f"{int(party_hps[p]*100)}%", font=f_small, fill=(20, 20, 20), anchor="rm")

    return canvas


def main():
    os.makedirs(OUT, exist_ok=True)
    if len(sys.argv) > 1 and sys.argv[1] == "export":
        export_all()
        return

    print("Generating lightweight console previews...")
    combat_img = composite_mockup(mode="combat", bar1_hidden=False)
    explore_img = composite_mockup(mode="explore", bar1_hidden=False)
    solo_img = composite_mockup(mode="combat", bar1_hidden=True)

    combat_img.save(os.path.join(OUT, "light-console-combat.png"))
    explore_img.save(os.path.join(OUT, "light-console-explore.png"))
    solo_img.save(os.path.join(OUT, "light-console-bar1-hidden.png"))

    crop_box = (CX - 360, 835, CX + 360, 1075)
    c_combat = combat_img.crop(crop_box)
    c_explore = explore_img.crop(crop_box)
    c_solo = solo_img.crop(crop_box)

    sheet_w = c_combat.width
    sheet_h = c_combat.height * 3 + 32
    sheet = Image.new("RGBA", (sheet_w, sheet_h), (12, 13, 16, 255))
    sheet.paste(c_explore, (0, 0))
    sheet.paste(c_combat, (0, c_combat.height + 16))
    sheet.paste(c_solo, (0, (c_combat.height + 16) * 2))

    sheet_path = os.path.join(OUT, "light-console-preview.png")
    sheet.save(sheet_path)
    print(f"Saved preview sheet to {sheet_path}")
    print(f"Saved standalone Bar1-hidden mockup to {os.path.join(OUT, 'light-console-bar1-hidden.png')}")


if __name__ == "__main__":
    main()
