#!/usr/bin/env python3
"""The corner strips, mocked up over the console and its action bar: the pieces the
console left without a home when it retired Blizzard's main bar.

  left   the micro menu: a character medallion (the player's portrait) and a
         row of gold glyph buttons, one per Blizzard micro button
  right  the status strip: a backpack medallion, then Bags, Durability and
         the clock (the bag drawer and its arrow were removed 2026-11-01: the
         user is moving bags into a new inventory UI)

After the user's references (one for each strip), drawn in the console's
own styling and mirrored about the centre line, as the suite requires. The
references are not mirrored (portrait outer, backpack inner), so two mirrored readings:

  A  both medallions at the INNER ends, flanking the console
  B  both medallions at the OUTER corners

    python3 art/strips/gen_strips.py          -> render/strips.png
    python3 art/strips/gen_strips.py layer3   -> assets/layer3.png, assets/strips/*.png
    python3 art/strips/gen_strips.py glyphs   -> assets/strips/<glyph>.png alone

The user chose B. assets/layer3.png is B's two strips in the console's
asset format (a 1920x1080 screen, the medallion wells cut out), and
assets/strips/ holds the parts code places itself: one 32x32 PNG per glyph,
and a round mask. art/console/export.py turns both into
media/.

Distances are 1080p screen pixels. The base is the console's combat render;
the action bar is the client's own art, so it is not in the mockup.
"""
import os
import subprocess

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
OUT = os.path.join(HERE, "render")
BASE = os.path.join(ROOT, "art", "console", "base-screen.png")

W, H, CX = 1920, 1080, 960
GOLD, GOLD_D, INK, TEXT = "#c4a557", "#8a7034", "#121110", "#f2ead2"
STRIP_H = 30                  # the strip, flush with the screen's bottom edge
LENGTH = 460                  # screen edge to the strip's top inner corner
MED_R = 25                    # medallion radius (ring included)
GLYPH, PITCH = 20, 30         # glyph size and button pitch: 13 glyphs fit the strip
GLYPH_DROP = 2                # glyph centre below the strip's middle: whole pixels

# Forever's micro buttons as it shows them, in its order, after the portrait
# (Help is hidden there). Retail shows eleven, Classic Era eight.
MICRO = ["profession", "spellbook", "talents", "legacy", "quests", "housing", "guild", "lfg",
         "collections", "journal", "store", "menu"]


