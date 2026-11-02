r"""Draft: the unit-frame editor, after Cell_UnitFrames' editor (a window that
lists a frame's pieces and sets each one's place, size, font and format,
plus an edit mode that drags them on the live frames).

The user's calls (2026-11-02): the console's frames (player, target, the
console party: per profile) and the group widgets' cells (party, raid, boss,
arena: shared); a window with the controls, applied live, plus an edit mode;
position, size and font, shown/hidden and text format; its own window,
opened from Unit Frames and /mdlui edit. The preview (simulate.lua) runs
with it, so there is something to edit out of a group.

Two readings of the window:
  A  frames as tabs over the body; the frame's pieces down the left, the
     chosen piece's controls on the right
  B  one list down the left: each frame a heading (Console, per profile;
     Widgets, shared) with its pieces under it; the controls on the right

And edit mode on the live frames: a box round every piece of the frames the
editor is on, the chosen one bright; drag a box to move its piece, the arrow
keys nudge it a pixel. On the console the pieces mirror: the player's and
the target's are one layout, set as outer and inner, not left and right.
"""
import os

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "render")
FONTS = os.path.join(HERE, "..", "..", "WoW", "Interface", "AddOns", "Medaluin", "media", "fonts")
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
CELL = (22, 22, 26)

W, H = 760, 520


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


def slider(dr, x, y, w, label, value, at):
    dr.text((x, y), label, font=f(11), fill=GOLD_B)
    dr.text((x + w, y), str(value), font=f(11, False), fill=TEXT, anchor="ra")
    y += 22
    dr.rectangle([x, y, x + w, y + 4], fill=WELL, outline=GOLD_D)
    k = x + int(w * at)
    dr.rectangle([k - 4, y - 5, k + 4, y + 9], fill=GOLD, outline=GOLD_B)


def button(dr, box, label, fill=SEL, lit=False):
    x0, y0, x1, y1 = box
    dr.rectangle(box, fill=GOLD_D if lit else fill, outline=GOLD_B if lit else GOLD)
    dr.text(((x0 + x1) / 2, (y0 + y1) / 2), label, font=f(12), fill=INK if lit else GOLD_B, anchor="mm")


def anchors(dr, x, y, chosen):
    """The nine points as a grid: the piece's anchor on what it hangs from."""
    dr.text((x, y), "Anchor", font=f(11), fill=GOLD_B)
    y += 16
    dr.rectangle([x, y, x + 66, y + 42], fill=WELL, outline=GOLD_D)
    for r in range(3):
        for c in range(3):
            cx, cy = x + 9 + c * 24, y + 7 + r * 14
            on = (r, c) == chosen
            dr.rectangle([cx - 4, cy - 4, cx + 4, cy + 4], fill=GOLD_B if on else PANEL, outline=GOLD_D)


def window(dr, title):
    dr.rectangle([0, 0, W, H], fill=BG)
    frame(dr, [10, 20, W - 10, H - 10], fill=PANEL)
    tw = f(15).getlength(title) + 40
    frame(dr, [(W - tw) / 2, 6, (W + tw) / 2, 34], fill=INK)
    dr.text((W / 2, 20), title, font=f(15), fill=GOLD_B, anchor="mm")
    dr.text((W - 28, 44), "x", font=f(14, False), fill=GOLD_B, anchor="mm")
    # footer: edit mode, the preview, reset; what is being edited and whose
    dr.line([20, H - 52, W - 20, H - 52], fill=GOLD_D)
    button(dr, [30, H - 44, 150, H - 18], "Edit mode", lit=True)
    button(dr, [160, H - 44, 260, H - 18], "Preview", lit=True)
    button(dr, [W - 250, H - 44, W - 140, H - 18], "Reset frame")
    button(dr, [W - 130, H - 44, W - 30, H - 18], "Close", fill=RED)


