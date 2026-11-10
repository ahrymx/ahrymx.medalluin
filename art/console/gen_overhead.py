#!/usr/bin/env python3
"""The overhead console: the decks that hang from the screen's top edge
(bosses, then pet / focus / target of target), in the console's brown and
gold, with the pet and stance bars laid over the plate's bottom rim as bare
icons (variant A, chosen 2026-11-01: one centred row, stances then pet bar;
the icon column on the LEFT of every unit). Round 2 (variant C, chosen the
same day): the icons sit inside a third deck, the tray, instead of hovering
over the floor; unit cells are 200 wide and every cell stretches to fill a
deck that had to grow. Round 3 (2026-11-01, variant A of `frames`): each
command icon is edged in gold, as the unit cells are.

    python3 art/console/gen_overhead.py            mockup -> art/console/render/overhead-C.png
    python3 art/console/gen_overhead.py export     pieces -> media/overhead/*.tga,
                                                    data   -> console/overhead_art.lua (after the check)
    python3 art/console/gen_overhead.py frames     the tray's gold-frame options -> render/overhead-frames.png
    python3 art/console/gen_overhead.py --check    assemble the pieces the way the Lua does, for every
                                                    boss/unit count, and compare with the plate drawn whole

This file is the one source of the geometry: the Lua reads it through the
generated console/overhead_art.lua. Never hand-edit that file.

The plate is one outline. Each deck is an inverted trapezoid with 45-degree
sides; a lower deck is LEDGE narrower than the floor of the deck above, so the
stack reads as an upside-down ziggurat: bosses, then companions, then the
tray of stance and pet icons. When a lower deck is too wide for that, the
decks above grow, and their cells stretch to fill the floor. A deck is three textures: a left wing
(its diagonal), a middle column stretched across, and the left wing mirrored.
The plate's gradient is fixed to the screen, so a deck's pieces depend on
the y it hangs at: pieces are named for their kind and that y (boss-0,
unit-34, tray-64, ...). A lower deck's pieces start OVERLAP rows above its own top, so they paint
over the upper deck's rim and hairline wherever the two decks meet; cut from
the plate drawn whole and masked to the lower deck, they put back the union's
outline, mitred corners included (the check measures it).

Every unit is one rectangle (the round-7 rule): a gold-edged well, an icon
column on its left that says who the frame is (skull, paw, crosshair, two
heads), then health over a thin power strip. Cells sit inside their deck's
floor, so no bar corner can poke past a diagonal (the round-6 rule).
"""
import os
import subprocess
import sys
from io import BytesIO

import numpy as np
from PIL import Image, ImageChops, ImageDraw
from shapely.geometry import Polygon
from shapely.ops import unary_union

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
OUT = os.path.join(HERE, "render")
BASE = os.path.join(HERE, "base-screen.png")
ADDON = os.path.join(ROOT, "WoW", "Interface", "AddOns", "Medalluin")
MEDIA = os.path.join(ADDON, "media", "overhead")
LUA = os.path.join(ADDON, "console", "overhead_art.lua")

GOLD, GOLD_D, INK, TEXT, DIM = "#c4a557", "#8a7034", "#121110", "#f2ead2", "#b3a88c"
NAVY_TOP, NAVY_BOTTOM = "#2f2713", "#483c1f"   # the plate's gradient, fixed to screen y 0..64

# ----------------------------------------------------------------- geometry (design pixels, 1080 high)
DECK = {"boss": 34, "unit": 30, "tray": 30}   # deck heights
CELL = {"boss": 168, "unit": 200} # a cell's least width; cells stretch to fill a grown deck
COL = {"boss": 20, "unit": 18}    # the icon column, inside the cell's edge
CELL_TOP, CELL_BOTTOM = 3, 7      # a cell's top below its deck's top; its bottom above the deck's floor
GAP = 4                           # between cells: the plate shows through
MARGIN = 4                        # floor beyond the outer cells, each side
LEDGE = 10                        # a lower deck's top corner, in from the floor above it
POWER = 4                         # the power strip under health
RIM = 3                           # the hairline's inset from the outline
OVERLAP = 4                       # rows a lower deck's pieces reach up over the deck above
ICON, ICON_GAP, ICON_SEP = 22, 2, 8   # command icons; ICON_SEP between stances and the pet bar
TRAY_TOP = 3                      # a command icon's top below the tray's top
EDGE = 2                          # pixels a piece reaches past its deck's outline, for the stroke
WING = 10                         # floor pixels a wing carries past the diagonal's foot
MID = 8                           # the middle column's texture width (it is stretched)