# ------------------------------------------------------------------ glyphs
# Original glyphs on a 20x20 box at (x, y), filled with the gold gradient.
def glyph(kind, x, y):
    s = GLYPH / 20
    f = 'fill="url(#gold)" stroke="#2a1e08" stroke-width="0.6"'

    def P(d, rule="nonzero"):
        return f'<path transform="translate({x},{y}) scale({s})" d="{d}" fill-rule="{rule}" {f}/>'
    if kind == "spellbook":     # an open book
        return P("M10,5 C7,3 4,3 1,4 L1,17 C4,16 7,16 10,18 C13,16 16,16 19,17 L19,4 C16,3 13,3 10,5 Z"
                 "M10,6 L10,16.5 M3,6.5 L8,7.2 M3,9.5 L8,10.2 M12,7.2 L17,6.5 M12,10.2 L17,9.5")
    if kind == "talents":       # three branches from one stem
        return P("M9,19 L9,11 L4,6 L5.5,4.5 L9.6,8.6 L9.6,2 L10.4,2 L10.4,8.6 L14.5,4.5 L16,6 L11,11 L11,19 Z"
                 "M2,4 a2.2,2.2 0 1,0 4.4,0 a2.2,2.2 0 1,0 -4.4,0 Z"
                 "M7.8,2 a2.2,2.2 0 1,0 4.4,0 a2.2,2.2 0 1,0 -4.4,0 Z"
                 "M13.6,4 a2.2,2.2 0 1,0 4.4,0 a2.2,2.2 0 1,0 -4.4,0 Z")
    if kind == "quests":        # the quest mark
        return P("M8,2 L12,2 L11.2,13 L8.8,13 Z M8,16.5 a2,2 0 1,0 4,0 a2,2 0 1,0 -4,0 Z")
    if kind == "social":        # two heads
        return P("M4,7 a3,3 0 1,0 6,0 a3,3 0 1,0 -6,0 Z M1,18 C1,12 13,12 13,18 Z"
                 "M11,5 a3,3 0 1,0 6,0 a3,3 0 1,0 -6,0 Z M12.5,11 C16,10 19.5,12 19.5,16 L14.5,16 C14.5,14 13.8,12 12.5,11 Z")
    if kind == "guild":         # a shield
        return P("M10,1.5 L18,4 C18,11 15,16 10,18.5 C5,16 2,11 2,4 Z M10,4.5 L10,16 M4.5,8 L15.5,8")
    if kind == "lfg":           # a spyglass eye
        return P("M1,10 C5,3 15,3 19,10 C15,17 5,17 1,10 Z M6.5,10 a3.5,3.5 0 1,0 7,0 a3.5,3.5 0 1,0 -7,0 Z"
                 "M8.6,10 a1.4,1.4 0 1,0 2.8,0 a1.4,1.4 0 1,0 -2.8,0 Z")
    if kind == "map":           # a folded map
        return P("M1,4 L7,2 L13,4 L19,2 L19,16 L13,18 L7,16 L1,18 Z M7,2.5 L7,15.5 M13,4.5 L13,17.5")
    if kind == "menu":          # a cog
        teeth = "".join(f'<rect x="8.6" y="0.5" width="2.8" height="5" transform="rotate({a} 10 10)"/>'
                        for a in range(0, 360, 45))
        return (f'<g transform="translate({x},{y}) scale({s})" {f}>{teeth}'
                f'<circle cx="10" cy="10" r="6.5"/><circle cx="10" cy="10" r="2.6" fill="#252a37"/></g>')
    if kind == "help":          # a question mark
        return P("M5,6.5 C5,1.5 15,1.5 15,6.5 C15,10 11.2,10 11.2,13 L8.8,13 C8.8,9 12.4,8.6 12.4,6.5 "
                 "C12.4,4.2 7.6,4.2 7.6,6.5 Z M8,16.5 a2,2 0 1,0 4,0 a2,2 0 1,0 -4,0 Z")
    if kind == "profession":    # a hammer
        return P("M2,2.5 L13,2.5 L15.5,4.75 L13,7 L9.3,7 L9.3,18.5 L6.7,18.5 L6.7,7 L2,7 Z")
    if kind == "achievement":   # a star
        import math
        p = []
        for i in range(10):
            r = 9 if i % 2 == 0 else 3.8
            a = math.radians(-90 + 36 * i)
            p.append(f"{10 + r * math.cos(a):.2f},{10.8 + r * math.sin(a):.2f}")
        return P("M" + " L".join(p) + " Z")
    if kind == "housing":       # a house with its door
        return P("M10,2 L19,10 L16.5,10 L16.5,18 L3.5,18 L3.5,10 L1,10 Z M8,18 L8,12 L12,12 L12,18 Z", "evenodd")
    if kind == "collections":   # a horseshoe
        return P("M3,2 L7,2 L7,10 C7,14.5 13,14.5 13,10 L13,2 L17,2 L17,10 C17,19.5 3,19.5 3,10 Z"
                 "M3,5.5 L7,5.5 M13,5.5 L17,5.5")
    if kind == "journal":       # a scroll
        return P("M4,3 L16,3 C18.2,3 18.2,6.5 16,6.5 L16,17 L4,17 C1.8,17 1.8,13.5 4,13.5 Z"
                 "M6.5,8 L13.5,8 M6.5,10.8 L13.5,10.8")
    if kind == "store":         # a coin purse
        return P("M7,2 L13,2 L11.5,5 C17,7 19,12 17,16 C15.5,18.6 4.5,18.6 3,16 C1,12 3,7 8.5,5 Z M7.5,5.2 L12.5,5.2")
    if kind == "legacy":        # an hourglass
        return P("M3,2 L17,2 L17,4 L15,4 C15,8 11,9 11,10 C11,11 15,12 15,16 L17,16 L17,18 L3,18 L3,16 L5,16 "
                 "C5,12 9,11 9,10 C9,9 5,8 5,4 L3,4 Z")
    # the quest tracker's footer (quests/tracker.lua)
    if kind == "questlog":      # a closed book, the quest mark cut from its cover
        return P("M3,3.4 C3,2.6 3.7,2 4.5,2 L17,2 L17,15.5 L5,15.5 C3.7,15.5 3.7,17.5 5,17.5 L17,17.5 L17,19 "
                 "L4.5,19 C3.7,19 3,18.4 3,17.5 Z"
                 "M9.4,4.2 L11.6,4.2 L11.1,10.4 L9.9,10.4 Z M9.3,12.6 a1.2,1.2 0 1,0 2.4,0 a1.2,1.2 0 1,0 -2.4,0 Z",
                 "evenodd")
    if kind == "sort":          # three bars, the longest first
        return P("M2,3 L18,3 L18,6 L2,6 Z M2,8.5 L13,8.5 L13,11.5 L2,11.5 Z M2,14 L8,14 L8,17 L2,17 Z")
    if kind == "view-minimal":  # a box of its own, in the screen
        return P("M1,2 L19,2 L19,18 L1,18 Z M2.6,3.6 L17.4,3.6 L17.4,16.4 L2.6,16.4 Z M4.2,5.2 L11,5.2 L11,10.4 "
                 "L4.2,10.4 Z", "evenodd")
    if kind == "view-full":     # a column down the screen's left
        return P("M1,2 L19,2 L19,18 L1,18 Z M2.6,3.6 L17.4,3.6 L17.4,16.4 L2.6,16.4 Z M4.2,5.2 L9,5.2 L9,14.8 "
                 "L4.2,14.8 Z", "evenodd")
    # the chat box's head (strips/chat.lua)
    if kind == "chat":          # a speech bubble, its tail at the lower left
        return P("M3,2.5 L17,2.5 C18.4,2.5 19,3.1 19,4.5 L19,12.5 C19,13.9 18.4,14.5 17,14.5 L9,14.5 L4,18.5 "
                 "L5,14.5 L3,14.5 C1.6,14.5 1,13.9 1,12.5 L1,4.5 C1,3.1 1.6,2.5 3,2.5 Z")
    if kind == "channels":      # a speaker, and its sound
        return P("M1.5,7 L5.5,7 L11,2 L11,18 L5.5,13 L1.5,13 Z"
                 "M13,6.6 C14.6,8.2 14.6,11.8 13,13.4 L14.4,14.8 C16.8,12.4 16.8,7.6 14.4,5.2 Z"
                 "M15.6,3.8 C19.2,7.2 19.2,12.8 15.6,16.2 L17,17.6 C21.4,13.4 21.4,6.6 17,2.4 Z")
    # the character window's tabs (character/window.lua)
    if kind == "character":     # head and shoulders
        return P("M6,6.5 a4,4.5 0 1,0 8,0 a4,4.5 0 1,0 -8,0 Z M1.5,19 C1.5,13 5,11.5 10,11.5 C15,11.5 18.5,13 18.5,19 Z")
    if kind == "reputation":    # a pennant on its pole
        return P("M3,1.5 L5,1.5 L5,19 L3,19 Z M5,2.5 L18,2.5 L14.5,6.5 L18,10.5 L5,10.5 Z")
    if kind == "currency":      # a stack of coins, and one standing beside it
        coins = "".join(f'<rect x="1.5" y="{y}" width="11" height="3.6" rx="1.8"/>' for y in (15, 11.5, 8, 4.5))
        return (f'<g transform="translate({x},{y}) scale({s})" {f}>{coins}'
                f'<circle cx="14.5" cy="13.5" r="4.6"/><circle cx="14.5" cy="13.5" r="2.2" fill="none"/></g>')
    if kind == "skills":        # a sword, point up
        return P("M10,1 L12,4 L12,12.5 L15.5,12.5 L15.5,14.5 L11.2,14.5 L11.2,17 L12.2,17 L12.2,19 L7.8,19 "
                 "L7.8,17 L8.8,17 L8.8,14.5 L4.5,14.5 L4.5,12.5 L8,12.5 L8,4 Z")
    if kind == "pvp":           # two swords, crossed
        blade = ("M10,0.5 L11.6,3 L11.6,12 L14.5,12 L14.5,13.6 L11,13.6 L11,17.5 L9,17.5 L9,13.6 L5.5,13.6 "
                 "L5.5,12 L8.4,12 L8.4,3 Z")
        return (f'<g transform="translate({x},{y}) scale({s})" {f}>'
                f'<path d="{blade}" transform="rotate(-38 10 10.5)"/><path d="{blade}" transform="rotate(38 10 10.5)"/>'
                f'</g>')
    if kind == "statistics":    # three bars on a line
        return P("M2,17 L18,17 L18,19 L2,19 Z M3.5,10 L7,10 L7,16 L3.5,16 Z M8.25,4 L11.75,4 L11.75,16 L8.25,16 Z"
                 "M13,7.5 L16.5,7.5 L16.5,16 L13,16 Z")
    # the window's own controls: fold the details, unfold them, close
    if kind == "chevron-down":
        return P("M2,5 L10,13 L18,5 L18,9.5 L10,17.5 L2,9.5 Z")
    if kind == "chevron-up":
        return P("M2,15 L10,7 L18,15 L18,10.5 L10,2.5 L2,10.5 Z")
    if kind == "close":         # a cross of two bars
        bar = '<rect x="8.4" y="1" width="3.2" height="18" rx="0.6" transform="rotate({} 10 10)"/>'
        return f'<g transform="translate({x},{y}) scale({s})" {f}>{bar.format(45)}{bar.format(-45)}</g>'
    if kind == "misc":          # a lozenge, for a button this list does not know
        return P("M10,1.5 L18.5,10 L10,18.5 L1.5,10 Z M10,5.5 L14.5,10 L10,14.5 L5.5,10 Z", "evenodd")
    raise ValueError(kind)


