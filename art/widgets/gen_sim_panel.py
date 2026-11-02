r"""Draft: unit-frame simulation for every frame, not only the party.

Today the panel (console/simulate.lua) sets the party's Dead and In range,
the boss count and two checks; the raid is always ten, the arena three, the
overhead's pet, focus and target of target fixed, the player and target not
simulated at all, and each unit's auras fixed.

  A  A panel with a tab per family: Console (player, target), Party, Raid,
     Enemies (bosses, arena), Overhead (pet, focus, target of target). Each
     tab: how many, then a grid with a column per unit and a row per state,
     then the auras that family's frames show
  B  The same controls inside the unit-frame editor's window, under its
     frame tabs: whichever frame the editor has open is the one simulated,
     so the frame being styled and its situation are set in one place

The states: Health (click cycles 100 / 60 / 25 / 0%), Dead, Offline, Out of
range, Pet; the auras: Dispel, CC, Boss debuff, Your buffs, Your debuffs.
Shown 2x.
"""
import os

from PIL import Image, ImageDraw

from gen_widgets import BG, GOLD, GOLD_BRIGHT, GOLD_D, INK, TEXT, font

HERE = os.path.dirname(os.path.abspath(__file__))
SCALE = 2
DIM = (150, 145, 130)
CLASS = [(255, 255, 255), (64, 199, 235), (199, 156, 110), (255, 245, 105)]


def frame(dr, x, y, w, h, title=None):
    dr.rectangle([x, y, x + w - 1, y + h - 1], fill=GOLD_D)
    dr.rectangle([x + 1, y + 1, x + w - 2, y + h - 2], fill=INK)
    if title:
        dr.text((x + 8, y + 7), title, font=font(11), fill=GOLD_BRIGHT)


def button(dr, x, y, w, label, lit=False, off=False, h=18, size=10):
    dr.rectangle([x, y, x + w - 1, y + h - 1], fill=GOLD_D)
    dr.rectangle([x + 1, y + 1, x + w - 2, y + h - 2], fill=(110, 90, 42) if lit else INK)
    col = (90, 88, 80) if off else GOLD_BRIGHT if lit else TEXT
    dr.text((x + w // 2, y + h // 2), label, font=font(size), fill=col, anchor="mm")


def label(dr, x, y, text):
    dr.text((x, y + 9), text, font=font(10), fill=DIM, anchor="lm")


def tabs(dr, x, y, names, at, w):
    tw = (w - 2 * (len(names) - 1)) // len(names)
    for i, n in enumerate(names):
        button(dr, x + i * (tw + 2), y, tw, n, lit=i == at, size=9)


def body(dr, x, y, w):
    """The Party tab: count, member grid, auras, checks. Returns its height."""
    col0, cw = 96, 36
    r = y
    label(dr, x, r, "Members")
    button(dr, x + col0, r, 22, "-")
    button(dr, x + col0 + 26, r, 60, "4")
    button(dr, x + col0 + 90, r, 22, "+")
    r += 26
    for i in range(4):
        dr.text((x + col0 + i * cw + 16, r + 6), "P%d" % (i + 1), font=font(10), fill=CLASS[i], anchor="mm")
    r += 16
    rows = [("Health", ["100", "60", "25", "100"]), ("Dead", [0, 0, 1, 0]), ("Offline", [0, 0, 0, 1]),
            ("Out of range", [0, 1, 0, 0]), ("Pet", [0, 1, 1, 0])]
    for name, vals in rows:
        label(dr, x, r, name)
        for i, v in enumerate(vals):
            if isinstance(v, str):
                button(dr, x + col0 + i * cw, r, 32, v)
            else:
                button(dr, x + col0 + i * cw, r, 32, "✓" if v else "", lit=bool(v))
        r += 22
    r += 6
    dr.line([(x, r - 3), (x + w - 1, r - 3)], fill=GOLD_D)
    label(dr, x, r, "Auras")
    r += 20
    aw = (w - 4 * 3) // 5
    for i, (n, on) in enumerate((("Dispel", 1), ("CC", 1), ("Boss", 1), ("Buffs", 1), ("Debuffs", 0))):
        button(dr, x + i * (aw + 3), r, aw, n, lit=bool(on), size=9)
    r += 26
    dr.line([(x, r - 3), (x + w - 1, r - 3)], fill=GOLD_D)
    half = (w - 4) // 2
    button(dr, x, r + 2, half, "Ready check")
    button(dr, x + half + 4, r + 2, half, "Role check")
    r += 24
    return r - y


def variant_a(img, x, y):
    dr = ImageDraw.Draw(img)
    W = 262
    frame(dr, x, y, W, 360, "Simulated frames")
    tabs(dr, x + 8, y + 26, ["Console", "Party", "Raid", "Enemies", "Overhead"], 1, W - 16)
    h = body(dr, x + 8, y + 54, W - 16)
    button(dr, x + 8, y + 54 + h + 6, W - 16, "End simulation")


def variant_b(img, x, y):
    dr = ImageDraw.Draw(img)
    W = 520
    frame(dr, x, y, W, 360, "Medalluin · Unit frames")
    tabs(dr, x + 8, y + 26, ["Player · Target", "Party", "Party widget", "Raid", "Boss", "Arena"], 1, W - 16)
    # the editor's pieces list and controls, schematic
    frame(dr, x + 8, y + 52, 120, 300)
    for i, p in enumerate(["Name", "Health value", "Role", "Ready check", "Crowd control", "Boss debuff",
                           "Your buffs"]):
        dr.text((x + 16, y + 62 + i * 18), p, font=font(10), fill=GOLD_BRIGHT if i == 0 else TEXT)
    frame(dr, x + 134, y + 52, 110, 300)
    dr.text((x + 189, y + 190), "the piece's\ncontrols", font=font(10), fill=DIM, anchor="mm", align="center")
    # the simulation strip, for the open frame
    sx = x + 250
    frame(dr, sx, y + 52, W - 258, 300)
    dr.text((sx + 8, y + 58), "Simulate: Party", font=font(10), fill=GOLD_BRIGHT)
    body(dr, sx + 8, y + 76, W - 274)


def main():
    W, H = 20 + 262 + 30 + 520 + 20, 420
    img = Image.new("RGB", (W, H), BG)
    dr = ImageDraw.Draw(img)
    dr.text((20, 10), "A  A panel, a tab per family", font=font(12), fill=GOLD)
    variant_a(img, 20, 34)
    dr.text((312, 10), "B  In the unit-frame editor, for the frame it has open", font=font(12), fill=GOLD)
    variant_b(img, 312, 34)
    img = img.resize((W * SCALE, H * SCALE), Image.Resampling.NEAREST)
    out = os.path.join(HERE, "render", "sim-panel-draft.png")
    img.save(out)
    print(out)


if __name__ == "__main__":
    main()
