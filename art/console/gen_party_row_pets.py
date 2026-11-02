r"""Draft: the light console's pets under their owners, in the default
console's stone trapezoid (pet-bracket, gen_pet_bracket.py), instead of a
share of the owner's slot. The row's frames then always fill their slots.

  A  the bracket as wide as its owner (the default console's rule: the pet
     spans its owner's TOPLEFT..TOPRIGHT, 8 below), stretched 129 -> ~146
  B  the bracket at its own width (129), centred under its owner

The row (mirrored, 1 2 | 3 4) at its game place: its foot is 37 above the
console's foot and 57 above the screen's, so a bracket (8 + 18) fits. party2
and party3 have pets. Shown 2x.
"""
import os

from PIL import Image, ImageDraw

import gen_light_console as G
from gen_party_row_mirror import BG, GOLD, font, member

HERE = os.path.dirname(os.path.abspath(__file__))
SCALE = 2
BRACKET = Image.open(os.path.join(HERE, "render", "pet-bracket.png")).convert("RGBA")
GAP, PET_H = 8, 18
PETS = {2: "W. Elemental", 3: "Imp"}
SIDES = (-1, -1, 1, 1)
FOOT = G.ROW_TOP + G.ROW_H                 # 119 below the console's top
SCREEN = 156 + 20                         # the console's height and its gap: the screen's foot


def bracket():
    a = BRACKET.getchannel("A")
    return BRACKET.crop(a.getbbox())


def pet(img, l, r, top, name, side):
    w = r - l
    art = bracket().resize((w, PET_H), Image.Resampling.LANCZOS)
    img.paste(art, (l, top), art)
    dr = ImageDraw.Draw(img)
    pad = 14
    fill = int((w - 2 * pad) * 0.9)
    x0 = l + pad if side == -1 else r - pad - fill
    dr.rectangle([x0, top + 4, x0 + fill - 1, top + PET_H - 5], fill=(60, 150, 190))
    f = font(8)
    dr.text((l + pad + 3 if side == -1 else r - pad - 3, top + PET_H // 2), name, font=f, fill=(20, 20, 20),
            anchor="lm" if side == -1 else "rm")


def row(img, y0, variant):
    frames = G.party_row_boxes()
    dr = ImageDraw.Draw(img)
    cx = 20 + G.CONSOLE_W // 2
    run = int(G.ROW_RUN)
    top, bot = y0 + G.ROW_TOP, y0 + FOOT
    l, r = 20, 20 + G.CONSOLE_W
    dr.rectangle([l, y0, r - 1, top - 1], fill=(52, 50, 46))          # the console above, schematic
    dr.text((cx, y0 + G.ROW_TOP // 2), "console", font=font(10), fill=(110, 105, 95), anchor="mm")
    dr.polygon([(l, top), (r, top), (r - run, bot), (l + run, bot)], fill=(28, 26, 22), outline=GOLD)
    dr.line([(l - 10, y0 + SCREEN), (r + 10, y0 + SCREEN)], fill=(200, 60, 60))
    dr.text((r + 12, y0 + SCREEN), "screen", font=font(8), fill=(200, 60, 60), anchor="lm")
    for i in range(4):
        fl, fr, ft, fb = frames[i]
        box = (cx + fl, cx + fr, y0 - ft, y0 - fb)
        member(dr, box, i + 1, SIDES[i])
        if i + 1 in PETS:
            pl, pr = box[0], box[1]
            if variant == "B":
                w = 129
                mid = (pl + pr) // 2
                pl, pr = mid - w // 2, mid - w // 2 + w
            pet(img, pl, pr, box[3] + GAP, PETS[i + 1], SIDES[i])


def main():
    W = G.CONSOLE_W + 90
    band = SCREEN + 30
    H = 10 + 2 * band
    img = Image.new("RGBA", (W, H), BG + (255,))
    dr = ImageDraw.Draw(img)
    for k, (v, label) in enumerate((("A", "A  as wide as its owner"), ("B", "B  its own width, centred"))):
        y = 10 + k * band
        dr.text((20, y), label, font=font(11), fill=GOLD)
        row(img, y + 16, v)
    img = img.resize((W * SCALE, H * SCALE), Image.Resampling.NEAREST)
    out = os.path.join(HERE, "render", "party-row-pets-draft.png")
    img.save(out)
    print(out)


if __name__ == "__main__":
    main()
