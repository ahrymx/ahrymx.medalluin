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
    up over down) and the page number's box; the left end is the same panel
    with a plain boss, so the outline stays symmetric and bar 1 stays
    centred on the console;
  * the lower row: one dark well as wide as the upper row, end panels
    included, for the player's cast bar (bars/cast.lua) and, when no cast is
    running, the class resource (bars/power.lua);
  * the chevrons themselves (up and down, normal and pushed, and a shared
    highlight), as small textures for Blizzard's own page buttons to wear.

Rows 2 and 3 (the Rows option) stand above the frame, bare.

    python3 art/bars/gen_bar.py          -> plan/bar.png (1 row), plan/bar-rows.png (1, 2, 3)
    python3 art/bars/gen_bar.py layer2   -> assets/layer2.png, assets/layer2.json, assets/bar/*.png

assets/layer2.png is the plate in the console's asset format (a 1920x1081
screen) with every window punched out: the 12 slots and the lower row.
assets/layer2.json lists them, the pager's boxes, and the rows above the
frame. art/console/export.py checks the holes against the list and writes
media/actionbar.tga, media/bar/*.tga and bars/windows.lua.

Distances are 1080p screen pixels, from the centre line.
"""
import json
import os
import subprocess
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
OUT = os.path.join(HERE, "render")
BASE = os.path.join(ROOT, "plan", "H-party-combat-screen.png")
PARTS = os.path.join(ROOT, "assets", "bar")

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
CHEVRON_IN, CHEVRON_W, CHEVRON_H, PAGER_GAP = 5, 18, 17, 2
NUMBER_IN, NUMBER_W, NUMBER_H = 3, 11, 17
# The chevron textures: canvas size, and the button they are drawn for.
TEX = 32

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


def boss():
    """The left end's ornament: a round stud, centred where the right end's
    boxes are, mirrored."""
    b = pager_boxes()
    l, r = b["up"][0], b["number"][2]
    return 2 * CX - (l + r) / 2, (SLOT_TOP + SLOT_BOTTOM) / 2


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
    """The plate's art, the windows included as wells (the layer2 pass
    punches the slots and the lower row out)."""
    stone_defs(defs)
    f = frame_outline()
    body = [f'<polygon points="{pts(f)}" fill="url(#stone)" stroke="{STONE_EDGE}" stroke-width="1.6"/>',
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
    for l, t, r, b in holes():
        body.append(well(l, t, r, b))
    b = pager_boxes()
    for k in ("up", "down", "number"):
        body.append(well(*b[k]))
    # the pager's boxes get a gold rim, as the reference's do
    for k in ("up", "down", "number"):
        l, t, r, bt = b[k]
        body.append(f'<rect x="{l - 0.5}" y="{t - 0.5}" width="{r - l + 1}" height="{bt - t + 1}" '
                    f'fill="none" stroke="{GOLD_D}" stroke-width="1"/>')
    bx, by = boss()
    body.append(f'<circle cx="{bx}" cy="{by}" r="7" fill="{STONE_EDGE}"/>'
                f'<circle cx="{bx}" cy="{by}" r="6" fill="url(#stone)"/>'
                f'<circle cx="{bx - 1.5}" cy="{by - 1.5}" r="2" fill="{STONE_HI}" opacity="0.8"/>')
    return "".join(body)


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


def chevrons():
    os.makedirs(PARTS, exist_ok=True)
    for name, (d, state) in CHEVRONS.items():
        rsvg(chevron_svg(d, state), os.path.join(PARTS, f"{name}.png"))


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
    for l, t, r, b in holes():
        for y in range(t, b):
            for x in range(l, r):
                px[x, y] = (0, 0, 0, 0)
    path = os.path.join(ROOT, "assets", "layer2.png")
    img.save(path)
    chevrons()
    layout = {
        "console_top": CONSOLE_TOP,
        "frame": [CX - FOOT_HALF, FRAME_TOP, CX + FOOT_HALF, FOOT_Y],
        "upper": [CX - FRAME_HALF, FRAME_TOP, CX + FRAME_HALF, SLOT_BOTTOM + MID_BAND],
        "low": list(LOW),
        "pager": {k: list(v) for k, v in pager_boxes().items()},
        "chevrons": sorted(CHEVRONS),
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
            f'<text x="{l + 4}" y="{b - 3}" {text}>{label}</text>'
            f'<text x="{r - 4}" y="{b - 3}" {text} text-anchor="end">0.9</text>')


def screen(rows, lit=3, casting=False):
    """The bar over the console's combat render; the plate's foot goes UNDER
    the console art, so the console is pasted back over it."""
    defs = []
    row = cast(0.62, "Frostbolt") if casting else power(5, lit)
    body = [plate(defs), row, icons(rows, defs), chevrons_drawn()]
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
