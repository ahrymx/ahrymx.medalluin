#!/usr/bin/env python3
"""Action bar 1's frame, Medaluin's own art, drawn here from shapes: pure
geometry, no gryphons (the user's sketch, after plan/2026-10-31_20-17-39.png):

       /                                \
      /        [Actionbar 1 row]         \
     /                                    \
    /    [castbar/alternative power row]   \

  * one stone plate standing on the console, symmetric about the centre
    line. Its sides are straight where the rows need the room and slanted
    where they can be: upright beside the upper row's end panels, then a
    45-degree skirt that runs on the console's own 45-degree shoulder line,
    so the plate's sides and the console's shoulders read as one edge. The
    foot tucks under the console's border, so the plate draws BELOW the
    console art;
  * the upper row: the 12 slots with a stone pillar in every gap, and an end
    panel at each side. The right end holds the page chevrons (two boxes,
    up over down) and the page number's box; the left end holds the minimap
    button drawer's toggle, a round button showing through a round window
    centred where the right end's boxes are, the window smaller than the
    button so the stone covers its gold rim; the outline stays symmetric
    and bar 1 stays centred on the console;
  * behind the slots, a dark backing drawn by code (bars/bar.lua), so an
    empty slot shows a well and not the world behind it;
  * the lower row: one pill-shaped window as wide as the upper row, end
    panels included, for the player's cast bar (bars/cast.lua) and, when no cast is
    running, the class resource (bars/power.lua);
  * the chevrons themselves (up and down, normal and pushed, and a shared
    highlight), as small textures for Blizzard's own page buttons to wear,
    and the drawer toggle: the user's toolkit icon (plan/toolkit.png),
    recoloured from its pink-to-blue gradient to the console's navy and
    gold, in a gold rim.

Rows 2 and 3 (the Rows option) stand above the frame, bare.

    python3 art/bars/gen_bar.py          -> plan/bar.png (1 row), plan/bar-rows.png (1, 2, 3),
                                            plan/bar-frame.png, plan/bar-drawer.png
    python3 art/bars/gen_bar.py layer2   -> assets/layer2.png, assets/layer2.json, assets/bar/*.png

assets/layer2.png is the plate in the console's asset format (a 1920x1081
screen) with every window punched out: the 12 slots and the lower row.
assets/layer2.json lists them, the pager's boxes, and the rows above the
frame. art/console/export.py checks the holes against the list and writes
media/actionbar.tga, media/bar/*.tga and bars/windows.lua.

Distances are 1080p screen pixels, from the centre line.
"""
import base64
import io
import json
import os
import subprocess
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
OUT = os.path.join(HERE, "render")
BASE = os.path.join(ROOT, "plan", "H-party-combat-screen.png")
PARTS = os.path.join(ROOT, "assets", "bar")
TOOLKIT = os.path.join(ROOT, "plan", "toolkit.png")

W, H, CX = 1920, 1080, 960
CONSOLE_TOP = 916                 # the console art's top edge (export.py bbox)
GOLD, GOLD_D, INK = "#e0b84a", "#8a6a24", "#0d0d0e"
STONE_HI, STONE, STONE_LO, STONE_EDGE = "#8e8c88", "#5c5a57", "#3a3937", "#141414"
COUNT, MAX_ROWS = 12, 3
# Whole pixels at 1080p, so every edge stays crisp: icon; the pillar between
# slots; the gap between the rows above the frame; the frame's band above
# the slots; the end panel's width beyond the last slot; the band between
# the two rows; the lower row's height; the band under it, down to the
# console's top edge; the foot under the console's border; and the cut on
# the frame's top corners.
ICON, PILLAR, ROW_GAP, BAND, END = 36, 6, 4, 6, 40
MID_BAND, LOW_H, LOW_BAND, FOOT, CUT = 4, 14, 5, 2, 4
# The console's top edge is CONSOLE_HALF either side of the centre line at
# CONSOLE_TOP, and its shoulders widen from there at 45 degrees (measured on
# assets/layer0.png); the skirt runs on that line.
CONSOLE_HALF = 322
# The right end panel, from the last slot's edge: the chevron boxes' inset
# and size (two boxes, one over the other, PAGER_GAP apart), and the page
# number's box beside them.
# They stand 6px clear of the plate's edge, as far as the slots stand apart.
CHEVRON_IN, CHEVRON_W, CHEVRON_H, PAGER_GAP = 6, 16, 15, 2
NUMBER_IN, NUMBER_W, NUMBER_H = 2, 10, 15
# The chevron textures' canvas; the drawer toggle's texture, its button's
# diameter, and the diameter of the plate's window over it (the icon's gold
# rim starts at 0.86 of its radius, so a smaller window hides it).
TEX = 32
TOOL_TEX, TOOL_D, HOLE_D = 64, 32, 27

