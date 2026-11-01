r"""Draft: a horizontal party row hanging under the light ("central") console.

One band across the console's full width, cut into four equal slots by upright
seams. Only the band's two outer ends slant (80 degrees). A member with a pet
gives up part of its slot to a pet cell on the centre-ward side, so the slots
never move and a frame shrinks only when its own pet appears:

    ------------------------------------------------
    \   party1   | party2    |p3 |party3| party4  /
     \___________|___________|pet|______|________/

Draws the combat console from gen_light_console (the minimap is top-right, as it
will be whenever a group forms) with the row under it, in three pet states.
The game's art is exported by gen_light_console.py (render_party_row); this
is the preview.
"""
import os

import numpy as np
from PIL import Image, ImageDraw

import gen_light_console as G

# the export's geometry (gen_light_console.py), so the draft and the game agree
ANGLE = G.ROW_ANGLE
ROW_TOP = G.FLUSH_TOP_Y + G.ROW_TOP  # tucks 1px under the console's bottom border (991)
ROW_H = G.ROW_H
HEALTH_H, SEAM, POWER_H, INSET = 23, 1, 4, G.ROW_INSET
ROW_W = G.CONSOLE_W                  # 624
SLOT_W = G.ROW_SLOT                  # 156: a member's share, pet included
PET_W = G.ROW_PET                    # a pet cell takes this much of its owner's slot
RUN = ROW_H / np.tan(np.radians(ANGLE))   # 5.6: how far an outer end slants in

MEMBERS = [
    # name, role, class colour, health, power colour, power
    ("Party 1", "H", (255, 255, 255), 0.95, (0, 120, 220), 0.70),
    ("Party 2", "D", (64, 199, 235), 0.62, (0, 120, 220), 0.40),
    ("Party 3", "T", (199, 156, 110), 1.00, (200, 30, 30), 0.25),
    ("Party 4", "D", (255, 245, 105), 0.88, (240, 220, 40), 0.90),
]
PET_NAMES = ["Imp", "Wolf", "Wolf", "Cat"]
PET_HP = [0.70, 0.90, 0.55, 1.00]

STATES = [
    ("no pets", set()),
    ("party 3 has a pet (the sketch)", {2}),
    ("everyone has a pet", {0, 1, 2, 3}),
]


def x_on(edge, y):
    """x of a cell side (two points) at height y."""
    (xa, ya), (xb, yb) = edge
    return xa + (xb - xa) * (y - ya) / (yb - ya)


def cell(xa, xb):
    """The band between xa and xb: upright sides, except where the band's own end slants."""
    left, right = G.CX - ROW_W / 2, G.CX + ROW_W / 2
    y0, y1 = ROW_TOP, ROW_TOP + ROW_H
    return [(max(xa, left), y0), (min(xb, right), y0),
            (min(xb, right - RUN), y1), (max(xa, left + RUN), y1)]


def inset_poly(poly, k):
    tl, tr, br, bl = poly
    y0, y1 = tl[1] + k, bl[1] - k
    return [(x_on((tl, bl), y0) + k, y0), (x_on((tr, br), y0) - k, y0),
            (x_on((tr, br), y1) - k, y1), (x_on((tl, bl), y1) + k, y1)]


def band(poly, ya, yb, frac):
    """The part of an inset cell between ya and yb, filled to frac from the left."""
    tl, tr, br, bl = poly
    xl_a, xl_b = x_on((tl, bl), ya), x_on((tl, bl), yb)
    xr_a, xr_b = x_on((tr, br), ya), x_on((tr, br), yb)
    cut = min(xl_a, xl_b) + frac * (max(xr_a, xr_b) - min(xl_a, xl_b))
    return [(xl_a, ya), (min(cut, xr_a), ya), (min(cut, xr_b), yb), (xl_b, yb)]


def layout(pets):
    """Per member: (frame cell, pet cell or None). Pets sit on the centre-ward side."""
    out = []
    left = G.CX - ROW_W / 2
    for i in range(4):
        a, b = left + i * SLOT_W, left + (i + 1) * SLOT_W
        if i not in pets:
            out.append((cell(a, b), None))
        elif i < 2:                                   # left half: pet to the right
            out.append((cell(a, b - PET_W), cell(b - PET_W, b)))
        else:                                         # right half: pet to the left
            out.append((cell(a + PET_W, b), cell(a, a + PET_W)))
    return out


def ss_poly(size, polys, fills, scale=4):
    w, h = size
    layer = Image.new("RGBA", (w * scale, h * scale), (0, 0, 0, 0))
    dr = ImageDraw.Draw(layer)
    for p, col in zip(polys, fills):
        dr.polygon([(x * scale, y * scale) for x, y in p], fill=col)
    return layer.resize((w, h), Image.LANCZOS)


