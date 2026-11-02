r"""Draft: the draggable group widgets (party, raid, boss, arena) in the format of
the user's 2026-11-01_23-10-17.png: one box, a title over each column, the
column's units stacked under it. The title is the grip that drags the box.

Two readings of the title, both in the console's ink and gold:
  A  a strip across the column's full width (the screenshot's)
  B  a tab, only as wide as its word, standing on the box's top edge

Each unit is ONE rectangle (the suite's rule): class-coloured health, a seam,
power under it, the name top-left. The raid shows one column per group in
use (two here), growing right to eight.
"""
import os
import subprocess
import sys

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "render")
FONT = os.path.join(HERE, "..", "..", "WoW", "Interface", "AddOns", "Medaluin", "media", "fonts",
                    "MarcellusSC-Regular.ttf")

INK = (18, 17, 16)
WELL = (22, 22, 26)
GOLD = (196, 165, 87)
GOLD_D = (138, 112, 52)
GOLD_BRIGHT = (224, 184, 74)
TEXT = (245, 240, 225)
BG = (40, 44, 52)

TITLE_H, EDGE, GAP, PAD = 18, 2, 3, 3

CLASSES = [(255, 125, 10), (64, 199, 235), (199, 156, 110), (244, 140, 186), (170, 211, 114),
           (255, 245, 105), (0, 112, 221), (135, 136, 238), (196, 30, 58), (255, 255, 255)]
NAMES = ["Nokamii", "Thalric", "Ahrymx", "Velis", "Brannoc", "Isolde", "Kerrin", "Mardu", "Ysolt", "Orrin"]
BOSSES = ["High Warlord Naj'entus", "Supremus", "Teron Gorefiend"]
ARENA = ["Arena 1", "Arena 2", "Arena 3"]


def font(size):
    return ImageFont.truetype(FONT, size)


def unit(dr, x, y, w, h, name, col, hp, pw, pcol=(0, 120, 220)):
    power_h = 4 if h < 50 else 6
    health_h = h - power_h - 1
    dr.rectangle([x, y, x + w - 1, y + h - 1], fill=WELL)
    dr.rectangle([x, y, x + int(w * hp) - 1, y + health_h - 1], fill=tuple(int(c * 0.55) for c in col))
    dr.rectangle([x, y + health_h, x + w - 1, y + health_h], fill=INK)
    dr.rectangle([x, y + health_h + 1, x + int(w * pw) - 1, y + h - 1], fill=pcol)
    for dx, dy, c in ((1, 1, (0, 0, 0)), (0, 0, TEXT)):
        dr.text((x + 4 + dx, y + 3 + dy), name, font=font(11), fill=c)
        dr.text((x + w - 4 + dx, y + health_h - 3 + dy), f"{int(hp * 100)}%", font=font(9), fill=c, anchor="rd")


def widget(titles, columns, cw, ch, style, boss=False):
    """titles: one per column; columns: lists of (name, colour, hp, pw)."""
    rows = max(len(c) for c in columns)
    n = len(columns)
    tab_room = TITLE_H if style == "B" else 0
    w = 2 * EDGE + 2 * PAD + n * cw + (n - 1) * GAP
    head = 0 if style == "B" else TITLE_H + 1
    h = tab_room + 2 * EDGE + 2 * PAD + head + rows * ch + (rows - 1) * GAP
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    dr = ImageDraw.Draw(img)
    top = tab_room
    dr.rectangle([0, top, w - 1, h - 1], fill=INK, outline=GOLD, width=EDGE)
    dr.rectangle([1, top + 1, w - 2, h - 2], outline=GOLD_D, width=1)
    for i, (title, col) in enumerate(zip(titles, columns)):
        x = EDGE + PAD + i * (cw + GAP)
        if style == "A":
            y = top + EDGE + PAD
            dr.rectangle([x, y, x + cw - 1, y + TITLE_H - 1], fill=(36, 31, 22))
            dr.line([x, y + TITLE_H, x + cw - 1, y + TITLE_H], fill=GOLD_D)
            dr.text((x + cw / 2, y + TITLE_H / 2), title, font=font(12), fill=GOLD_BRIGHT, anchor="mm")
            uy = y + TITLE_H + 1
        else:
            tw = int(font(12).getlength(title)) + 20
            tx = x + (cw - tw) // 2
            dr.polygon([(tx, top + 1), (tx + 5, 0), (tx + tw - 5, 0), (tx + tw, top + 1)], fill=(36, 31, 22),
                       outline=GOLD)
            dr.rectangle([tx + 1, top, tx + tw - 1, top + EDGE], fill=(36, 31, 22))
            dr.text((tx + tw / 2, top / 2 + 1), title, font=font(12), fill=GOLD_BRIGHT, anchor="mm")
            uy = top + EDGE + PAD
        for j, (name, c, hp, pw) in enumerate(col):
            unit(dr, x, uy + j * (ch + GAP), cw, ch, name, c, hp, pw, (200, 30, 30) if boss else (0, 120, 220))
    return img


