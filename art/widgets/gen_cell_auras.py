r"""Draft: auras on the group widgets' cells (Unit Frames > Raid, Battleground,
Boss, Arena). The party's frames already carry them: a glow on the border
for a debuff you can dispel, a centre icon for crowd control or a boss
debuff, your own buffs in a corner. The widget cells are smaller (raid
112x36, boss 180x40, arena 160x40), so where those go is the question.

  Raid / Battleground (friendly):
    A  the centre icon over the middle of the health, as on the party frames
    B  the icon at the health's right end; the value steps left of it
  Boss / Arena (enemy): your debuffs on it, and on arena the CC it is under
    A  inside: your debuffs in a row in the health's top-right corner; CC
       in the centre (arena)
    B  outside: your debuffs in a strip beside the cell, the box wider by it;
       CC in the centre (arena)

Drawn at the game's size, then shown 3x.
"""
import os

from PIL import Image, ImageDraw

from gen_widgets import (BG, CLASSES, EDGE, GAP, GOLD, GOLD_BRIGHT, GOLD_D, INK, NAMES, PAD, TEXT, WELL,
                         font)

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "render")
SCALE = 3

CURSE, MAGIC = (178, 0, 255), (51, 153, 255)
ICONS = {"sheep": (210, 200, 230), "boss": (120, 60, 140), "dot1": (90, 200, 60), "dot2": (230, 120, 30),
         "dot3": (160, 40, 40), "stun": (240, 200, 60)}


def icon(dr, x, y, size, kind, text=None, rim=INK):
    dr.rectangle([x, y, x + size - 1, y + size - 1], fill=rim)
    dr.rectangle([x + 1, y + 1, x + size - 2, y + size - 2], fill=ICONS[kind])
    # a swept quarter, the cooldown
    dr.pieslice([x + 1, y + 1, x + size - 2, y + size - 2], -90, 0, fill=(0, 0, 0, 150))
    if text:
        f = font(9 if size < 22 else 11)
        for dx, dy, c in ((1, 1, (0, 0, 0)), (0, 0, (255, 230, 50))):
            dr.text((x + size / 2 + dx, y + size / 2 + dy), text, font=f, fill=c, anchor="mm")


def cell(dr, x, y, w, h, name, col, hp, pcol=(0, 120, 220), value_right=4):
    power_h = 5 if h >= 40 else 4
    health_h = h - power_h - 1
    dr.rectangle([x, y, x + w - 1, y + h - 1], fill=WELL)
    dr.rectangle([x, y, x + int(w * hp) - 1, y + health_h - 1], fill=tuple(int(c * 0.55) for c in col))
    dr.rectangle([x, y + health_h, x + w - 1, y + health_h], fill=INK)
    dr.rectangle([x, y + health_h + 1, x + int(w * 0.7) - 1, y + h - 1], fill=pcol)
    for dx, dy, c in ((1, 1, (0, 0, 0)), (0, 0, TEXT)):
        dr.text((x + 4 + dx, y + 3 + dy), name, font=font(11), fill=c)
        dr.text((x + w - value_right + dx, y + health_h - 3 + dy), f"{int(hp * 100)}%", font=font(9), fill=c,
                anchor="rd")
    return health_h


def glow(dr, x, y, w, h, colour):
    dr.rectangle([x, y, x + w - 1, y + h - 1], outline=colour, width=3)


def box(cells_w, cells_h, rows, extra=0):
    w = 2 * EDGE + 2 * PAD + cells_w + extra
    h = 2 * EDGE + 2 * PAD + rows * cells_h + (rows - 1) * GAP
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    dr = ImageDraw.Draw(img)
    dr.rectangle([0, 0, w - 1, h - 1], fill=INK, outline=GOLD, width=EDGE)
    dr.rectangle([1, 1, w - 2, h - 2], outline=GOLD_D, width=1)
    return img, dr


