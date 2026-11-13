r"""Draft: Medalluin's own settings window, after the user's
2026-11-01_23-50-36.png (Grid2's window: a tree down the left, the page's
options in framed groups laid out in columns), in the console's ink and gold.

Two readings of the way round, both on the Unit Frames page:
  A  the tree alone: every page a node (Console's pages under it), the page's
     groups as framed boxes, two controls a row
  B  the tree for the top pages, the Console's pages as tabs over the body
     (Grid2 has both: the tree and tabs)

And the Interface > AddOns > Medalluin page it leaves behind: what Medalluin
is, the slash commands, and one button that opens the window.
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "render")
FONTS = os.path.join(HERE, "..", "..", "WoW", "Interface", "AddOns", "Medalluin", "media", "fonts")
SERIF = os.path.join(FONTS, "MarcellusSC-Regular.ttf")
SANS = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"

INK = (18, 17, 16)
PANEL = (26, 24, 21)
WELL = (12, 12, 12)
SEL = (52, 42, 22)
GOLD = (196, 165, 87)
GOLD_D = (138, 112, 52)
GOLD_B = (224, 184, 74)
TEXT = (235, 230, 215)
DIM = (150, 144, 130)
RED = (120, 24, 20)
BG = (52, 60, 46)

W, H = 900, 600
TREE_W = 190


def f(size, serif=True):
    return ImageFont.truetype(SERIF if serif else SANS, size)


def frame(dr, box, fill=INK, edge=2):
    x0, y0, x1, y1 = box
    dr.rectangle(box, fill=fill, outline=GOLD, width=edge)
    dr.rectangle([x0 + edge, y0 + edge, x1 - edge, y1 - edge], outline=GOLD_D, width=1)


def checkbox(dr, x, y, label, on):
    dr.rectangle([x, y, x + 15, y + 15], fill=WELL, outline=GOLD_D)
    if on:
        dr.line([(x + 3, y + 8), (x + 6, y + 12), (x + 13, y + 3)], fill=GOLD_B, width=2)
    dr.text((x + 23, y + 8), label, font=f(12, False), fill=TEXT, anchor="lm")


def dropdown(dr, x, y, w, label, value):
    dr.text((x, y), label, font=f(11), fill=GOLD_B)
    y += 16
    dr.rectangle([x, y, x + w, y + 22], fill=WELL, outline=GOLD_D)
    dr.text((x + 8, y + 11), value, font=f(12, False), fill=TEXT, anchor="lm")
    ax = x + w - 12
    dr.polygon([(ax - 5, y + 9), (ax + 5, y + 9), (ax, y + 15)], fill=GOLD_B)


def button(dr, box, label, fill=SEL):
    x0, y0, x1, y1 = box
    dr.rectangle(box, fill=fill, outline=GOLD)
    dr.text(((x0 + x1) / 2, (y0 + y1) / 2), label, font=f(12), fill=GOLD_B, anchor="mm")


def group(dr, x, y, w, h, title):
    dr.rectangle([x, y + 8, x + w, y + h], outline=GOLD_D)
    tw = f(13).getlength(title)
    dr.rectangle([x + 10, y, x + 20 + tw, y + 16], fill=PANEL)
    dr.text((x + 15, y + 8), title, font=f(13), fill=GOLD_B, anchor="lm")


def window(dr, title):
    dr.rectangle([0, 0, W, H], fill=BG)
    frame(dr, [10, 20, W - 10, H - 10], fill=PANEL)
    tw = f(15).getlength(title) + 40
    tab = [(W - tw) / 2, 6, (W + tw) / 2, 34]
    frame(dr, tab, fill=INK)
    dr.text((W / 2, 20), title, font=f(15), fill=GOLD_B, anchor="mm")
    dr.text((W - 28, 44), "x", font=f(14, False), fill=GOLD_B, anchor="mm")
    # footer: the profile it is editing, Reload UI, Close
    dr.line([20, H - 52, W - 20, H - 52], fill=GOLD_D)
    dr.text((30, H - 31), "Profile: Medallion", font=f(12), fill=DIM, anchor="lm")
    button(dr, [W - 250, H - 44, W - 140, H - 18], "Reload UI")
    button(dr, [W - 130, H - 44, W - 30, H - 18], "Close", fill=RED)


def tree(dr, nodes, chosen):
    frame(dr, [24, 54, 24 + TREE_W, H - 62], fill=INK)
    y = 66
    for depth, name in nodes:
        if name == chosen:
            dr.rectangle([28, y - 2, 20 + TREE_W, y + 18], fill=SEL)
        size = 13 if depth == 0 else 12
        col = GOLD_B if depth == 0 else TEXT
        dr.text((36 + depth * 14, y + 8), name, font=f(size, depth == 0), fill=col, anchor="lm")
        y += 24


def unit_frames(dr, x0, y0, x1):
    """The Unit Frames page's groups, two controls a row."""
    cw = (x1 - x0 - 30) // 2
    c1, c2 = x0 + 12, x0 + 18 + cw
    group(dr, x0, y0, x1 - x0, 118, "Party")
    dropdown(dr, c1, y0 + 24, cw - 20, "Party layout", "Widget")
    dropdown(dr, c2, y0 + 24, cw - 20, "Fade out of range", "40 yards")
    checkbox(dr, c1, y0 + 80, "Show party pets", True)
    y = y0 + 132
    group(dr, x0, y, x1 - x0, 70, "Boss and arena")
    dropdown(dr, c1, y + 24, cw - 20, "Boss frames", "Vertical")
    dr.text((c2, y + 48), "Hold a box's tab to move it.", font=f(11, False), fill=DIM, anchor="lm")
    y += 84
    group(dr, x0, y, x1 - x0, 104, "Auras")
    checkbox(dr, c1, y + 26, "Dispel glow on frame borders", True)
    checkbox(dr, c2, y + 26, "Crowd control center icon", True)
    checkbox(dr, c1, y + 52, "Player buffs on health", True)
    checkbox(dr, c2, y + 52, "Boss debuffs", True)
    checkbox(dr, c1, y + 78, "Blizzard's buff and debuff rows", False)
    return y + 104