def members(start, count):
    hp = [0.95, 0.62, 1.0, 0.88, 0.41, 0.77, 0.55, 1.0, 0.9, 0.3]
    return [(NAMES[(start + k) % 10], CLASSES[(start + k) % 10], hp[(start + k) % 10], 0.7) for k in range(count)]


def sheet(style):
    party = widget(["Party"], [members(0, 5)], 160, 56, style)
    raid = widget(["Group 1", "Group 2"], [members(0, 5), members(5, 5)], 112, 44, style)
    boss = widget(["Bosses"], [[(b, (196, 30, 58), hp, 1.0) for b, hp in zip(BOSSES, (0.85, 0.92, 0.64))]],
                  180, 40, style, boss=True)
    arena = widget(["Arena"], [[(a, CLASSES[k * 3], 0.9 - 0.2 * k, 0.6) for k, a in enumerate(ARENA)]],
                   160, 40, style)
    pieces = [party, raid, boss, arena]
    w = sum(p.width for p in pieces) + 40 * (len(pieces) + 1)
    h = max(p.height for p in pieces) + 70
    img = Image.new("RGBA", (w, h), BG + (255,))
    dr = ImageDraw.Draw(img)
    dr.text((20, 14), {"A": "A  title strip across each column", "B": "B  title as a tab on the top edge"}[style],
            font=font(18), fill=TEXT)
    x = 40
    for p in pieces:
        img.alpha_composite(p, (x, 50))
        x += p.width + 40
    return img


# ------------------------------------------------------------ the game's art
# The tab, in three slices: a slanted end, a middle that stretches to the
# word, the mirrored end. Its bottom TAB_OVER rows lie over the box's gold
# edge, so the tab opens into the box (widgets/box.lua reads TAB_*).
TAB_W, TAB_H, TAB_END, TAB_OVER = 64, 20, 8, 2
MEDIA = os.path.join(HERE, "..", "..", "WoW", "Interface", "AddOns", "Medaluin", "media", "widgets")


def tab_svg():
    fill, gold, dark = "#241f16", "#c4a557", "#8a7034"
    w, h, e = TAB_W, TAB_H, TAB_END - 2
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}">'
            f'<defs><linearGradient id="g" x1="0" y1="0" x2="0" y2="1">'
            f'<stop offset="0" stop-color="#fff0b0"/><stop offset="0.5" stop-color="{gold}"/>'
            f'<stop offset="1" stop-color="{dark}"/></linearGradient></defs>'
            f'<polygon points="0,{h} {e},1 {w - e},1 {w},{h}" fill="{fill}"/>'
            f'<polyline points="0.8,{h - TAB_OVER} {e + 0.5},1 {w - e - 0.5},1 {w - 0.8},{h - TAB_OVER}" '
            f'fill="none" stroke="url(#g)" stroke-width="1.6"/></svg>')


def export():
    os.makedirs(MEDIA, exist_ok=True)
    tmp = os.path.join(OUT, "_tab.png")
    os.makedirs(OUT, exist_ok=True)
    subprocess.run(["rsvg-convert", "-o", tmp], input=tab_svg().encode(), check=True)
    img = Image.open(tmp).convert("RGBA")
    os.remove(tmp)
    padded = Image.new("RGBA", (64, 32), (0, 0, 0, 0))
    padded.paste(img, (0, 0))
    png = os.path.join(MEDIA, "tab.png")
    padded.save(png)
    tga = os.path.join(MEDIA, "tab.tga")
    subprocess.run(["magick", png, "-define", "tga:compression=none", "-depth", "8", "-type", "TrueColorAlpha",
                    tga], check=True)
    os.remove(png)
    print(tga)


def main():
    if sys.argv[1:] == ["export"]:
        export()
        return
    os.makedirs(OUT, exist_ok=True)
    a, b = sheet("A"), sheet("B")
    out = Image.new("RGBA", (max(a.width, b.width), a.height + b.height), BG + (255,))
    out.alpha_composite(a, (0, 0))
    out.alpha_composite(b, (0, a.height))
    out = out.resize((out.width * 2, out.height * 2), Image.LANCZOS)
    path = os.path.join(OUT, "widgets-draft.png")
    out.save(path)
    print(path)


if __name__ == "__main__":
    main()