HUES = [("#e0b25a", "#5a3a10"), ("#d0603a", "#3a0e06"), ("#7f9ce0", "#16224a"),
        ("#9ccc6a", "#1e3a10"), ("#b384de", "#2a1046"), ("#ead08a", "#5a4416"),
        ("#6ab8b0", "#103a36"), ("#e08a5a", "#4a1806"), ("#b0b6c6", "#262a36"),
        ("#d6b45e", "#4a3610"), ("#8aaa5a", "#1a2a0a"), ("#c86a7a", "#3a0e18")]

WIDTH = COUNT * ICON + (COUNT - 1) * PILLAR
HALF = WIDTH // 2                         # the slots' half-width
FRAME_HALF = HALF + END                   # the upper row, end panels included
LOW_BOTTOM = CONSOLE_TOP - LOW_BAND
LOW_TOP = LOW_BOTTOM - LOW_H
SLOT_BOTTOM = LOW_TOP - MID_BAND
SLOT_TOP = SLOT_BOTTOM - ICON
FRAME_TOP = SLOT_TOP - BAND
FOOT_Y = CONSOLE_TOP + FOOT
LOW = (CX - FRAME_HALF, LOW_TOP, CX + FRAME_HALF, LOW_BOTTOM)


def shoulder(y):
    """The console's shoulder line: its half-width at height y."""
    return CONSOLE_HALF + (y - CONSOLE_TOP)


# where the upright side meets the skirt
KNEE_Y = CONSOLE_TOP - (CONSOLE_HALF - FRAME_HALF)
FOOT_HALF = shoulder(FOOT_Y)
assert WIDTH % 2 == 0 and SLOT_TOP < KNEE_Y < LOW_TOP
assert shoulder(LOW_TOP) - FRAME_HALF >= 4  # stone beside the lower row


def pts(p):
    return " ".join(f"{x:.1f},{y:.1f}" for x, y in p)


def mirror(left):
    """A polygon's left half and its mirror, so it is symmetric by
    construction."""
    return left + [(2 * CX - x, y) for x, y in reversed(left)]


def slots(rows):
    """Each row's slots as (x, y) top-left corners, bottom row (bar 1) first:
    bar 1 sits in the frame, each row above it on the frame's top edge."""
    out = []
    for r in range(rows):
        y = SLOT_TOP if r == 0 else FRAME_TOP - ROW_GAP - ICON - (r - 1) * (ICON + ROW_GAP)
        out.append([(CX - HALF + i * (ICON + PILLAR), y) for i in range(COUNT)])
    return out