# ----------------------------------------------------------------- pieces
def pts(p):
    return " ".join(f"{x:.1f},{y:.1f}" for x, y in p)


def strip(side):
    """One strip: flush with the screen edge and bottom, the inner end cut at
    45 degrees like the console's own ends, a gold edge and inner hairline
    along the top."""
    top = H - STRIP_H

    def m(x):
        return x if side < 0 else W - x
    body = [(m(0), H), (m(0), top), (m(LENGTH), top), (m(LENGTH + STRIP_H), H)]
    hair = [(m(0), top + 3), (m(LENGTH + 1.2), top + 3), (m(LENGTH + STRIP_H - 1.8), H)]
    return (f'<polygon points="{pts(body)}" fill="url(#navy)" stroke="{GOLD_D}" stroke-width="1.6" '
            f'filter="url(#shadow)"/>'
            f'<polyline points="{pts(hair)}" fill="none" stroke="{GOLD}" stroke-width="0.9" opacity="0.8"/>')


def medallion(cx, cy, inner):
    """A round button: gold ring, ink well, and whatever sits inside it."""
    return (f'<circle cx="{cx}" cy="{cy}" r="{MED_R}" fill="url(#navy)" stroke="{GOLD_D}" stroke-width="1.6" '
            f'filter="url(#shadow)"/>'
            f'<circle cx="{cx}" cy="{cy}" r="{MED_R - 3}" fill="{INK}" stroke="url(#gold)" stroke-width="2.4"/>'
            f'{inner}')