def pieces_list(dr, x0, y0, x1, y1, items, chosen, headings=()):
    frame(dr, [x0, y0, x1, y1], fill=INK)
    y = y0 + 10
    for depth, name in items:
        if name in headings:
            dr.text((x0 + 10, y + 8), name, font=f(13), fill=GOLD_B, anchor="lm")
            y += 24
            continue
        if name == chosen:
            dr.rectangle([x0 + 4, y - 2, x1 - 4, y + 18], fill=SEL)
        hidden = name.endswith("(off)")
        dr.text((x0 + 14 + depth * 12, y + 8), name, font=f(12, depth == 0), fill=DIM if hidden else TEXT,
                anchor="lm")
        y += 22


def controls(dr, x0, y0, x1, title, scope):
    dr.text((x0, y0), title, font=f(16), fill=GOLD_B)
    dr.text((x0, y0 + 24), scope, font=f(11, False), fill=DIM)
    y = y0 + 52
    cw = (x1 - x0 - 24) // 2
    c2 = x0 + cw + 24
    checkbox(dr, x0, y, "Shown", True)
    y += 30
    anchors(dr, x0, y, (1, 0))
    dropdown(dr, c2, y, cw, "On", "Health bar")
    y += 70
    slider(dr, x0, y, cw, "Outer offset", 6, 0.55)
    slider(dr, c2, y, cw, "Up offset", 0, 0.5)
    y += 52
    slider(dr, x0, y, cw, "Font size", 12, 0.45)
    dropdown(dr, c2, y, cw, "Outline", "Thin")
    y += 58
    dropdown(dr, x0, y, cw, "Format", "Abbreviated")
    slider(dr, c2, y, cw, "Longest name", "12 letters", 0.4)


def variant_a():
    img = Image.new("RGB", (W, H))
    dr = ImageDraw.Draw(img)
    window(dr, "Unit Frame Editor")
    tabs = ["Player · Target", "Party", "Party widget", "Raid", "Boss", "Arena"]
    x = 30
    for i, t in enumerate(tabs):
        tw = f(12).getlength(t) + 24
        box = [x, 46, x + tw, 70]
        dr.rectangle(box, fill=SEL if i == 0 else INK, outline=GOLD if i == 0 else GOLD_D)
        dr.text((x + tw / 2, 58), t, font=f(12), fill=GOLD_B if i == 0 else DIM, anchor="mm")
        x += tw + 4
    dr.line([24, 70, W - 24, 70], fill=GOLD)
    items = [(0, "Name"), (0, "Health value"), (0, "Power value"), (0, "Crowd control"), (0, "Boss debuff"),
             (0, "Your buffs")]
    pieces_list(dr, 30, 82, 210, H - 62, items, "Name")
    controls(dr, 232, 86, W - 34, "Name", "Player and target, mirrored. Per profile: Medallion.")
    return img


def variant_b():
    img = Image.new("RGB", (W, H))
    dr = ImageDraw.Draw(img)
    window(dr, "Unit Frame Editor")
    heads = ("Console · per profile", "Widgets · shared")
    items = [(0, heads[0]), (0, "Player · Target"), (1, "Name"), (1, "Health value"), (1, "Power value"),
             (1, "Auras"), (0, "Party"), (0, heads[1]), (0, "Party"), (0, "Raid"), (0, "Boss"), (0, "Arena")]
    pieces_list(dr, 30, 46, 230, H - 62, items, "Name", heads)
    controls(dr, 252, 52, W - 34, "Player · Target  >  Name", "Mirrored. Per profile: Medallion.")
    return img


def cell(dr, x, y, w, h, name, col, hp, value):
    dr.rectangle([x, y, x + w - 1, y + h - 1], fill=CELL)
    hh = h - 6
    dr.rectangle([x, y, x + int(w * hp) - 1, y + hh - 1], fill=tuple(int(c * 0.55) for c in col))
    dr.rectangle([x, y + hh + 1, x + int(w * 0.7) - 1, y + h - 1], fill=(0, 120, 220))
    dr.text((x + 4, y + 3), name, font=f(11, False), fill=TEXT)
    dr.text((x + w - 4, y + hh - 3), value, font=f(9, False), fill=DIM, anchor="rd")