def draw_row(canvas, pets):
    cells = layout(pets)
    polys, fills = [], []
    for i, (frame, pet) in enumerate(cells):
        _, _, hcol, hp, pcol, pw = MEMBERS[i]
        inner = inset_poly(frame, INSET)
        y0 = inner[0][1]
        polys += [inner, band(inner, y0, y0 + HEALTH_H, hp),
                  band(inner, y0 + HEALTH_H + SEAM, y0 + HEALTH_H + SEAM + POWER_H, pw)]
        fills += [(16, 16, 20, 255), hcol + (220,), pcol + (255,)]
        if pet:
            pin = inset_poly(pet, INSET)
            polys += [pin, band(pin, pin[0][1], pin[3][1], PET_HP[i])]
            fills += [(14, 14, 18, 255), (60, 170, 70, 255)]
    canvas.alpha_composite(ss_poly(canvas.size, polys, fills))

    # Gold: the band's outline, slot seams in the bright gradient, owner|pet seams darker.
    whole = cell(-1e9, 1e9)
    pts = " ".join(f"{x:.2f},{y:.2f}" for x, y in whole)
    y0, y1 = ROW_TOP, ROW_TOP + ROW_H
    svg = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{G.W}" height="{G.H}"><defs>{G.svg_defs()}</defs>',
           f'<polygon points="{pts}" fill="none" stroke="url(#goldGrad)" stroke-width="1.6" filter="url(#shadow)"/>']
    left = G.CX - ROW_W / 2
    for i in range(1, 4):
        x = left + i * SLOT_W
        svg.append(f'<line x1="{x:.2f}" y1="{y0}" x2="{x:.2f}" y2="{y1}" stroke="url(#goldGrad)" stroke-width="1.6"/>')
    for i, (frame, pet) in enumerate(cells):
        inner = inset_poly(frame, INSET)
        ys = inner[0][1] + HEALTH_H + SEAM / 2
        svg.append(f'<line x1="{x_on((inner[0], inner[3]), ys):.2f}" y1="{ys:.2f}" '
                   f'x2="{x_on((inner[1], inner[2]), ys):.2f}" y2="{ys:.2f}" stroke="{G.GOLD_D}" stroke-width="1"/>')
        if pet:
            x = pet[0][0] if i < 2 else pet[1][0]
            svg.append(f'<line x1="{x:.2f}" y1="{y0 + 1}" x2="{x:.2f}" y2="{y1 - 1}" stroke="{G.GOLD_D}" stroke-width="1"/>')
    svg.append("</svg>")
    tmp = os.path.join(G.OUT, "_tmp_row.png")
    canvas.alpha_composite(G.rsvg("".join(svg), tmp))
    os.remove(tmp)

    dr = ImageDraw.Draw(canvas)
    f_name, f_small, f_pet = G.get_font(11), G.get_font(9), G.get_font(8)
    for i, (frame, pet) in enumerate(cells):
        name, role, _, hp, _, _ = MEMBERS[i]
        inner = inset_poly(frame, INSET)
        ty = inner[0][1] + HEALTH_H / 2
        xl, xr = x_on((inner[0], inner[3]), ty), x_on((inner[1], inner[2]), ty)
        dr.rectangle([xl + 3, ty - 7, xl + 17, ty + 7], fill=(30, 30, 35, 255), outline=(180, 150, 60))
        dr.text((xl + 10, ty), role, font=f_small, fill=(240, 240, 240), anchor="mm")
        for dx, dy, col in ((1, 1, (0, 0, 0)), (0, 0, (245, 240, 225))):
            dr.text((xl + 22 + dx, ty + dy), name, font=f_name, fill=col, anchor="lm")
            dr.text((xr - 4 + dx, ty + dy), f"{int(hp * 100)}%", font=f_small, fill=col, anchor="rm")
        if pet:
            cx = (pet[0][0] + pet[1][0]) / 2
            cy = (pet[0][1] + pet[3][1]) / 2
            for dx, dy, col in ((1, 1, (0, 0, 0)), (0, 0, (245, 240, 225))):
                dr.text((cx + dx, cy - 6 + dy), PET_NAMES[i], font=f_pet, fill=col, anchor="mm")
                dr.text((cx + dx, cy + 6 + dy), f"{int(PET_HP[i] * 100)}%", font=f_pet, fill=col, anchor="mm")


def main():
    os.makedirs(G.OUT, exist_ok=True)
    crop = (int(G.CX - 340), 845, int(G.CX + 340), 1040)
    shots = []
    for label, pets in STATES:
        img = G.composite_mockup(mode="combat")
        draw_row(img, pets)
        c = img.crop(crop)
        c = c.resize((c.width * 2, c.height * 2), Image.LANCZOS)
        ImageDraw.Draw(c).text((12, 10), f"{ANGLE} deg ends   slot {SLOT_W:.0f}px   pet {PET_W}px   -   {label}",
                               font=G.get_font(20), fill=(242, 234, 210))
        shots.append(c)
    sheet = Image.new("RGBA", (shots[0].width, sum(s.height for s in shots) + 16 * 2), (12, 13, 16, 255))
    y = 0
    for s in shots:
        sheet.paste(s, (0, y))
        y += s.height + 16
    path = os.path.join(G.OUT, "party-row-draft.png")
    sheet.save(path)
    print(path)


if __name__ == "__main__":
    main()