def portrait(cx, cy):
    """A stand-in for the player's portrait (SetPortraitTexture in game)."""
    r = MED_R - 5
    return (f'<clipPath id="pc{cx}"><circle cx="{cx}" cy="{cy}" r="{r}"/></clipPath>'
            f'<g clip-path="url(#pc{cx})"><circle cx="{cx}" cy="{cy}" r="{r}" fill="url(#portrait)"/>'
            f'<circle cx="{cx}" cy="{cy - 4}" r="7" fill="#c9a98a"/>'
            f'<path d="M{cx - 15},{cy + 20} C{cx - 14},{cy + 6} {cx + 14},{cy + 6} {cx + 15},{cy + 20} Z" '
            f'fill="#5a6a8a"/></g>')


def backpack(cx, cy):
    """A stand-in for the backpack's own item icon (shown round in game)."""
    x, y = cx - 12, cy - 12
    return (f'<g transform="translate({x},{y})">'
            f'<path d="M5,7 C5,2 19,2 19,7" fill="none" stroke="#6a3a14" stroke-width="2.4"/>'
            f'<rect x="2" y="7" width="20" height="15" rx="3" fill="#b0702a" stroke="#4a2408" stroke-width="1"/>'
            f'<rect x="2" y="7" width="20" height="6" rx="2" fill="#c98a3a" stroke="#4a2408" stroke-width="1"/>'
            f'<rect x="10" y="10" width="4" height="6" fill="#e8d6a0" stroke="#4a2408" stroke-width="0.8"/></g>')


def text(x, y, s, anchor="middle", size=15):
    return (f'<text x="{x}" y="{y}" font-family="Marcellus SC" font-size="{size}" fill="{TEXT}" '
            f'text-anchor="{anchor}" stroke="#000" stroke-width="2.4" paint-order="stroke">{s}</text>')


def divider(x):
    top = H - STRIP_H
    return f'<line x1="{x}" y1="{top + 8}" x2="{x}" y2="{H - 5}" stroke="{GOLD_D}" stroke-width="1"/>'


def micro_buttons(x0, step):
    """The glyph row, starting at x0 and stepping step px per button (negative
    to run leftward)."""
    cy = H - STRIP_H / 2 + GLYPH_DROP
    out = []
    for i, kind in enumerate(MICRO):
        cx = x0 + i * step
        out.append(glyph(kind, cx - GLYPH / 2, cy - GLYPH / 2))
    return "".join(out)


def status(x0, x1):
    """Bags | Durability | clock, spread evenly between x0 and x1."""
    y = H - 9
    items = ["Bags 48%", "Durability 100%", "11:39"]
    widths = [70, 122, 44]                       # Marcellus SC 15px, measured
    gap = (abs(x1 - x0) - sum(widths)) / len(items)
    out, x = [], min(x0, x1) + gap / 2
    for i, (s, w) in enumerate(zip(items, widths)):
        out.append(text(x + w / 2, y, s))
        x += w + gap
        if i < len(items) - 1:
            out.append(divider(x - gap / 2))
    return "".join(out)


# --------------------------------------------------------------- variants
MED_Y = H - MED_R - 3


def variant(kind):
    body = [strip(-1), strip(1)]
    if kind == "A":
        # medallions at the inner ends, the glyphs and stats reading outward
        lx, rx = LENGTH - MED_R - 22, W - (LENGTH - MED_R - 22)
        body.append(micro_buttons(lx - MED_R - 26, -PITCH))
        body.append(medallion(lx, MED_Y, portrait(lx, MED_Y)))
        body.append(medallion(rx, MED_Y, backpack(rx, MED_Y)))
        body.append(status(rx + MED_R + 10, W - 12))
    else:
        # medallions at the outer corners, the glyphs and stats reading inward
        lx, rx = MED_R + 10, W - MED_R - 10
        body.append(micro_buttons(lx + MED_R + 26, PITCH))
        body.append(medallion(lx, MED_Y, portrait(lx, MED_Y)))
        body.append(medallion(rx, MED_Y, backpack(rx, MED_Y)))
        body.append(status(W - LENGTH + 4, rx - MED_R - 18))
    return svg("".join(body))