def tooltip(dr, x, y):
    lines = ["Party layout", "A box of party frames, under a Party tab,",
             "that you can drag anywhere."]
    frame(dr, [x, y, x + 270, y + 62], fill=WELL, edge=1)
    for i, t in enumerate(lines):
        dr.text((x + 10, y + 10 + i * 16), t, font=f(12 if i == 0 else 11, i == 0),
                fill=GOLD_B if i == 0 else TEXT)


def variant_a():
    img = Image.new("RGB", (W, H))
    dr = ImageDraw.Draw(img)
    window(dr, "Medalluin")
    tree(dr, [(0, "General"), (0, "Console"), (1, "Action Bar"), (1, "Paging"), (1, "Unit Frames"),
              (1, "Overhead"), (1, "Cast Bars"), (0, "Chat"), (0, "Side panel"), (0, "Bags")], "Unit Frames")
    x0, x1 = 24 + TREE_W + 14, W - 26
    frame(dr, [x0, 54, x1, H - 62], fill=PANEL)
    dr.text((x0 + 16, 74), "Unit Frames", font=f(18), fill=GOLD_B, anchor="lm")
    dr.text((x0 + 16, 96), "Kept per profile.", font=f(11, False), fill=DIM, anchor="lm")
    unit_frames(dr, x0 + 14, 116, x1 - 14)
    tooltip(dr, x1 - 300, 150)
    return img


def variant_b():
    img = Image.new("RGB", (W, H))
    dr = ImageDraw.Draw(img)
    window(dr, "Medalluin")
    tree(dr, [(0, "General"), (0, "Console"), (0, "Chat"), (0, "Side panel"), (0, "Bags")], "Console")
    x0, x1 = 24 + TREE_W + 14, W - 26
    tabs = ["Profile", "Action Bar", "Paging", "Unit Frames", "Overhead", "Cast Bars"]
    x = x0 + 12
    for t in tabs:
        tw = f(12).getlength(t) + 24
        on = t == "Unit Frames"
        dr.rectangle([x, 56, x + tw, 80], fill=PANEL if on else INK, outline=GOLD if on else GOLD_D)
        dr.text((x + tw / 2, 68), t, font=f(12), fill=GOLD_B if on else DIM, anchor="mm")
        x += tw + 4
    frame(dr, [x0, 80, x1, H - 62], fill=PANEL)
    dr.line([x0 + 12 + sum(f(12).getlength(t) + 28 for t in tabs[:3]) + 2, 80,
             x0 + 12 + sum(f(12).getlength(t) + 28 for t in tabs[:4]) - 2, 80], fill=PANEL, width=3)
    unit_frames(dr, x0 + 14, 100, x1 - 14)
    return img