def raid(style):
    W, H = 112, 36
    img, dr = box(W, H, 4)
    x0 = EDGE + PAD
    hps = [0.95, 0.62, 1.0, 0.41]
    for i in range(4):
        y = EDGE + PAD + i * (H + GAP)
        right = 4 if style == "A" or i in (0, 2) else 4 + 22
        hh = cell(dr, x0, y, W, H, NAMES[i], CLASSES[i], hps[i], value_right=right)
        size = 20
        cy = y + (hh - size) // 2
        cx = x0 + (W - size) // 2 if style == "A" else x0 + W - size - 3
        if i == 0:
            glow(dr, x0, y, W, H, CURSE)            # a curse you can take off
        elif i == 1:
            icon(dr, cx, cy, size, "sheep", "4")   # crowd control
        elif i == 3:
            icon(dr, cx, cy, size, "boss", "8", rim=(230, 38, 38))   # a boss debuff
    return img


def enemy(style, arena):
    W, H = (160, 40) if arena else (180, 40)
    size_in, size_out = 14, 18
    strip = 3 * size_out + 2 * 2 + 4 if style == "B" else 0
    img, dr = box(W, H, 3, strip)
    x0 = EDGE + PAD
    names = ["Arena 1", "Arena 2", "Arena 3"] if arena else ["High Warlord Naj'entus", "Supremus",
                                                                "Teron Gorefiend"]
    cols = [CLASSES[0], CLASSES[3], CLASSES[2]] if arena else [(196, 30, 58)] * 3
    hps = [0.9, 0.7, 0.5] if arena else [0.85, 0.92, 0.64]
    mine = [["dot1", "dot2", "dot3"], ["dot1"], ["dot2", "dot3"]]
    for i in range(3):
        y = EDGE + PAD + i * (H + GAP)
        hh = cell(dr, x0, y, W, H, names[i], cols[i], hps[i], (200, 30, 30) if not arena else (0, 120, 220))
        if style == "A":
            for k, kind in enumerate(mine[i]):
                dr_x = x0 + W - 2 - (k + 1) * size_in - k * 2
                icon(dr, dr_x, y + 2, size_in, kind)
        else:
            for k, kind in enumerate(mine[i]):
                icon(dr, x0 + W + 4 + k * (size_out + 2), y + (H - size_out) // 2, size_out, kind, "9")
        if arena and i == 1:
            icon(dr, x0 + (W - 22) // 2, y + (hh - 22) // 2, 22, "stun", "3")
    return img


def label(dr, x, y, text, size=16, fill=TEXT):
    dr.text((x, y), text, font=font(size), fill=fill)


def main():
    os.makedirs(OUT, exist_ok=True)
    panels = [
        ("Raid / Battleground  A: centre icon", raid("A")),
        ("Raid / Battleground  B: icon at the right end", raid("B")),
        ("Boss  A: your debuffs inside", enemy("A", False)),
        ("Boss  B: your debuffs beside", enemy("B", False)),
        ("Arena  A: inside, CC centre", enemy("A", True)),
        ("Arena  B: beside, CC centre", enemy("B", True)),
    ]
    big = [(t, p.resize((p.width * SCALE, p.height * SCALE), Image.NEAREST)) for t, p in panels]
    col_w = max(p.width for _, p in big) + 60
    rows = [big[0:2], big[2:4], big[4:6]]
    row_h = [max(p.height for _, p in r) + 70 for r in rows]
    img = Image.new("RGBA", (col_w * 2 + 40, sum(row_h) + 120), BG + (255,))
    dr = ImageDraw.Draw(img)
    label(dr, 30, 20, "Auras on the widget cells (shown 3x)", 24, GOLD_BRIGHT)
    label(dr, 30, 56, "row 1 cells: a curse you can dispel (glow), crowd control, none, a boss debuff", 14)
    y = 100
    for r, h in zip(rows, row_h):
        for k, (t, p) in enumerate(r):
            x = 30 + k * col_w
            label(dr, x, y, t)
            img.alpha_composite(p, (x, y + 34))
        y += h
    path = os.path.join(OUT, "cell-auras-draft.png")
    img.save(path)
    print(path)


if __name__ == "__main__":
    main()