def leave(size=64):
    """The leave-vehicle seat, for the right well while a vehicle can be left
    (Blizzard's own art is a square button with a frame; the well is round):
    a crimson disc filling the 64x64 part edge to edge, as the backpack's icon
    does (the part is drawn at the well's size, under the ring), and a gold
    door with an arrow stepping out of it, drawn on a 64 box then grown a fifth
    about the disc's centre so it reads at 42 px."""
    c = size / 2
    f = 'fill="url(#gold)" stroke="#2a0806" stroke-width="1.1" stroke-linejoin="round"'
    return (f'<radialGradient id="seat" cx="45%" cy="38%" r="65%">'
            f'<stop offset="0" stop-color="#b8322a"/><stop offset="0.7" stop-color="#6e1410"/>'
            f'<stop offset="1" stop-color="#3a0806"/></radialGradient>'
            f'<circle cx="{c}" cy="{c}" r="{c}" fill="url(#seat)"/>'
            # the glyph's box is 19-48 by 15-47: centred, then grown
            f'<g transform="translate({c},{c}) scale(1.2) translate(-33.5,-31)">'
            # the door: an arched frame, open on its right
            f'<path d="M37,47 L19,47 L19,26 C19,15 37,15 37,26 L37,29 L33,29 L33,26 C33,20.5 23,20.5 23,26 '
            f'L23,43 L33,43 L33,40 L37,40 Z" {f}/>'
            # the arrow, stepping out through the opening
            f'<path d="M27,32.5 L39,32.5 L39,27 L48,34.5 L39,42 L39,36.5 L27,36.5 Z" {f}/></g>')


def svg(body):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}"><defs>'
            f'<linearGradient id="navy" x1="0" y1="0" x2="0" y2="1">'
            f'<stop offset="0" stop-color="#3a4154"/><stop offset="1" stop-color="#252a37"/></linearGradient>'
            f'<linearGradient id="gold" x1="0" y1="0" x2="0" y2="1">'
            f'<stop offset="0" stop-color="#f0d488"/><stop offset="1" stop-color="#a8823a"/></linearGradient>'
            f'<radialGradient id="portrait" cx="50%" cy="35%" r="70%">'
            f'<stop offset="0" stop-color="#4a5a7a"/><stop offset="1" stop-color="#151a26"/></radialGradient>'
            f'<filter id="shadow" x="-20%" y="-60%" width="140%" height="220%">'
            f'<feGaussianBlur in="SourceAlpha" stdDeviation="3"/><feOffset dy="-1"/>'
            f'<feComponentTransfer><feFuncA type="linear" slope="0.6"/></feComponentTransfer>'
            f'<feMerge><feMergeNode/><feMergeNode in="SourceGraphic"/></feMerge></filter>'
            f'</defs>{body}</svg>')


def render(kind):
    png = os.path.join(OUT, f"strips-{kind}.png")
    subprocess.run(["rsvg-convert", "-o", png], input=variant(kind).encode(), check=True)
    base = Image.open(BASE).convert("RGBA").crop((0, 0, W, H))
    screen = Image.alpha_composite(base, Image.open(png).convert("RGBA"))
    screen.convert("RGB").save(os.path.join(OUT, f"strips-{kind}-screen.png"))
    return screen


# ----------------------------------------------------------------- layer3
GLYPHS = ["spellbook", "talents", "quests", "social", "guild", "lfg", "map", "menu", "help",
          "profession", "achievement", "housing", "collections", "journal", "store", "legacy", "misc"]
# the character window's tabs, its controls, the quest tracker's footer and the chat box's head
TABS = ["character", "reputation", "currency", "skills", "pvp", "statistics",
        "chevron-down", "chevron-up", "close", "questlog", "sort", "view-minimal", "view-full",
        "chat", "channels"]


def part(name, inner, size=32):
    """One of the parts code places: assets/strips/<name>.png."""
    parts = os.path.join(ROOT, "assets", "strips")
    os.makedirs(parts, exist_ok=True)
    doc = svg(inner).replace(f'width="{W}" height="{H}"', f'width="{size}" height="{size}"')
    subprocess.run(["rsvg-convert", "-o", os.path.join(parts, name + ".png")], input=doc.encode(), check=True)