def info_page():
    w, h = 640, 420
    img = Image.new("RGB", (w, h), (24, 24, 24))
    dr = ImageDraw.Draw(img)
    dr.text((20, 22), "Medalluin", font=f(26), fill=GOLD_B, anchor="lm")
    dr.text((20, 50), "Version 1.x  ·  by ahrymx", font=f(12, False), fill=DIM, anchor="lm")
    dr.line([20, 70, w - 20, 70], fill=GOLD_D)
    body = ["A console UI: the action bar, unit frames, overhead, chat,",
            "side panel and bags in one frame.", "",
            "Its options have a window of their own."]
    for i, t in enumerate(body):
        dr.text((20, 92 + i * 20), t, font=f(13, False), fill=TEXT, anchor="lm")
    button(dr, [20, 186, 240, 218], "Open Medalluin settings")
    dr.text((20, 252), "Slash commands", font=f(14), fill=GOLD_B, anchor="lm")
    cmds = [("/mdlui", "open the settings window"), ("/mdlui unit, bar, bags...", "open it on that page"),
            ("/mdlui kb", "bind keys"), ("/mdlui taint", "what blocked a click")]
    for i, (c, d) in enumerate(cmds):
        dr.text((30, 278 + i * 22), c, font=f(12, False), fill=GOLD, anchor="lm")
        dr.text((230, 278 + i * 22), d, font=f(12, False), fill=TEXT, anchor="lm")
    return img


MEDIA = os.path.join(HERE, "..", "..", "WoW", "Interface", "AddOns", "Medalluin", "media", "options")


def icon(draw):
    """A 32x32 icon in bright gold on clear, drawn at 4x and brought down."""
    big = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    draw(ImageDraw.Draw(big))
    return big.resize((32, 32), Image.LANCZOS)


def export():
    """The window's two drawn marks, the checkbox's tick and the dropdown's
    arrow (options/controls.lua), gold, so the game draws them untinted; and
    a tick and a cross for text, white."""
    os.makedirs(MEDIA, exist_ok=True)
    tick = icon(lambda d: d.line([(22, 66), (52, 98), (106, 28)], fill=GOLD_B + (255,), width=18, joint="curve"))
    arrow = icon(lambda d: d.polygon([(24, 44), (104, 44), (64, 92)], fill=GOLD_B + (255,)))
    # the tick and cross in a line of text (core.lua's ns.Tick, ns.Cross):
    # white, so the |T escape tints them each to its text; no font has them
    WHITE = (255, 255, 255, 255)
    mark = icon(lambda d: d.line([(22, 66), (52, 98), (106, 28)], fill=WHITE, width=18, joint="curve"))
    cross = icon(lambda d: (d.line([(34, 34), (94, 94)], fill=WHITE, width=16),
                            d.line([(94, 34), (34, 94)], fill=WHITE, width=16)))
    for name, img in (("check", tick), ("arrow", arrow), ("tick", mark), ("cross", cross)):
        path = os.path.join(MEDIA, name + ".tga")
        img.save(path, orientation=1)   # top-left first, as media/widgets/tab.tga
        print(path)


def main():
    if sys.argv[1:] == ["export"]:
        export()
        return
    os.makedirs(OUT, exist_ok=True)
    a, b, info = variant_a(), variant_b(), info_page()
    sheet = Image.new("RGB", (W * 2 + 30, H + 40 + 420 + 40), (30, 30, 30))
    dr = ImageDraw.Draw(sheet)
    for i, (img, label) in enumerate(((a, "A  tree only"), (b, "B  tree + tabs"))):
        x = 10 + i * (W + 10)
        dr.text((x, 20), label, font=f(16), fill=TEXT, anchor="lm")
        sheet.paste(img, (x, 40))
    dr.text((10, H + 60), "Interface > AddOns > Medalluin (both)", font=f(16), fill=TEXT, anchor="lm")
    sheet.paste(info, (10, H + 80))
    path = os.path.join(OUT, "settings-draft.png")
    sheet.save(path)
    print(path)


if __name__ == "__main__":
    main()