def dashed(dr, box, colour, label=None, lit=False):
    x0, y0, x1, y1 = box
    step = 4
    for x in range(int(x0), int(x1), step * 2):
        dr.line([x, y0, min(x + step, x1), y0], fill=colour)
        dr.line([x, y1, min(x + step, x1), y1], fill=colour)
    for y in range(int(y0), int(y1), step * 2):
        dr.line([x0, y, x0, min(y + step, y1)], fill=colour)
        dr.line([x1, y, x1, min(y + step, y1)], fill=colour)
    if lit:
        dr.rectangle(box, outline=colour, width=2)
    if label:
        dr.text((x0, y0 - 2), label, font=f(9, False), fill=colour, anchor="ld")


def edit_mode():
    """A party widget's cell and the console's player frame, as edit mode
    draws them: every piece boxed, the chosen one bright."""
    S = 3
    w, h = 380, 150
    img = Image.new("RGB", (w, h), BG)
    dr = ImageDraw.Draw(img)
    # the party widget, one cell
    x, y = 12, 30
    frame(dr, [x - 5, y - 5, x + 165, y + 45], fill=INK)
    cell(dr, x, y, 160, 40, "Nokamii", (255, 125, 10), 0.82, "82%")
    dashed(dr, [x + 3, y + 2, x + 50, y + 15], GOLD_B, "Name", lit=True)
    dashed(dr, [x + 136, y + 24, x + 157, y + 34], GOLD_D)
    dashed(dr, [x + 70, y + 7, x + 90, y + 27], GOLD_D)
    dr.text((x, y + 58), "party widget: Name chosen;", font=f(9, False), fill=TEXT)
    dr.text((x, y + 70), "value and the centre icon boxed", font=f(9, False), fill=TEXT)
    # the console's player frame (a straight stand-in for the vial)
    x = 200
    dr.polygon([(x, y), (x + 160, y), (x + 172, y + 12), (x + 172, y + 40), (x, y + 40)], fill=INK, outline=GOLD)
    dr.rectangle([x + 2, y + 8, x + 130, y + 30], fill=(40, 120, 40))
    dr.rectangle([x + 2, y + 32, x + 100, y + 38], fill=(0, 120, 220))
    dr.text((x + 8, y + 19), "Ahrymx", font=f(11, False), fill=TEXT, anchor="lm")
    dr.text((x + 160, y + 19), "100%", font=f(9, False), fill=DIM, anchor="rm")
    dashed(dr, [x + 6, y + 12, x + 52, y + 26], GOLD_B, "Name  (outer)", lit=True)
    dashed(dr, [x + 134, y + 13, x + 162, y + 25], GOLD_D)
    dr.text((x, y + 58), "player: the target's name", font=f(9, False), fill=TEXT)
    dr.text((x, y + 70), "moves with it, mirrored", font=f(9, False), fill=TEXT)
    dr.text((10, 8), "Edit mode on the live frames (shown 3x). Drag a box; arrows nudge 1 px.",
            font=f(10, False), fill=GOLD_B)
    return img.resize((w * S, h * S), Image.NEAREST)


def main():
    os.makedirs(OUT, exist_ok=True)
    a, b, e = variant_a(), variant_b(), edit_mode()
    sheet = Image.new("RGB", (W * 2 + 60, H + e.height + 120), BG)
    dr = ImageDraw.Draw(sheet)
    dr.text((20, 14), "A  frames as tabs, pieces down the left", font=f(18), fill=GOLD_B)
    dr.text((W + 40, 14), "B  one list: frames and their pieces", font=f(18), fill=GOLD_B)
    sheet.paste(a, (20, 44))
    sheet.paste(b, (W + 40, 44))
    sheet.paste(e, (20, H + 90))
    path = os.path.join(OUT, "editor-draft.png")
    sheet.save(path)
    print(path)


if __name__ == "__main__":
    main()