# The quest tracker's mark for a dungeon's or a raid's quest: an arched
# wooden gate in a gold frame, the doors' planks and iron bands. Its own
# colours (not the glyphs' gold fill), drawn at 64 so it stays clear at the
# 14-20 pixels a quest's mark is drawn at.
def gate(size=64):
    s = size / 20
    frame = ("M1.5,19.5 L1.5,9 C1.5,4 5.5,0.5 10,0.5 C14.5,0.5 18.5,4 18.5,9 L18.5,19.5 Z"
             "M4.3,19.5 L4.3,9.4 C4.3,6 6.8,3.4 10,3.4 C13.2,3.4 15.7,6 15.7,9.4 L15.7,19.5 Z")
    door = "M4.3,19.5 L4.3,9.4 C4.3,6 6.8,3.4 10,3.4 C13.2,3.4 15.7,6 15.7,9.4 L15.7,19.5 Z"
    seams = "M7.15,4.6 L7.15,19.5 M12.85,4.6 L12.85,19.5"
    return (f'<g transform="scale({s})">'
            f'<path d="{door}" fill="url(#wood)"/>'
            f'<path d="{seams}" stroke="#2e1a08" stroke-width="0.55"/>'
            f'<path d="M10,3.4 L10,19.5" stroke="#1c0f04" stroke-width="0.9"/>'
            f'<path d="M4.3,8.6 L15.7,8.6 M4.3,15.6 L15.7,15.6" stroke="#2a2724" stroke-width="1.3"/>'
            f'<circle cx="8.9" cy="12.3" r="0.65" fill="url(#gold)"/>'
            f'<circle cx="11.1" cy="12.3" r="0.65" fill="url(#gold)"/>'
            f'<path d="{frame}" fill="url(#gold)" fill-rule="evenodd" stroke="#2a1e08" stroke-width="0.6"/>'
            f'</g>')


def gate_part():
    """assets/strips/quest-dungeon.png, and a look at it in render/gate.png:
    at 4x, and at the sizes the tracker draws it over its ink."""
    doc = svg(gate()).replace(f'width="{W}" height="{H}"', 'width="64" height="64"').replace(
        "</defs>", '<linearGradient id="wood" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#9a6634"/>'
        '<stop offset="1" stop-color="#5c3a18"/></linearGradient></defs>')
    parts = os.path.join(ROOT, "assets", "strips")
    path = os.path.join(parts, "quest-dungeon.png")
    subprocess.run(["rsvg-convert", "-o", path], input=doc.encode(), check=True)
    im = Image.open(path).convert("RGBA")
    os.makedirs(OUT, exist_ok=True)
    sheet = Image.new("RGBA", (256 + 3 * 40 + 40, 264), (18, 17, 16, 255))
    sheet.alpha_composite(im.resize((256, 256), Image.LANCZOS), (4, 4))
    for i, n in enumerate((14, 18, 22)):
        sheet.alpha_composite(im.resize((n, n), Image.LANCZOS), (280 + i * 40, 120))
    out = os.path.join(OUT, "gate.png")
    sheet.save(out)
    print(out)


def glyphs():
    """The glyph parts alone (layer3 untouched), and a sheet of them at 4x
    in render/glyphs.png to look at."""
    for g in GLYPHS + TABS:
        part(g, glyph(g, 6, 6))
    os.makedirs(OUT, exist_ok=True)
    names = GLYPHS + TABS
    sheet = Image.new("RGBA", (len(names) * 140, 140), (18, 17, 16, 255))
    for i, g in enumerate(names):
        im = Image.open(os.path.join(ROOT, "assets", "strips", g + ".png")).convert("RGBA").resize((128, 128),
                                                                                                    Image.NEAREST)
        sheet.alpha_composite(im, (i * 140 + 6, 6))
    path = os.path.join(OUT, "glyphs.png")
    sheet.save(path)
    print(path)
WELL_R = MED_R - 4            # the hole under the ring: portrait or bag icon


def layer3():
    """Variant B's bare art: both strips and their medallion rings, the wells
    cut out; plus the parts code places (glyphs, round mask)."""
    from PIL import ImageDraw
    os.makedirs(OUT, exist_ok=True)
    lx, rx = MED_R + 10, W - MED_R - 10
    body = strip(-1) + strip(1) + medallion(lx, MED_Y, "") + medallion(rx, MED_Y, "")
    png = os.path.join(OUT, "layer3-raw.png")
    subprocess.run(["rsvg-convert", "-o", png], input=svg(body).encode(), check=True)
    img = Image.open(png).convert("RGBA")
    # punch the wells, antialiased by drawing the hole at 4x
    k = 4
    hole = Image.new("L", (W * k, H * k), 0)
    d = ImageDraw.Draw(hole)
    for cx in (lx, rx):
        d.ellipse(((cx - WELL_R) * k, (MED_Y - WELL_R) * k, (cx + WELL_R) * k, (MED_Y + WELL_R) * k), fill=255)
    hole = hole.resize((W, H), Image.LANCZOS)
    alpha = img.getchannel("A")
    alpha = Image.composite(Image.new("L", (W, H), 0), alpha, hole)
    img.putalpha(alpha)
    path = os.path.join(ROOT, "assets", "layer3.png")
    img.save(path)
    print(path, img.getchannel("A").getbbox())

    parts = os.path.join(ROOT, "assets", "strips")
    for g in GLYPHS + TABS:
        part(g, glyph(g, 6, 6))
    # white disc: the backpack icon's mask and the medallions' hover glow
    part("round", '<circle cx="32" cy="32" r="31.5" fill="#fff"/>', size=64)
    # the leave-vehicle seat, in the right well while a vehicle can be left
    part("leave", leave(), size=64)
    # the numbers code needs that the art cannot show (screen px, 1080p)
    import json
    with open(os.path.join(parts, "layout.json"), "w") as f:
        json.dump({**chat(), "stripHeight": STRIP_H, "length": LENGTH, "pitch": PITCH, "glyphTex": 32,
                   # first glyph's centre, from the screen edge
                   "firstGlyph": lx + MED_R + 26,
                   # the glyph's centre sits this far below the strip's middle
                   "glyphDrop": GLYPH_DROP,
                   # the medallion ring's radius: the well is inside it
                   "ringRadius": MED_R,
                   # the stats run between these, from the screen edge
                   "statsFrom": MED_R + 10 + MED_R + 18, "statsTo": LENGTH - 4}, f, indent=1)
    print(parts, len(os.listdir(parts)), "parts")