MAX_BOSS, MAX_UNIT = 5, 3
ROWS = [(0, 0), (1, 0), (3, 0), (0, 10), (3, 10), (6, 10)]   # (stances, pets) the check walks
TOLERANCE = 8                     # out of 255, for the check


def deck_width(kind, n):
    """A deck's top width for n cells: the cells fit its floor, which is
    2*height narrower than its top, plus MARGIN each side. Always even."""
    return n * CELL[kind] + (n - 1) * GAP + 2 * DECK[kind] + 2 * MARGIN


def row_width(stances, pets):
    """The command row's width: stances, ICON_SEP, the pet bar."""
    n = stances + pets
    if not n:
        return 0
    return n * (ICON + ICON_GAP) - ICON_GAP + (ICON_SEP if stances and pets else 0)


def stack(bosses, units, stances=0, pets=0):
    """The decks, top down, as (kind, n, top y, half-width); a tray's n is its
    row's width. Bottom up, a deck grows when the one under it would not be
    LEDGE narrower than its floor. The Lua does the same sums."""
    decks = []
    if bosses:
        decks.append(["boss", bosses, deck_width("boss", bosses)])
    if units:
        decks.append(["unit", units, deck_width("unit", units)])
    rw = row_width(stances, pets)
    if rw:
        decks.append(["tray", rw, rw + 2 * DECK["tray"] + 2 * MARGIN])
    for i in range(len(decks) - 2, -1, -1):
        need = decks[i + 1][2] + 2 * DECK[decks[i][0]] + 2 * LEDGE
        decks[i][2] = max(decks[i][2], need)
    out, y = [], 0
    for kind, n, w in decks:
        out.append((kind, n, y, w // 2))
        y += DECK[kind]
    return out


def cell_width(kind, n, half):
    """Cells share the floor less its margins; the total is kept even, so the
    row stays centred on whole pixels. Never under CELL: a deck is at least
    deck_width wide."""
    floor = 2 * half - 2 * DECK[kind] - 2 * MARGIN
    cw = (floor - (n - 1) * GAP) // n
    if (n * cw + (n - 1) * GAP) % 2:
        cw -= 1
    return cw


def deck_poly(cx, kind, y, half):
    h = DECK[kind]
    top = y - 10 if y == 0 else y     # the top deck runs past the screen's edge: no rim up there
    return Polygon([(cx - half - (y - top), top), (cx + half + (y - top), top),
                    (cx + half - h, y + h), (cx - half + h, y + h)])


def cells(cx, kind, n, y, half):
    """Cell rectangles (left, top, right, bottom), centred in the deck's floor."""
    cw = cell_width(kind, n, half)
    total = n * cw + (n - 1) * GAP
    left = cx - total // 2
    return [(left + i * (cw + GAP), y + CELL_TOP,
             left + i * (cw + GAP) + cw, y + DECK[kind] - CELL_BOTTOM) for i in range(n)]


def pts(p):
    return " ".join(f"{x:.3f},{y:.3f}" for x, y in p)


def outline(geom):
    return list(geom.exterior.coords)


# ----------------------------------------------------------------- glyphs and icons
ICON_HUES = [("#e0b25a", "#5a3a10"), ("#d0603a", "#3a0e06"), ("#7f9ce0", "#16224a"),
             ("#a0c060", "#203a10"), ("#c06a8a", "#3a1020"), ("#8a7ad0", "#1e1640")]


def glyph(kind, cx, cy, size):
    """Gold glyphs on a 20-unit grid, centred on (cx, cy)."""
    s = size / 20
    f = 'fill="url(#gold)" stroke="#2a1e08" stroke-width="0.7"'
    t = f'transform="translate({cx - size / 2:.3f},{cy - size / 2:.3f}) scale({s:.4f})"'
    if kind == "skull":       # boss
        return (f'<path {t} fill-rule="evenodd" {f} d="M10,1.5 C4.5,1.5 2,5.2 2,9.2 C2,12 3.4,13.6 5,14.4 '
                f'L5,17.8 L7.4,17.8 L7.4,16 L8.8,16 L8.8,17.8 L11.2,17.8 L11.2,16 L12.6,16 L12.6,17.8 L15,17.8 '
                f'L15,14.4 C16.6,13.6 18,12 18,9.2 C18,5.2 15.5,1.5 10,1.5 Z '
                f'M4.6,9.4 a2.6,2.4 0 1,0 5.2,0 a2.6,2.4 0 1,0 -5.2,0 Z '
                f'M10.2,9.4 a2.6,2.4 0 1,0 5.2,0 a2.6,2.4 0 1,0 -5.2,0 Z '
                f'M10,11.6 L8.9,13.6 L11.1,13.6 Z"/>')
    if kind == "paw":         # pet
        return (f'<g {t} {f}>'
                f'<path d="M10,9 C6,9 3.2,13 3.6,15.6 C4,18 6.6,18.4 10,17.2 C13.4,18.4 16,18 16.4,15.6 '
                f'C16.8,13 14,9 10,9 Z"/>'
                f'<ellipse cx="3.4" cy="8.2" rx="1.9" ry="2.5" transform="rotate(-20 3.4 8.2)"/>'
                f'<ellipse cx="7.3" cy="4.4" rx="2" ry="2.7" transform="rotate(-8 7.3 4.4)"/>'
                f'<ellipse cx="12.7" cy="4.4" rx="2" ry="2.7" transform="rotate(8 12.7 4.4)"/>'
                f'<ellipse cx="16.6" cy="8.2" rx="1.9" ry="2.5" transform="rotate(20 16.6 8.2)"/></g>')
    if kind == "target":      # focus: a crosshair
        return (f'<path {t} fill-rule="evenodd" {f} d="M10,2 a8,8 0 1,0 0.01,0 Z M10,4.6 a5.4,5.4 0 1,1 -0.01,0 Z '
                f'M9,0 L11,0 L11,6.4 L9,6.4 Z M9,13.6 L11,13.6 L11,20 L9,20 Z '
                f'M0,9 L6.4,9 L6.4,11 L0,11 Z M13.6,9 L20,9 L20,11 L13.6,11 Z '
                f'M10,8.6 a1.4,1.4 0 1,0 0.01,0 Z"/>')
    if kind == "friend":      # target of target: two heads, the near one larger
        return (f'<path {t} {f} d="M12.6,5.4 a2.7,2.7 0 1,0 5.4,0 a2.7,2.7 0 1,0 -5.4,0 Z '
                f'M13.2,9.6 C16.6,9 19.6,11 19.6,15 L15.4,15 C15.4,12.6 14.6,10.8 13.2,9.6 Z '
                f'M3,6.8 a3.6,3.6 0 1,0 7.2,0 a3.6,3.6 0 1,0 -7.2,0 Z '
                f'M0.6,18 C0.6,11.4 12.6,11.4 12.6,18 Z"/>')
    raise ValueError(kind)


# unit -> (glyph, cell kind)
WHO = {"boss": ("skull", "boss"), "pet": ("paw", "unit"), "focus": ("target", "unit"),
       "targettarget": ("friend", "unit")}


def chip_size(kind):
    """The icon column's inside: COL wide, the cell less its 1px edge top and bottom."""
    return COL[kind], DECK[kind] - CELL_TOP - CELL_BOTTOM - 2


def chip_svg(who, x, y):
    g, kind = WHO[who]
    w, h = chip_size(kind)
    return (f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="url(#chip)"/>'
            + glyph(g, x + w / 2, y + h / 2, min(w, h) - 5))


# ----------------------------------------------------------------- SVG
def defs():
    return ('<defs>'
            f'<linearGradient id="navy" gradientUnits="userSpaceOnUse" x1="0" y1="0" x2="0" y2="64">'
            f'<stop offset="0" stop-color="{NAVY_TOP}"/><stop offset="1" stop-color="{NAVY_BOTTOM}"/>'
            '</linearGradient>'
            '<linearGradient id="chip" x1="0" y1="0" x2="0" y2="1">'
            '<stop offset="0" stop-color="#3b3017"/><stop offset="1" stop-color="#251e0e"/></linearGradient>'
            '<linearGradient id="gold" x1="0" y1="0" x2="0" y2="1">'
            '<stop offset="0" stop-color="#f0d488"/><stop offset="1" stop-color="#a8823a"/></linearGradient>'
            + "".join(f'<linearGradient id="ic{i}" x1="0" y1="0" x2="1" y2="1">'
                      f'<stop offset="0" stop-color="{a}"/><stop offset="1" stop-color="{b}"/></linearGradient>'
                      for i, (a, b) in enumerate(ICON_HUES))
            + '</defs>')


def plate_svg(cx, decks):
    if not decks:
        return ""
    plate = unary_union([deck_poly(cx, k, y, h) for k, _, y, h in decks])
    inner = plate.buffer(-RIM, join_style="mitre")
    return (f'<polygon points="{pts(outline(plate))}" fill="url(#navy)" stroke="{GOLD_D}" stroke-width="1.6"/>'
            f'<polygon points="{pts(outline(inner))}" fill="none" stroke="{GOLD}" stroke-width="0.9" '
            f'opacity="0.8"/>')


def svg(width, height, body, viewbox=None, scale=1):
    vb = f' viewBox="{viewbox}"' if viewbox else ""
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{width * scale}" height="{height * scale}"{vb}>'
            f'{defs()}{body}</svg>')


def rsvg(text):
    p = subprocess.run(["rsvg-convert"], input=text.encode(), check=True, capture_output=True)
    return Image.open(BytesIO(p.stdout)).convert("RGBA")


# ----------------------------------------------------------------- the mockup's units
BOSSES = [("High Warlord Naj'entus", 0.85, "#b8401a", "#c03028"),
          ("Supremus", 0.92, "#b8401a", "#c03028"),
          ("Shade of Akama", 0.40, "#b8401a", "#3a64b8"),
          ("Teron Gorefiend", 0.66, "#b8401a", "#3a64b8"),
          ("Gurtogg Bloodboil", 0.20, "#b8401a", "#c03028")]
UNITS = {"pet": ("Wolf", 1.00, "#3f9a3a", "#c8a028"),
         "focus": ("Lady Sacrolash", 0.60, "#b8401a", "#3a64b8"),
         "targettarget": ("Main Tank", 0.88, "#9e7c56", "#c03028")}


def text(x, y, s, anchor="start", size=10, fill=TEXT):
    s = s.replace("&", "&amp;").replace("'", "&#39;")
    return (f'<text x="{x:.2f}" y="{y:.2f}" font-family="Marcellus SC" font-size="{size}" fill="{fill}" '
            f'text-anchor="{anchor}" stroke="#000" stroke-width="2" paint-order="stroke">{s}</text>')


def cell_svg(who, rect, data):
    """The cell as the Lua builds it: 1px gold edge, the chip, a 1px gold
    divider, then health over one ink row over power, in the window."""
    l, t, r, b = rect
    kind = WHO[who][1]
    name, frac, hp, pw = data
    bx, br = l + 1 + COL[kind] + 1, r - 1
    ht, hb = t + 1, b - 1 - POWER - 1
    w = br - bx
    cid = f"n{l}_{t}"
    return "".join([
        f'<rect x="{l}" y="{t}" width="{r - l}" height="{b - t}" fill="{GOLD_D}"/>',
        f'<rect x="{l + 1}" y="{t + 1}" width="{r - l - 2}" height="{b - t - 2}" fill="{INK}"/>',
        chip_svg(who, l + 1, t + 1),
        f'<rect x="{bx:.2f}" y="{ht}" width="{w * frac:.2f}" height="{hb - ht}" fill="{hp}"/>',
        f'<rect x="{bx:.2f}" y="{ht}" width="{w * frac:.2f}" height="{(hb - ht) / 2:.2f}" fill="#fff" opacity="0.08"/>',
        f'<rect x="{bx}" y="{b - 1 - POWER}" width="{w * 0.7:.2f}" height="{POWER}" fill="{pw}"/>',
        f'<clipPath id="{cid}"><rect x="{bx}" y="{t}" width="{w - 34}" height="{b - t}"/></clipPath>',
        f'<g clip-path="url(#{cid})">{text(bx + 4, (ht + hb) / 2 + 3.6, name)}</g>',
        text(br - 4, (ht + hb) / 2 + 3.6, f"{round(frac * 100)}%", "end", fill=DIM),
    ])


def bare_icon(x, y, i, active=False):
    a, _ = ICON_HUES[i % len(ICON_HUES)]
    out = [f'<rect x="{x}" y="{y}" width="{ICON}" height="{ICON}" fill="#000"/>',
           f'<rect x="{x + 1}" y="{y + 1}" width="{ICON - 2}" height="{ICON - 2}" '
           f'fill="url(#ic{i % len(ICON_HUES)})"/>',
           f'<path d="M{x + 5},{y + ICON - 6} L{x + ICON / 2},{y + 6} L{x + ICON - 5},{y + ICON - 6}" '
           f'fill="none" stroke="{a}" stroke-width="2" opacity="0.9"/>']
    if active:     # the current stance: Blizzard's checked state, our gold overlay
        out.append(f'<rect x="{x + 1}" y="{y + 1}" width="{ICON - 2}" height="{ICON - 2}" fill="{GOLD}" '
                   f'opacity="0.35"/>')
    return "".join(out)


def command_row(cx, y, stances, pets):
    """One centred row inside the tray: stances, ICON_SEP, the pet bar."""
    step = ICON + ICON_GAP
    sep = ICON_SEP if stances and pets else 0
    x, top = cx - row_width(stances, pets) // 2, y + TRAY_TOP
    out = []
    for i in range(stances):
        out.append(gold_edge(x, top) + bare_icon(x, top, i, active=(i == 0)))
        x += step
    x += sep
    for i in range(pets):
        out.append(gold_edge(x, top) + bare_icon(x, top, i + 3))
        x += step
    return "".join(out)


def gold_edge(x, y):
    """The icon's 1px gold edge, outside its 1px black one."""
    return f'<rect x="{x - 1}" y="{y - 1}" width="{ICON + 2}" height="{ICON + 2}" fill="url(#gold)"/>'


def scene(cx, bosses, units, stances=0, pets=0):
    decks = stack(bosses, len(units), stances, pets)
    body = [plate_svg(cx, decks)]
    for kind, n, y, half in decks:
        if kind == "tray":
            body.append(command_row(cx, y, stances, pets))
            continue
        who = ["boss"] * n if kind == "boss" else units
        for i, (rect, w) in enumerate(zip(cells(cx, kind, n, y, half), who)):
            body.append(cell_svg(w, rect, BOSSES[i] if w == "boss" else UNITS[w]))
    return "".join(body)


# ----------------------------------------------------------------- pieces
CW, CH = 1400, 100           # the canvas pieces are cut from, and the check's
CX = CW // 2


def placements():
    """Every place a deck can hang: name -> (kind, y, the kinds above it)."""
    out = {}
    for b in (False, True):
        for u in (False, True):
            for t in (False, True):
                kinds = [k for k, on in (("boss", b), ("unit", u), ("tray", t)) if on]
                y = 0
                for i, k in enumerate(kinds):
                    out[f"{k}-{y}"] = (k, y, kinds[:i])
                    y += DECK[k]
    return out


def piece_specs():
    """name -> (the decks the source plate holds, the wing's crop box, the
    middle column's crop box, a mask polygon or None). Boxes are (left, top,
    right, bottom) on the source canvas; the last deck is the piece's own.
    A lower deck is cut from the plate with the decks above it, masked to
    itself plus the OVERLAP rows above it, so it repaints the meeting."""
    specs = {}
    for name, (kind, y, above) in placements().items():
        h, half = DECK[kind], 400
        halves = [half]
        for k in reversed(above):          # each deck above wider than its floor needs
            halves.insert(0, halves[0] + DECK[k] + LEDGE + 60)
        decks, yy = [], 0
        for k, hf in zip(above + [kind], halves):
            decks.append((k, 1, yy, hf))
            yy += DECK[k]
        left = CX - half
        if not above:
            specs[name] = (decks, (left - EDGE, 0, left + h + WING, h + EDGE),
                           (CX - MID // 2, 0, CX + MID // 2, h + EDGE), None)
            continue
        reach = OVERLAP + EDGE
        mask = Polygon([(left - reach, y - OVERLAP), (CX + half + reach, y - OVERLAP),
                        (CX + half + reach - (h + EDGE + OVERLAP), y + h + EDGE),
                        (CX - half - reach + (h + EDGE + OVERLAP), y + h + EDGE)])
        specs[name] = (decks, (left - reach, y - OVERLAP, left + h + WING, y + h + EDGE),
                       (CX - MID // 2, y - OVERLAP, CX + MID // 2, y + h + EDGE), mask)
    return specs


def masked(img, poly):
    """img with everything outside poly cleared."""
    m = Image.new("L", img.size, 0)
    ImageDraw.Draw(m).polygon([(x, y) for x, y in outline(poly)], fill=255)
    out = img.copy()
    out.putalpha(ImageChops.multiply(img.getchannel("A"), m))
    return out


def over_solve(whole, under):
    """The layer that, composited over `under`, gives `whole`: premultiplied,
    L = T - (1 - aL) U with aL = (aT - aU) / (1 - aU). Where `under` is
    already opaque, the layer is the whole plate itself, opaque. A pixel the
    layer cannot reach (the whole is clearer than what lies under it) is
    clamped, and the check reports it."""
    t = np.asarray(whole, dtype=np.float64) / 255
    u = np.asarray(under, dtype=np.float64) / 255
    tp, up = t[..., :3] * t[..., 3:], u[..., :3] * u[..., 3:]
    ta, ua = t[..., 3:], u[..., 3:]
    opaque = ua >= 1 - 1e-6
    la = np.where(opaque, 1.0, (ta - ua) / np.maximum(1 - ua, 1e-6))
    la = np.where(ta < 1e-6, 0.0, la)
    la = np.clip(la, 0, 1)
    lp = np.where(opaque, tp, tp - (1 - la) * up)
    lp = np.clip(lp, 0, la)
    rgb = np.where(la > 1e-6, lp / np.maximum(la, 1e-6), 0)
    out = np.concatenate([rgb, la], axis=2)
    return Image.fromarray(np.round(out * 255).astype(np.uint8), "RGBA")


def cut_pieces():
    """name -> {"wing", "mid", "dx", "dy"}: (dx, dy) take the deck's top-left
    corner (its outline at its own top) to the wing's top-left."""
    out = {}
    for name, (decks, wing_box, mid_box, mask) in piece_specs().items():
        src = rsvg(svg(CW, CH, plate_svg(CX, decks)))
        if mask is not None:
            # what the decks above already paint is subtracted, not painted twice
            src = masked(over_solve(src, rsvg(svg(CW, CH, plate_svg(CX, decks[:-1])))), mask)
        _, _, top, half = decks[-1]
        out[name] = {"wing": src.crop(wing_box), "mid": src.crop(mid_box),
                     "dx": wing_box[0] - (CX - half), "dy": wing_box[1] - top}
    return out


def assemble(pieces, bosses, units, width, stances=0, pets=0):
    """The plate as the Lua lays it: per deck, top deck first, the wing at the
    left corner, the wing mirrored at the right, the column stretched between."""
    canvas = Image.new("RGBA", (width, CH), (0, 0, 0, 0))
    cx = width // 2
    for kind, _, y, half in stack(bosses, units, stances, pets):
        p = pieces[f"{kind}-{y}"]
        wing, mid = p["wing"], p["mid"]
        x, top = cx - half + p["dx"], y + p["dy"]
        right = cx + half - p["dx"] - wing.width
        layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
        layer.paste(wing, (x, top))
        layer.paste(wing.transpose(Image.FLIP_LEFT_RIGHT), (right, top))
        midw = right - (x + wing.width)
        if midw > 0:
            layer.paste(mid.resize((midw, mid.height), Image.NEAREST), (x + wing.width, top))
        canvas = Image.alpha_composite(canvas, layer)
    return canvas


def premul(img):
    """Colour times alpha, as integers: a nearly clear pixel's colour is noise, not art."""
    a = np.asarray(img, dtype=np.int32)
    out = a.copy()
    out[..., :3] = a[..., :3] * a[..., 3:4] // 255
    return out


def worst(a, b, tol):
    """The largest channel difference, and the box of pixels past tol."""
    d = np.abs(a - b).max(axis=2)
    ys, xs = np.nonzero(d > tol)
    where = (int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())) if len(xs) else None
    return int(d.max()), where


def check(pieces=None):
    """Every boss/unit count and command row: the plate assembled from pieces against the plate
    drawn whole, and the whole plate against its mirror. The middle column
    must be flat, or stretching it would smear."""
    pieces = pieces or cut_pieces()
    bad = 0
    for name, p in pieces.items():
        mid = p["mid"]
        cols = {mid.crop((x, 0, x + 1, mid.height)).tobytes() for x in range(mid.width)}
        if len(cols) != 1:
            print(f"FAIL {name}: the middle column is not flat ({len(cols)} different columns)")
            bad += 1
    top = 0
    for b in range(MAX_BOSS + 1):
        for u in range(MAX_UNIT + 1):
            for st, pe in ROWS:
                if not b and not u and not st and not pe:
                    continue
                what = f"{b} bosses, {u} units, {st}+{pe} icons"
                whole = premul(rsvg(svg(CW, CH, plate_svg(CW // 2, stack(b, u, st, pe)))))
                d, where = worst(whole, premul(assemble(pieces, b, u, CW, st, pe)), TOLERANCE)
                top = max(top, d)
                if where:
                    print(f"FAIL {what}: pieces differ from the whole plate by {d} at {where}")
                    bad += 1
                m, where = worst(whole, whole[:, ::-1], TOLERANCE)
                if where:
                    print(f"FAIL {what}: the plate is not mirrored ({m} at {where})")
                    bad += 1
    print(f"overhead check: worst piece/whole difference {top} (tolerance {TOLERANCE}), {bad} failures")
    return bad == 0


# ----------------------------------------------------------------- export
def to_tga(img, path):
    """32-bit uncompressed TGA via magick, as export.py writes them."""
    tmp = path + ".png"
    img.save(tmp)
    subprocess.run(["magick", tmp, "-define", "tga:compression=none",
                    "-depth", "8", "-type", "TrueColorAlpha", path], check=True)
    os.remove(tmp)


def pow2(n):
    p = 1
    while p < n:
        p *= 2
    return p


def padded(img):
    """Top-left in a power-of-two canvas, as WoW wants; the Lua's texcoords crop it."""
    c = Image.new("RGBA", (pow2(img.width), pow2(img.height)), (0, 0, 0, 0))
    c.paste(img, (0, 0))
    return c


def rgb(hexa):
    return ", ".join(f"{int(hexa[i:i + 2], 16) / 255:.3f}" for i in (1, 3, 5))


def export():
    pieces = cut_pieces()
    if not check(pieces):
        sys.exit("overhead: the pieces do not rebuild the plate; nothing written")
    os.makedirs(MEDIA, exist_ok=True)
    rows = []
    for name, p in pieces.items():
        for part in ("wing", "mid"):
            img = p[part]
            tex = padded(img)
            to_tga(tex, os.path.join(MEDIA, f"{name}-{part}.tga"))
            rows.append(f'    ["{name}-{part}"] = {{ w = {img.width}, h = {img.height}, '
                        f'tw = {tex.width}, th = {tex.height}, dx = {p["dx"]}, dy = {p["dy"]} }},')
    chips = []
    for who, (g, kind) in WHO.items():
        w, h = chip_size(kind)
        tex = padded(rsvg(svg(w, h, chip_svg(who, 0, 0))))
        to_tga(tex, os.path.join(MEDIA, f"icon-{g}.tga"))
        chips.append(f'    {who} = {{ file = "icon-{g}", w = {w}, h = {h}, tw = {tex.width}, th = {tex.height} }},')
    nl = "\n"
    lua = f"""-- GENERATED by art/console/gen_overhead.py export. Do not edit: change the
-- generator and run it again. The overhead's geometry in design pixels (a
-- 1080-high screen) and its art pieces in media/overhead/.
local _, ns = ...

ns.overheadArt = {{
    deck = {{ boss = {DECK["boss"]}, unit = {DECK["unit"]}, tray = {DECK["tray"]} }},
    cell = {{ boss = {CELL["boss"]}, unit = {CELL["unit"]} }},
    col = {{ boss = {COL["boss"]}, unit = {COL["unit"]} }},
    cellTop = {CELL_TOP}, cellBottom = {CELL_BOTTOM},
    gap = {GAP}, margin = {MARGIN}, ledge = {LEDGE}, power = {POWER},
    icon = {ICON}, iconGap = {ICON_GAP}, iconSep = {ICON_SEP}, trayTop = {TRAY_TOP},
    edge = {{ {rgb(GOLD_D)} }},
}}

-- each piece, named for its deck's kind and the y it hangs at: the art (w x h)
-- at the top-left of a tw x th texture, and (dx, dy) from its deck's top-left
-- corner to the art's top-left
ns.overheadPieces = {{
{nl.join(rows)}
}}

-- each unit's icon column, chip and glyph, the same way
ns.overheadChips = {{
{nl.join(chips)}
}}
"""
    with open(LUA, "w") as f:
        f.write(lua)
    print("wrote", LUA, "and", MEDIA)


# ----------------------------------------------------------------- mockup
W, H = 1000, 110
STATES = [
    ("Hunter, solo: pet + pet bar", 0, ["pet"], 0, 10),
    ("Hunter, 7 pet slots shown", 0, ["pet"], 0, 7),
    ("Warrior, a target: ToT + stances", 0, ["targettarget"], 3, 0),
    ("Raid boss, everything", 2, ["pet", "focus", "targettarget"], 3, 10),
    ("One boss, pet and focus", 1, ["pet", "focus"], 0, 10),
    ("Five bosses, no companions", 5, [], 6, 0),
    ("Warrior, no target: the tray alone", 0, [], 3, 0),
]


def mockup():
    from PIL import ImageFont
    os.makedirs(OUT, exist_ok=True)
    tiles = []
    for label, bosses, units, stances, pets in STATES:
        art = rsvg(svg(W, H, scene(W // 2, bosses, units, stances, pets), f"0 0 {W} {H}", 2))
        x0 = 960 - W // 2
        base = Image.open(BASE).convert("RGBA").crop((x0, 0, x0 + W, H)).resize((W * 2, H * 2))
        tiles.append((label, Image.alpha_composite(base, art)))
    lab = 30
    sheet = Image.new("RGB", (W * 2, len(tiles) * (H * 2 + lab)), "#0b0c10")
    font = ImageFont.truetype("/usr/local/share/fonts/wow-art/MarcellusSC-Regular.ttf", 20)
    d = ImageDraw.Draw(sheet)
    for i, (label, img) in enumerate(tiles):
        y = i * (H * 2 + lab)
        d.text((12, y + 4), f"C  ·  {label}", fill=TEXT, font=font)
        sheet.paste(img.convert("RGB"), (0, y + lab))
    path = os.path.join(OUT, "overhead-C.png")
    sheet.save(path)
    print(path)


# ----------------------------------------------------------------- the tray's frame (2026-11-01, asked)
# "putting a golden frame over pet/stance actionbars?" Three readings, drawn; the user chose A,
# which command_row now draws and console/overhead.lua builds (Frame):
#   A  each icon edged in gold, as the unit cells are (1px gold, 1px black, the icon)
#   B  the row in one gold-edged ink well, a cell's frame, a gold hairline between stances and pets
#   C  both
FRAME_PAD = 2                     # B and C: the well's inside, around the icons


def framed_row(cx, y, stances, pets, variant):
    step = ICON + ICON_GAP
    sep = ICON_SEP if stances and pets else 0
    rw = row_width(stances, pets)
    x0, top = cx - rw // 2, y + TRAY_TOP
    out = []
    if variant in ("B", "C"):
        p = FRAME_PAD
        out.append(f'<rect x="{x0 - p - 1}" y="{top - p - 1}" width="{rw + 2 * p + 2}" height="{ICON + 2 * p + 2}" '
                   f'fill="{GOLD_D}"/>')
        out.append(f'<rect x="{x0 - p}" y="{top - p}" width="{rw + 2 * p}" height="{ICON + 2 * p}" fill="{INK}"/>')
        if sep:
            hx = x0 + stances * step - ICON_GAP + sep / 2
            out.append(f'<rect x="{hx - 0.5}" y="{top - p}" width="1" height="{ICON + 2 * p}" fill="{GOLD_D}"/>')
    x = x0
    for i in range(stances + pets):
        if i == stances:
            x += sep
        icon = bare_icon(x, top, i if i < stances else i + 3, active=(i == 0 and stances > 0))
        if variant in ("A", "C"):
            out.append(f'<rect x="{x - 1}" y="{top - 1}" width="{ICON + 2}" height="{ICON + 2}" fill="url(#gold)"/>')
        out.append(icon)
        x += step
    return "".join(out)


def frames():
    from PIL import ImageFont
    os.makedirs(OUT, exist_ok=True)
    font = ImageFont.truetype("/usr/local/share/fonts/wow-art/MarcellusSC-Regular.ttf", 20)
    rows = [(0, 7), (3, 6)]
    w, h, k = 420, 64, 3
    tiles = []
    for variant, label in (("0", "before: bare icons"), ("A", "A  each icon edged in gold"),
                           ("B", "B  the row in one gold-edged well"), ("C", "C  both")):
        for stances, pets in rows:
            decks = stack(0, 1, stances, pets)
            body = [plate_svg(w // 2, decks)]
            for kind, n, y, half in decks:
                if kind == "tray":
                    body.append(framed_row(w // 2, y, stances, pets, variant))
                else:
                    for rect in cells(w // 2, kind, n, y, half):
                        body.append(cell_svg("pet", rect, UNITS["pet"]))
            art = rsvg(svg(w, h, "".join(body), f"0 0 {w} {h}", k))
            x0 = 960 - w // 2
            base = Image.open(BASE).convert("RGBA").crop((x0, 0, x0 + w, h)).resize((w * k, h * k))
            tiles.append((f"{label}   ({stances} stances, {pets} pet)", Image.alpha_composite(base, art)))
    lab = 30
    sheet = Image.new("RGB", (w * k * 2 + 10, 4 * (h * k + lab)), "#0b0c10")
    d = ImageDraw.Draw(sheet)
    for i, (label, img) in enumerate(tiles):
        col, row = i % 2, i // 2
        x, y = col * (w * k + 10), row * (h * k + lab)
        d.text((x + 12, y + 4), label, fill=TEXT, font=font)
        sheet.paste(img.convert("RGB"), (x, y + lab))
    path = os.path.join(OUT, "overhead-frames.png")
    sheet.save(path)
    print(path, sheet.size)


if __name__ == "__main__":
    if "export" in sys.argv[1:]:
        export()
    elif "frames" in sys.argv[1:]:
        frames()
    elif "--check" in sys.argv[1:]:
        sys.exit(0 if check() else 1)
    else:
        mockup()
