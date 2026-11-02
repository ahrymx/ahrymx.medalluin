r"""Draft: a dead unit's frame. The health well takes the dead colour (a
colour picker, Unit Frames), and a stack stands in the middle of it:

    [wings]   the new resurrect icon (wings.png), gold
    [timer]   how long the unit has been dead
    [name]

Three takes on the "special art" under the stack:
  A  Shroud   the dead colour, flat, edge to edge
  B  Hatch    the dead colour with faint diagonal hatching, a tomb's stone
  C  Vignette the dead colour darkening to its edges, a thin gold line inside

Dead, the power bar is empty, so the art and the stack take the whole
frame. Each on the console's party window (129x43), a raid cell (112x36) and a
boss cell (180x40). Drawn at the game's size, then shown 3x.
"""
import os

from PIL import Image, ImageDraw, ImageFilter

from gen_widgets import GOLD, GOLD_BRIGHT, GOLD_D, INK, TEXT, WELL, font

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "render")
WINGS = os.path.join(HERE, "..", "console", "wings.png")
SCALE = 3
DEAD = (64, 66, 74)  # the default dead colour

FRAMES = [("Party (console)", 129, 43, 9), ("Raid cell", 112, 36, 4), ("Boss cell", 180, 40, 5)]
WHO = [("Thalric", (64, 199, 235), "0:42"), ("Velis", (244, 140, 186), "3:07"), ("Ysolt", (170, 211, 114), "12:55")]


def wings(size):
    src = Image.open(WINGS).convert("RGBA")
    mask = src.getchannel("A")  # a black glyph: its alpha is the shape
    mask = mask.crop(mask.getbbox())
    side = max(mask.size) + 40
    sq = Image.new("L", (side, side), 0)
    sq.paste(mask, ((side - mask.size[0]) // 2, (side - mask.size[1]) // 2))
    gold = Image.new("RGBA", sq.size, GOLD_BRIGHT + (255,))
    gold.putalpha(sq)
    # a dark rim so the gold reads on any dead colour
    rim = Image.new("RGBA", sq.size, (0, 0, 0, 255))
    rim.putalpha(sq.filter(ImageFilter.MaxFilter(15)))
    out = Image.alpha_composite(rim, gold)
    return out.resize((size, size), Image.Resampling.LANCZOS)


def art(img, x, y, w, h, style):
    dr = ImageDraw.Draw(img)
    dr.rectangle([x, y, x + w - 1, y + h - 1], fill=DEAD)
    if style == "B":
        layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
        ld = ImageDraw.Draw(layer)
        for k in range(-h, w, 6):
            ld.line([(x + k, y + h - 1), (x + k + h, y)], fill=(255, 255, 255, 14), width=1)
        crop = Image.new("L", img.size, 0)
        ImageDraw.Draw(crop).rectangle([x, y, x + w - 1, y + h - 1], fill=255)
        layer.putalpha(Image.composite(layer.getchannel("A"), Image.new("L", img.size, 0), crop))
        img.alpha_composite(layer)
    elif style == "C":
        layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
        ld = ImageDraw.Draw(layer)
        for i in range(6):
            ld.rectangle([x + i, y + i, x + w - 1 - i, y + h - 1 - i], outline=(0, 0, 0, 70 - i * 11))
        img.alpha_composite(layer)
        ImageDraw.Draw(img).rectangle([x + 1, y + 1, x + w - 2, y + h - 2], outline=GOLD_D)


ICONS = []  # (x, y, size): pasted after the 3x, at that resolution


def frame(img, x, y, w, h, power, who, style):
    # dead, the power is empty: the whole frame is the dead art
    art(img, x, y, w, h, style)
    dr = ImageDraw.Draw(img)
    name, col, timer = who
    icon = 16 if h < 40 else 18
    fn, ft = font(10), font(8)
    stack = icon + 8 + 10
    top = y + (h - stack) // 2
    ICONS.append((x + w // 2 - icon // 2, top, icon))
    cx = x + w // 2
    for dx, dy, c in ((1, 1, (0, 0, 0)), (0, 0, (210, 205, 190))):
        dr.text((cx + dx, top + icon + 4 + dy), timer, font=ft, fill=c, anchor="mm")
    nc = tuple(int(c * 0.8) for c in col)
    for dx, dy, c in ((1, 1, (0, 0, 0)), (0, 0, nc)):
        dr.text((cx + dx, top + icon + 8 + 5 + dy), name, font=fn, fill=c, anchor="mm")


def main():
    cols = 3
    pad = 10
    label_h = 14
    col_w = max(f[1] for f in FRAMES) + pad
    row_h = max(f[2] for f in FRAMES) + label_h + pad
    W = pad + 3 * col_w + 40
    H = 20 + 3 * (row_h + 16)
    img = Image.new("RGBA", (W, H), (40, 44, 52, 255))
    dr = ImageDraw.Draw(img)
    names = {"A": "A  Shroud", "B": "B  Hatch", "C": "C  Vignette"}
    for r, style in enumerate("ABC"):
        y0 = 6 + r * (row_h + 16)
        dr.text((pad, y0), names[style], font=font(11), fill=GOLD)
        for c, (label, w, h, power) in enumerate(FRAMES):
            x = 40 + c * col_w
            dr.text((x, y0 + 16), label, font=font(8), fill=(150, 150, 150))
            frame(img, x, y0 + 16 + label_h, w, h, power, WHO[c], style)
    img = img.resize((W * SCALE, H * SCALE), Image.Resampling.NEAREST)
    for x, y, size in ICONS:
        img.alpha_composite(wings(size * SCALE), (x * SCALE, y * SCALE))
    img.save(os.path.join(OUT, "dead-draft.png"))


if __name__ == "__main__":
    main()