# ------------------------------------------------------------------- chat
# The chat panel: Blizzard's own chat frames, standing on the left strip from
# the portrait's medallion to the strip's top inner corner, so the chat sits
# on the micro menu. Its own texture, not part of layer3, which must mirror:
# the right strip has nothing above it. Fixed in size (the user's call; a
# height setting may come later). Panel pixels from its top-left:
CHAT_LEFT = MED_R * 2 + 16        # clear of the medallion and its shadow
CHAT_W, CHAT_H = LENGTH - CHAT_LEFT, 180
CHAT_PAD = 4
CHAT_COLUMN = 29                  # Blizzard's button frame, in the left column
CHAT_TOP = 0                      # tabs rest on top of the panel, not inside
CHAT_RIGHT = 14                   # the scroll bar (8) and a margin
CHAT_EDIT = 32                    # the edit box, over the messages' foot
CHAT_R = 6                        # the top corners
TAB_W, TAB_H, TAB_CAP, TAB_TOP = 64, 32, 16, 8    # the tab's art: three slices, shape below TAB_TOP


def chat_panel():
    """The panel: translucent black fading from bottom to top, open at the
    foot, where the strip's own gold edge is its border."""
    w, h = CHAT_W, CHAT_H
    return (f'<linearGradient id="panel" x1="0" y1="0" x2="0" y2="1">'
            f'<stop offset="0" stop-color="#000000" stop-opacity="0"/>'
            f'<stop offset="1" stop-color="#000000" stop-opacity="0.80"/></linearGradient>'
            f'<rect width="{w}" height="{h}" fill="url(#panel)"/>')


def chat_tab(selected):
    """A tab, 64x32 in three slices (caps TAB_CAP wide): rounded top corners,
    open at the foot onto the panel."""
    top, r = TAB_TOP + 0.5, 5
    d = (f"M1.5,{TAB_H} L1.5,{top + r} Q1.5,{top} {1.5 + r},{top} L{TAB_W - 1.5 - r},{top} "
         f"Q{TAB_W - 1.5},{top} {TAB_W - 1.5},{top + r} L{TAB_W - 1.5},{TAB_H}")
    if selected:
        fill = ('<linearGradient id="tab" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#4a5368"/>'
                '<stop offset="1" stop-color="#2c3242"/></linearGradient>')
        rim, glow = 'url(#gold)', f'<line x1="{2 + r}" y1="{top + 1.5}" x2="{TAB_W - 2 - r}" y2="{top + 1.5}" ' \
            f'stroke="#f0d488" stroke-width="1" opacity="0.6"/>'
    else:
        fill = ('<linearGradient id="tab" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#2c3242"/>'
                '<stop offset="1" stop-color="#1c202b"/></linearGradient>')
        rim, glow = GOLD_D, ""
    return (f'{fill}<path d="{d} Z" fill="url(#tab)" fill-opacity="0.9"/>'
            f'<path d="{d}" fill="none" stroke="{rim}" stroke-width="1.4"/>{glow}')


def chat():
    """assets/chat.png and the tab parts; their numbers go in layout.json."""
    doc = svg(chat_panel()).replace(f'width="{W}" height="{H}"', f'width="{CHAT_W}" height="{CHAT_H}"')
    path = os.path.join(ROOT, "assets", "chat.png")
    subprocess.run(["rsvg-convert", "-o", path], input=doc.encode(), check=True)
    parts = os.path.join(ROOT, "assets", "strips")
    for name, sel in (("tab", False), ("tab-selected", True)):
        doc = svg(chat_tab(sel)).replace(f'width="{W}" height="{H}"', f'width="{TAB_W}" height="{TAB_H}"')
        subprocess.run(["rsvg-convert", "-o", os.path.join(parts, name + ".png")], input=doc.encode(), check=True)
    print(path, Image.open(path).size)
    return {"chatLeft": CHAT_LEFT, "chatWidth": CHAT_W, "chatHeight": CHAT_H, "chatPad": CHAT_PAD,
            "chatColumn": CHAT_COLUMN, "chatTop": CHAT_TOP, "chatRight": CHAT_RIGHT, "chatEdit": CHAT_EDIT,
            "tabCap": TAB_CAP, "tabTex": TAB_W}


