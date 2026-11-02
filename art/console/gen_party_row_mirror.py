r"""Draft: the light console's party row, mirrored like the console's party.

  Now  1 2 | 3 4   every frame a left copy: fills from the left, name on the left
  A    1 2 | 3 4   the slots as they are; the right pair mirrored
  B    3 1 | 2 4   the console's order too: party1 and party2 take the inner
                   pair, so a small group stays near the centre; the right
                   pair mirrored

A mirrored frame fills from its outer end, its name and role icon sit at the
outer end, its auras at the inner end. The row's geometry is
gen_light_console.party_row_boxes; pets hang under it (gen_party_row_pets.py).
Shown 2x.
"""
import os

from PIL import Image, ImageDraw

import gen_light_console as G

HERE = os.path.dirname(os.path.abspath(__file__))
SCALE = 2
GOLD, INK, BG = (196, 160, 82), (14, 14, 16), (40, 44, 52)
CLASS = {1: (196, 196, 196), 2: (64, 170, 210), 3: (170, 120, 90), 4: (200, 190, 60)}
FILL = {1: 0.85, 2: 0.6, 3: 0.4, 4: 0.75}
POWER = {1: (150, 40, 200), 2: (40, 60, 210), 3: (200, 30, 30), 4: (220, 200, 0)}
VARIANTS = [("Now   1 2 | 3 4, all left copies", (1, 2, 3, 4), (-1, -1, -1, -1)),
            ("A   1 2 | 3 4, right pair mirrored", (1, 2, 3, 4), (-1, -1, 1, 1)),
            ("B   3 1 | 2 4, the console's order, right pair mirrored", (3, 1, 2, 4), (-1, -1, 1, 1))]


def font(size):
    return G.get_font(size)


def member(dr, box, unit, side):
    l, r, t, b = box
    dr.rectangle([l, t, r - 1, b - 1], fill=INK)
    hb = t + 21
    w = int((r - l) * FILL[unit])
    hx = (l, l + w) if side == -1 else (r - w, r)
    dr.rectangle([hx[0], t, hx[1] - 1, hb - 1], fill=CLASS[unit])
    pw = int((r - l) * 0.7)
    px = (l, l + pw) if side == -1 else (r - pw, r)
    dr.rectangle([px[0], hb + 1, px[1] - 1, b - 1], fill=POWER[unit])
    name = "Party %d" % unit
    f = font(10)
    if side == -1:
        dr.text((l + 6, t + 10), name, font=f, fill=(30, 30, 30), anchor="lm")
        ax = r - 16
    else:
        dr.text((r - 6, t + 10), name, font=f, fill=(30, 30, 30), anchor="rm")
        ax = l + 2
    dr.rectangle([ax, t + 2, ax + 13, t + 15], fill=(200, 110, 30), outline=(0, 0, 0))  # an aura
    rx = l - 3 if side == -1 else r - 6                                                  # the role icon
    dr.ellipse([rx, b - 4, rx + 9, b + 5], fill=(40, 60, 120), outline=GOLD)



def row(img, y0, order, sides):
    frames = G.party_row_boxes()
    dr = ImageDraw.Draw(img)
    cx = 20 + G.CONSOLE_W // 2
    run = int(G.ROW_RUN)
    top, bot = y0, y0 + G.ROW_H
    l, r = 20, 20 + G.CONSOLE_W
    dr.polygon([(l, top), (r, top), (r - run, bot), (l + run, bot)], fill=(28, 26, 22), outline=GOLD)
    dr.line([(cx, top), (cx, bot)], fill=(90, 80, 50))
    for slot, unit in enumerate(order):
        bx = frames[slot]
        member(dr, (cx + bx[0], cx + bx[1], y0 - bx[2] - G.ROW_TOP, y0 - bx[3] - G.ROW_TOP), unit, sides[slot])


def main():
    W = G.CONSOLE_W + 40
    H = 10 + len(VARIANTS) * 70
    img = Image.new("RGB", (W, H), BG)
    dr = ImageDraw.Draw(img)
    for k, (label, order, sides) in enumerate(VARIANTS):
        y = 10 + k * 70
        dr.text((20, y), label, font=font(11), fill=GOLD)
        row(img, y + 22, order, sides)
    img = img.resize((W * SCALE, H * SCALE), Image.Resampling.NEAREST)
    out = os.path.join(HERE, "render", "party-row-mirror-draft.png")
    img.save(out)
    print(out)


if __name__ == "__main__":
    main()