def pager_boxes():
    """The right end's boxes, as (left, top, right, bottom): the up chevron,
    the down chevron, the page number."""
    x = CX + HALF + CHEVRON_IN
    mid = (SLOT_TOP + SLOT_BOTTOM) // 2
    up = (x, mid - PAGER_GAP // 2 - CHEVRON_H, x + CHEVRON_W, mid - PAGER_GAP // 2)
    down = (x, mid + PAGER_GAP // 2, x + CHEVRON_W, mid + PAGER_GAP // 2 + CHEVRON_H)
    nx = x + CHEVRON_W + NUMBER_IN
    number = (nx, mid - NUMBER_H // 2, nx + NUMBER_W, mid - NUMBER_H // 2 + NUMBER_H)
    return {"up": up, "down": down, "number": number}


def drawer_box():
    """The left end's box, the drawer's toggle: the mirror of the right
    end's boxes taken together."""
    b = pager_boxes()
    return (2 * CX - b["number"][2], b["up"][1], 2 * CX - b["up"][0], b["down"][3])


def toggle_centre():
    l, t, r, b = drawer_box()
    return (l + r) / 2, (t + b) / 2


# The drawer, outside the plate: a cell per minimap button, the button
# fitted inside it, the panel's padding, and its gap from the plate (when
# it opens left) or from the frame's top (when it opens up).
CELL, CELL_BUTTON, DRAWER_PAD, DRAWER_GAP = 34, 30, 2, 4


def drawer_panel(direction, n):
    """The open drawer's panel as (left, top, right, bottom): one line of n
    cells, left beside the plate at the upper row's height, or up from the
    frame's top over the toggle's centre (clear of rows 2 and 3, which only
    span the slots)."""
    long, short = n * CELL + 2 * DRAWER_PAD, CELL + 2 * DRAWER_PAD
    if direction == "left":
        r = CX - FRAME_HALF - DRAWER_GAP
        mid = (SLOT_TOP + SLOT_BOTTOM) / 2
        return (r - long, mid - short / 2, r, mid + short / 2)
    l, _, r, _ = drawer_box()
    mid = (l + r) / 2
    b = FRAME_TOP - DRAWER_GAP
    return (mid - short / 2, b - long, mid + short / 2, b)


def frame_outline():
    """The plate, from its foot's left corner round to its right."""
    fx = CX - FRAME_HALF
    return mirror([(CX - FOOT_HALF, FOOT_Y), (fx, KNEE_Y), (fx, FRAME_TOP + CUT), (fx + CUT, FRAME_TOP)])


def holes():
    """Every window, as (left, top, right, bottom)."""
    return [(x, y, x + ICON, y + ICON) for x, y in slots(1)[0]] + [LOW]


def stone_defs(defs):
    defs.append(
        f'<linearGradient id="stone" x1="0" y1="0" x2="0" y2="1">'
        f'<stop offset="0" stop-color="{STONE_HI}"/><stop offset="0.18" stop-color="{STONE}"/>'
        f'<stop offset="0.8" stop-color="{STONE}"/><stop offset="1" stop-color="{STONE_LO}"/></linearGradient>'
        f'<linearGradient id="pillar" x1="0" y1="0" x2="1" y2="0">'
        f'<stop offset="0" stop-color="{STONE_LO}"/><stop offset="0.45" stop-color="{STONE_HI}"/>'
        f'<stop offset="1" stop-color="{STONE_LO}"/></linearGradient>'
        f'<linearGradient id="well" x1="0" y1="0" x2="0" y2="1">'
        f'<stop offset="0" stop-color="#050505"/><stop offset="1" stop-color="#1c1b1a"/></linearGradient>'
        # a faint grain, so the stone is not a flat fill
        f'<filter id="grain" x="0" y="0" width="100%" height="100%">'
        f'<feTurbulence type="fractalNoise" baseFrequency="0.55" numOctaves="2" seed="7" result="n"/>'
        f'<feColorMatrix in="n" type="matrix" values="0 0 0 0 0  0 0 0 0 0  0 0 0 0 0  0 0 0 0.9 -0.35"/>'
        f'<feComposite in2="SourceGraphic" operator="in"/></filter>')


def well(l, t, r, b):
    """A recessed box: dark inside, shadowed along the top and left, lit
    along the bottom and right, with a black edge."""
    return (f'<rect x="{l - 1}" y="{t - 1}" width="{r - l + 2}" height="{b - t + 2}" fill="{STONE_EDGE}"/>'
            f'<rect x="{l}" y="{t}" width="{r - l}" height="{b - t}" fill="url(#well)"/>'
            f'<line x1="{l - 1}" y1="{b + 1.5}" x2="{r + 1}" y2="{b + 1.5}" stroke="{STONE_HI}" stroke-width="1"/>')


def plate(defs):
    """The plate's art, its windows cut by a mask: the slots and the lower
    row's pill, and the toggle's round window. The plate draws OVER what
    shows through them (the slot backing, the cast bar and class resource,
    the toggle), so its edges crop them."""
    stone_defs(defs)
    cx, cy = toggle_centre()
    l, t, r, b = LOW
    rr = (b - t) / 2
    defs.append(f'<mask id="holes" maskUnits="userSpaceOnUse" x="0" y="0" width="{W}" height="{H + 1}">'
                f'<rect width="{W}" height="{H + 1}" fill="#fff"/>'
                + "".join(f'<rect x="{x}" y="{y}" width="{ICON}" height="{ICON}" fill="#000"/>'
                          for x, y in slots(1)[0])
                + f'<rect x="{l}" y="{t}" width="{r - l}" height="{b - t}" rx="{rr}" fill="#000"/>'
                f'<circle cx="{cx}" cy="{cy}" r="{HOLE_D / 2}" fill="#000"/></mask>')
    f = frame_outline()
    body = ['<g mask="url(#holes)">',
            f'<polygon points="{pts(f)}" fill="url(#stone)" stroke="{STONE_EDGE}" stroke-width="1.6"/>',
            f'<polygon points="{pts(f)}" fill="#fff" filter="url(#grain)"/>']
    # the bevel: a lit line just inside the top edge and down both sides
    i = 1.5
    fx = CX - FRAME_HALF
    lit = mirror([(CX - FOOT_HALF + 2 * i, CONSOLE_TOP), (fx + i, KNEE_Y + i), (fx + i, FRAME_TOP + CUT),
                  (fx + CUT, FRAME_TOP + i)])
    body.append(f'<polyline points="{pts(lit)}" fill="none" stroke="{STONE_HI}" stroke-width="1" opacity="0.7"/>')
    # the band between the rows: a seam, lit below, so the rows read as two
    seam = SLOT_BOTTOM + MID_BAND / 2 + 1
    body.append(f'<line x1="{fx + 3}" y1="{seam}" x2="{2 * CX - fx - 3}" y2="{seam}" '
                f'stroke="{STONE_LO}" stroke-width="1"/>')
    # a pillar in every gap between the slots
    for x, _ in slots(1)[0][1:]:
        body.append(f'<rect x="{x - PILLAR}" y="{SLOT_TOP - 1}" width="{PILLAR}" height="{ICON + 2}" '
                    f'fill="url(#pillar)"/>')
    # each end panel is set off from the slots by a seam
    for side in (-1, 1):
        x = CX + side * (HALF + 1.5)
        body.append(f'<line x1="{x}" y1="{FRAME_TOP + 3}" x2="{x}" y2="{SLOT_BOTTOM + 1}" '
                    f'stroke="{STONE_LO}" stroke-width="1"/>')
    for x, y in slots(1)[0]:
        body.append(well(x, y, x + ICON, y + ICON))
    # the pill and the round window: a black edge only
    body.append(f'<rect x="{l - 1}" y="{t - 1}" width="{r - l + 2}" height="{b - t + 2}" rx="{rr + 1}" '
                f'fill="{STONE_EDGE}"/>'
                f'<circle cx="{cx}" cy="{cy}" r="{HOLE_D / 2 + 1.2}" fill="{STONE_EDGE}"/>')
    b = pager_boxes()
    for k in ("up", "down", "number"):
        body.append(well(*b[k]))
    # the boxes get a gold rim, as the reference's do
    for k in ("up", "down", "number"):
        l, t, r, bt = b[k]
        body.append(f'<rect x="{l - 0.5}" y="{t - 0.5}" width="{r - l + 1}" height="{bt - t + 1}" '
                    f'fill="none" stroke="{GOLD_D}" stroke-width="1"/>')
    body.append('</g>')
    return "".join(body)


def backing():
    """The slots' backing, as bars/bar.lua draws it: one dark band behind
    every slot, under the plate."""
    row = slots(1)[0]
    return (f'<rect x="{row[0][0]}" y="{SLOT_TOP}" width="{row[-1][0] + ICON - row[0][0]}" height="{ICON}" '
            f'fill="{INK}"/>')


# ------------------------------------------------------------ chevrons
def chevron_svg(direction, state):
    """One chevron texture: a gold arrowhead on transparency, drawn for a
    button the size of a chevron box's inside. Pushed sits a pixel lower
    and darker; the highlight is a soft glow for either arrow."""
    s = TEX
    defs = (f'<linearGradient id="g" x1="0" y1="0" x2="0" y2="1">'
            f'<stop offset="0" stop-color="#fff2b0"/><stop offset="0.5" stop-color="{GOLD}"/>'
            f'<stop offset="1" stop-color="{GOLD_D}"/></linearGradient>')
    if state == "highlight":
        body = (f'<radialGradient id="h" cx="50%" cy="50%" r="50%"><stop offset="0" stop-color="#ffe9a0" '
                f'stop-opacity="0.55"/><stop offset="1" stop-color="#ffe9a0" stop-opacity="0"/></radialGradient>'
                f'<rect width="{s}" height="{s}" fill="url(#h)"/>')
        return f'<svg xmlns="http://www.w3.org/2000/svg" width="{s}" height="{s}">{body}</svg>'
    # a solid arrowhead, as wide as the box allows
    dy = 2 if state == "pushed" else 0
    tip, base = (6, 24) if direction == "up" else (26, 8)
    poly = [(x, y + dy) for x, y in [(4, base), (16, tip), (28, base)]]
    fill = "url(#g)" if state == "normal" else GOLD_D
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{s}" height="{s}"><defs>{defs}</defs>'
            f'<polygon points="{pts(poly)}" fill="{fill}" stroke="#1a1206" stroke-width="2.2" '
            f'stroke-linejoin="round"/></svg>')


CHEVRONS = {"chevron-up": ("up", "normal"), "chevron-up-pushed": ("up", "pushed"),
            "chevron-down": ("down", "normal"), "chevron-down-pushed": ("down", "pushed"),
            "chevron-highlight": ("up", "highlight")}


def toolkit(state):
    """The drawer toggle's texture, TOOL_TEX square: the toolkit icon with
    its gradient taken out and the console's colours put in. The icon is a
    disc in a horizontal pink-to-blue gradient with the case drawn in white
    over it (the hammer is the gradient again, through the case), so every
    pixel is white mixed with the gradient colour at its column, and the mix
    is solved for: 0 is the disc, 1 the case. The disc becomes navy, the
    case gold, both lit from above, and a gold rim goes round. Pushed is
    darker and a pixel lower."""
    src = np.asarray(Image.open(TOOLKIT).convert("RGBA")).astype(float)
    n = src.shape[0]
    rgb, alpha = src[..., :3], src[..., 3] / 255
    # the gradient, read off the disc's middle row either side of the case
    left, right = src[n // 2, n // 64, :3], src[n // 2, n - 1 - n // 64, :3]
    x = (np.arange(n) - n // 64) / (n - 1 - 2 * (n // 64))
    grad = left + np.clip(x, 0, 1)[None, :, None] * (right - left)
    mix = np.clip(((rgb - grad) / np.maximum(255 - grad, 1)).mean(axis=2), 0, 1)

    y = (np.arange(n) / (n - 1))[:, None, None]
    def lit(top, bottom):
        return np.array(top, float) + y * (np.array(bottom, float) - np.array(top, float))
    navy, gold = lit((0x3e, 0x47, 0x60), (0x1a, 0x1e, 0x2b)), lit((0xf6, 0xdc, 0x8a), (0xa8, 0x82, 0x30))
    out = navy * (1 - mix[..., None]) + gold * mix[..., None]

    # the rim: gold, dark on its outer edge, over the disc's own edge
    yy, xx = np.mgrid[0:n, 0:n]
    d = np.hypot(xx - (n - 1) / 2, yy - (n - 1) / 2) / (n / 2)
    rim = np.clip((d - 0.86) * 40, 0, 1)[..., None]
    edge = np.clip((d - 0.96) * 40, 0, 1)[..., None]
    out = out * (1 - rim) + lit((0xe0, 0xb8, 0x4a), (0x8a, 0x6a, 0x24)) * rim
    out = out * (1 - edge) + np.array((0x1a, 0x12, 0x06), float) * edge
    if state == "pushed":
        out = out * 0.72
    img = Image.fromarray(np.dstack([out, alpha * 255]).clip(0, 255).astype(np.uint8), "RGBA")
    return img.resize((TOOL_TEX, TOOL_TEX), Image.LANCZOS)


def toolkit_pushed():
    """Pushed: darker, and lower by a screen pixel."""
    img = toolkit("pushed")
    moved = Image.new("RGBA", img.size, (0, 0, 0, 0))
    moved.paste(img, (0, TOOL_TEX // TOOL_D))
    return moved


TOOLKIT_PARTS = {"toolkit": lambda: toolkit("normal"), "toolkit-pushed": toolkit_pushed}


def parts():
    os.makedirs(PARTS, exist_ok=True)
    for name, (d, state) in CHEVRONS.items():
        rsvg(chevron_svg(d, state), os.path.join(PARTS, f"{name}.png"))
    for name in ("drawer-left", "drawer-left-pushed", "drawer-right", "drawer-right-pushed",
                 "drawer-up", "drawer-up-pushed", "drawer-down", "drawer-down-pushed"):
        if os.path.exists(os.path.join(PARTS, f"{name}.png")):
            os.remove(os.path.join(PARTS, f"{name}.png"))       # the arrow glyphs the toolkit replaced
    for name, make in TOOLKIT_PARTS.items():
        make().save(os.path.join(PARTS, f"{name}.png"))


def chevrons_drawn():
    """The chevrons in their boxes, for the mockup, as code shows them."""
    b, out = pager_boxes(), []
    for k in ("up", "down"):
        l, t, r, bt = b[k]
        out.append(f'<svg x="{l + 1}" y="{t + 1}" width="{r - l - 2}" height="{bt - t - 2}" '
                   f'viewBox="0 0 {TEX} {TEX}" preserveAspectRatio="none">'
                   f'{chevron_svg(k, "normal").split(">", 1)[1].rsplit("</svg>", 1)[0]}</svg>')
    nl, nt, nr, nb = b["number"]
    out.append(f'<text x="{(nl + nr) / 2}" y="{nb - 4}" font-family="Friz Quadrata TT, serif" font-size="12" '
               f'fill="{GOLD}" text-anchor="middle">1</text>')
    return "".join(out)


def toggle_drawn():
    """The drawer toggle, under the plate, as code places it."""
    cx, cy = toggle_centre()
    out = []
    buf = io.BytesIO()
    toolkit("normal").save(buf, "PNG")
    out.append(f'<image x="{cx - TOOL_D / 2}" y="{cy - TOOL_D / 2}" width="{TOOL_D}" height="{TOOL_D}" '
               f'href="data:image/png;base64,{base64.b64encode(buf.getvalue()).decode()}"/>')
    return "".join(out)


# ------------------------------------------------------------ mockup
def icons(rows, defs):
    out, s = [], ICON
    for r, row in enumerate(slots(rows)):
        for k, (x, y) in enumerate(row):
            if r > 0:
                out.append(f'<rect x="{x}" y="{y}" width="{s}" height="{s}" fill="none" stroke="#6a665e" '
                           f'stroke-width="1.5" rx="2"/>')
                continue                  # rows 2 and 3: Blizzard's bare slots
            if k in (2, 3, 6, 7, 8, 9, 10, 11) and r == 0:
                continue                  # empty slots show the well
            light, dark = HUES[(k + 5 * r) % len(HUES)]
            gid = f"g{r}_{k}"
            defs.append(f'<radialGradient id="{gid}" cx="45%" cy="40%" r="70%"><stop offset="0" '
                        f'stop-color="{light}"/><stop offset="1" stop-color="{dark}"/></radialGradient>')
            out.append(f'<rect x="{x}" y="{y}" width="{s}" height="{s}" fill="url(#{gid})"/>')
    return "".join(out)


def power(n, lit):
    """The class resource in the lower row, as code draws it: n segments,
    1px apart, the first `lit` filled."""
    l, t, r, b = LOW
    seg = (r - l - (n - 1)) / n
    out = [f'<rect x="{l}" y="{t}" width="{r - l}" height="{b - t}" fill="{INK}"/>']
    for i in range(n):
        x = l + i * (seg + 1)
        out.append(f'<rect x="{x:.1f}" y="{t}" width="{seg:.1f}" height="{b - t}" '
                   f'fill="{"#e8c860" if i < lit else "#2a2620"}"/>')
    return "".join(out)


def wrap(defs, body, height=H):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{height}"><defs>'
            f'{"".join(defs)}</defs>{"".join(body)}</svg>')


def rsvg(svg_text, png):
    subprocess.run(["rsvg-convert", "-o", png], input=svg_text.encode(), check=True)
    return Image.open(png).convert("RGBA")


def layer2():
    """The plate with its windows punched out, the chevrons, and the layout
    as JSON."""
    defs = []
    img = rsvg(wrap(defs, [plate(defs)], height=1081), os.path.join(OUT, "layer2.png"))
    px = img.load()
    # the slots again by pixel, so a slot is exactly its hole (the pill and
    # the round window keep the mask's soft edge)
    for l, t, r, b in holes()[:-1]:
        for y in range(t, b):
            for x in range(l, r):
                px[x, y] = (0, 0, 0, 0)
    path = os.path.join(ROOT, "assets", "layer2.png")
    img.save(path)
    parts()
    layout = {
        "console_top": CONSOLE_TOP,
        "frame": [CX - FOOT_HALF, FRAME_TOP, CX + FOOT_HALF, FOOT_Y],
        "upper": [CX - FRAME_HALF, FRAME_TOP, CX + FRAME_HALF, SLOT_BOTTOM + MID_BAND],
        "low": list(LOW),
        "pager": {k: list(v) for k, v in pager_boxes().items()},
        "drawer": list(drawer_box()),
        "toggle": {"diameter": TOOL_D, "hole": HOLE_D},
        "drawer_cell": {"cell": CELL, "button": CELL_BUTTON, "pad": DRAWER_PAD,
                        # where the open line stands: its right edge (open
                        # left) and its bottom edge (open up)
                        "left": CX - FRAME_HALF - DRAWER_GAP, "up": FRAME_TOP - DRAWER_GAP},
        "parts": sorted(CHEVRONS) + sorted(TOOLKIT_PARTS),
        "rows": {str(n): [[[x, x + ICON, y, y + ICON] for x, y in row] for row in slots(n)]
                 for n in range(1, MAX_ROWS + 1)},
    }
    with open(os.path.join(ROOT, "assets", "layer2.json"), "w") as f:
        json.dump(layout, f, indent=1)
    print(path, img.getchannel("A").getbbox())


def cast(fraction, label):
    """A cast in the lower row, as bars/cast.lua draws it: the gold fill over
    the row's ink, a spark on its edge, the spell's name left, the time
    right."""
    l, t, r, b = LOW
    w = (r - l) * fraction
    text = 'font-family="Marcellus SC" font-size="10" fill="#f2ead2"'
    return (f'<rect x="{l}" y="{t}" width="{r - l}" height="{b - t}" fill="{INK}"/>'
            f'<rect x="{l}" y="{t}" width="{w:.1f}" height="{b - t}" fill="#d9b35c"/>'
            f'<rect x="{l + w - 1:.1f}" y="{t}" width="2" height="{b - t}" fill="#fff" opacity="0.8"/>'
            f'<text x="{l + 8}" y="{b - 3}" {text}>{label}</text>'
            f'<text x="{r - 8}" y="{b - 3}" {text} text-anchor="end">0.9</text>')


# minimap buttons, as the mockup's stand-ins: a round icon in a dark ring
MINIMAP_HUES = ["#c9a14a", "#6a9ad0", "#a0c060", "#c06a8a", "#8a7ad0"]


def drawer(direction, n=5):
    """The open drawer: its panel, a well like the boxes', and n round
    buttons in a line, as bars/drawer.lua lays them out."""
    l, t, r, b = drawer_panel(direction, n)
    out = [well(l, t, r, b),
           f'<rect x="{l - 0.5}" y="{t - 0.5}" width="{r - l + 1}" height="{b - t + 1}" fill="none" '
           f'stroke="{GOLD_D}" stroke-width="1"/>']
    for i in range(n):
        # the first cell sits next to the toggle
        if direction == "left":
            cx, cy = r - DRAWER_PAD - (i + 0.5) * CELL, (t + b) / 2
        else:
            cx, cy = (l + r) / 2, b - DRAWER_PAD - (i + 0.5) * CELL
        rr = CELL_BUTTON / 2
        out.append(f'<circle cx="{cx}" cy="{cy}" r="{rr}" fill="#1a1a1a" stroke="#b8a070" stroke-width="2"/>'
                   f'<circle cx="{cx}" cy="{cy}" r="{rr - 5}" fill="{MINIMAP_HUES[i % len(MINIMAP_HUES)]}"/>')
    return "".join(out)


def screen(rows, lit=3, casting=False, drawer_open=None):
    """The bar over the console's combat render; the plate's foot goes UNDER
    the console art, so the console is pasted back over it."""
    defs = []
    row = cast(0.62, "Frostbolt") if casting else power(5, lit)
    body = [backing(), row, toggle_drawn(), plate(defs), icons(rows, defs), chevrons_drawn()]
    if drawer_open:
        body.append(drawer(drawer_open))
    over = rsvg(wrap(defs, body), os.path.join(OUT, f"bar-{rows}.png"))
    base = Image.open(BASE).convert("RGBA").crop((0, 0, W, H))
    shot = Image.alpha_composite(base, over)
    shot.paste(base.crop((0, CONSOLE_TOP, W, H)), (0, CONSOLE_TOP),
               base.crop((0, CONSOLE_TOP, W, H)))
    return shot.convert("RGB")


def main():
    shots = [screen(r) for r in range(1, MAX_ROWS + 1)]
    crop = (560, 740, 1360, 1000)
    shots[0].crop(crop).resize((1600, 520), Image.LANCZOS).save(os.path.join(ROOT, "plan", "bar.png"))
    # bar 1 alone at twice the size: the class resource, then a cast
    frame = (620, 844, 1300, 930)
    w, h = frame[2] - frame[0], frame[3] - frame[1]
    pair = Image.new("RGB", (2 * w, 4 * h + 8), (10, 10, 10))
    pair.paste(shots[0].crop(frame).resize((2 * w, 2 * h), Image.LANCZOS), (0, 0))
    pair.paste(screen(1, casting=True).crop(frame).resize((2 * w, 2 * h), Image.LANCZOS), (0, 2 * h + 8))
    pair.save(os.path.join(ROOT, "plan", "bar-frame.png"))
    # the drawer open, left and up (with three rows, so it clears them)
    crop = (380, 620, 1360, 1000)
    w, h = crop[2] - crop[0], crop[3] - crop[1]
    sheet = Image.new("RGB", (2 * w + 8, h), (10, 10, 10))
    sheet.paste(screen(1, drawer_open="left").crop(crop), (0, 0))
    sheet.paste(screen(3, drawer_open="up").crop(crop), (w + 8, 0))
    sheet.save(os.path.join(ROOT, "plan", "bar-drawer.png"))
    w, h = crop[2] - crop[0], crop[3] - crop[1]
    sheet = Image.new("RGB", (w, h * MAX_ROWS))
    for i, s in enumerate(shots):
        sheet.paste(s.crop(crop), (0, i * h))
    path = os.path.join(ROOT, "plan", "bar-rows.png")
    sheet.save(path)
    print(path)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    layer2() if sys.argv[1:2] == ["layer2"] else main()