def chat_preview():
    """The left corner with the panel, tabs and some lines, at 2x."""
    from PIL import ImageDraw, ImageFont
    base = Image.open(os.path.join(OUT, "strips-B-screen.png")).convert("RGBA")
    panel = Image.open(os.path.join(ROOT, "assets", "chat.png")).convert("RGBA")
    top = H - STRIP_H - CHAT_H
    layer = Image.new("RGBA", base.size, (0, 0, 0, 0))
    layer.paste(panel, (CHAT_LEFT, top))
    parts = os.path.join(ROOT, "assets", "strips")
    font = ImageFont.truetype(os.path.join(ROOT, "WoW", "Interface", "AddOns", "Medalluin", "media", "fonts",
                                           "MarcellusSC-Regular.ttf"), 11)
    x = CHAT_LEFT + CHAT_PAD + CHAT_COLUMN + 5 - 2 + 2      # Background's left, plus the tab's own 2
    for i, label in enumerate(("General", "Log", "Trade")):
        tw = max(TAB_W, int(font.getlength(label)) + 28)
        tab = Image.open(os.path.join(parts, "tab-selected.png" if i == 0 else "tab.png")).convert("RGBA")
        # three slices, the middle stretched
        cap = TAB_CAP
        img = Image.new("RGBA", (tw, TAB_H))
        img.paste(tab.crop((0, 0, cap, TAB_H)), (0, 0))
        img.paste(tab.crop((cap, 0, TAB_W - cap, TAB_H)).resize((tw - 2 * cap, TAB_H)), (cap, 0))
        img.paste(tab.crop((TAB_W - cap, 0, TAB_W, TAB_H)), (tw - cap, 0))
        ty = top - TAB_H
        layer.alpha_composite(img, (x, ty))
        ImageDraw.Draw(layer).text((x + tw / 2, ty + 21), label, font=font, anchor="mm",
                                   fill=(255, 210, 0) if i == 0 else (200, 170, 80))
        x += tw + 1
    d = ImageDraw.Draw(layer)
    mx = CHAT_LEFT + CHAT_PAD + CHAT_COLUMN + 5
    lines = ["[Guild] Aldren: anyone for the raid tonight?", "You are no longer Away.",
             "[Trade] Selling Flask of the Currents", "[Party] Mira: pull in 3"]
    for i, s in enumerate(lines):
        d.text((mx, H - STRIP_H - 6 - 14 * (len(lines) - i)), s, font=font, fill=(242, 234, 210))
    # the button column's three Blizzard buttons, as boxes
    cx = CHAT_LEFT + CHAT_PAD + CHAT_COLUMN / 2
    for y in (top + 4, top + 34, H - STRIP_H - 4 - 26):
        d.rounded_rectangle((cx - 12, y, cx + 12, y + 24), 4, outline=(196, 165, 87), width=1)
    screen = Image.alpha_composite(base, layer)
    # the left strip over it, as in game
    strip = Image.open(os.path.join(ROOT, "assets", "layer3.png")).convert("RGBA")
    screen = Image.alpha_composite(screen, strip)
    crop = screen.crop((0, top - 36, LENGTH + 60, H)).convert("RGB")
    crop = crop.resize((crop.width * 2, crop.height * 2), Image.LANCZOS)
    path = os.path.join(OUT, "chat.png")
    crop.save(path)
    print(path)


def main():
    from PIL import ImageDraw, ImageFont
    os.makedirs(OUT, exist_ok=True)
    font = ImageFont.truetype(os.path.join(ROOT, "WoW", "Interface", "AddOns", "Medalluin", "media", "fonts",
                                           "MarcellusSC-Regular.ttf"), 22)
    rows = []
    for kind in ("A", "B"):
        screen = render(kind)
        # the bottom 220px of the whole screen, then each corner at 2x
        band = screen.crop((0, H - 220, W, H)).convert("RGB")
        ImageDraw.Draw(band).text((14, 10), kind, font=font, fill=(242, 234, 210))
        rows.append(band)
    sheet = Image.new("RGB", (W, sum(r.height for r in rows) + 8 * (len(rows) - 1)), (10, 10, 10))
    y = 0
    for r in rows:
        sheet.paste(r, (0, y))
        y += r.height + 8
    path = os.path.join(OUT, "strips.png")
    sheet.save(path)
    print(path)
    chat_preview()


if __name__ == "__main__":
    import sys
    if sys.argv[1:2] == ["layer3"]:
        layer3()
    elif sys.argv[1:2] == ["glyphs"]:
        glyphs()
    elif sys.argv[1:2] == ["gate"]:
        gate_part()
    else:
        main()
