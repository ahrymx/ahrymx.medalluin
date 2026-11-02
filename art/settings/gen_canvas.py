r"""Draft: the unit-frame editor's edit mode as a canvas window (2026-11-02).

The user: "Edit mode should become a preview/canvas within the Unit Frame
Editor window, instead of on the live/simulated frames", then: "The Edit
Mode button stays. When pressed, a canvas window opens with the current
page/element adjustable via dragging. Attach a tree of elements onto the
left side of this canvas window to switch the element."

So: the editor keeps its footer's Edit mode button; it opens a second
window, docked to the editor's right. Down its left side a tree, the frames
with the chosen one open on its pieces; the rest of it the canvas: the
chosen frame drawn as its buttons have it now (a copy, read off the real
button after every change), every piece boxed, the chosen one bright. Drag
a box to move its piece, the arrow keys nudge it; the frames on screen
follow. A mirrored frame shows both copies, one over the other, so the
mirror can be seen at a size that can be grabbed.
"""
import os

from PIL import Image, ImageDraw

import gen_editor as g

W, H = 600, 340
TREE_W = 170


def tree(dr, x0, y0, x1, y1):
    g.frame(dr, [x0, y0, x1, y1], fill=g.INK)
    frames = ["Player · Target", "Party", "Party widget", "Raid", "Boss", "Arena"]
    pieces = ["Name", "Health value", "Power value", "Crowd control", "Boss debuff", "Your buffs"]
    y = y0 + 8
    for i, name in enumerate(frames):
        open_ = i == 0
        dr.text((x0 + 10, y + 9), ("v " if open_ else "> ") + name, font=g.f(12), fill=g.GOLD_B if open_ else g.DIM,
                anchor="lm")
        y += 20
        if open_:
            for k, p in enumerate(pieces):
                if k == 0:
                    dr.rectangle([x0 + 4, y, x1 - 4, y + 18], fill=g.SEL)
                dr.text((x0 + 26, y + 9), p, font=g.f(11), fill=g.GOLD_B if k == 0 else g.TEXT, anchor="lm")
                if k in (0, 1):
                    dr.rectangle([x1 - 14, y + 7, x1 - 10, y + 11], fill=g.GOLD)
                y += 19


def copy(dr, x, y, w, h, side, name, value, col):
    dr.rectangle([x, y, x + w, y + h], fill=g.CELL, outline=g.GOLD_D)
    ph = int(h * 0.22)
    dr.rectangle([x + 1, y + 1, x + w - 1, y + h - ph - 1], fill=col)
    dr.rectangle([x + 1, y + h - ph, x + w - 1, y + h - 1], fill=(0, 90, 190))
    outer, inner = (x, x + w) if side < 0 else (x + w, x)
    nx = outer - side * 16
    mid = y + (h - ph) / 2
    fn = g.f(22, False)
    dr.text((nx, mid), name, font=fn, fill=g.TEXT, anchor="lm" if side < 0 else "rm")
    nw = fn.getlength(name)
    g.dashed(dr, [min(nx, nx - side * nw) - 3, mid - 14, max(nx, nx - side * nw) + 3, mid + 14], g.GOLD_B,
             "Name" if side < 0 else None, lit=True)
    vx = inner + side * 70
    fv = g.f(18, False)
    dr.text((vx, mid), value, font=fv, fill=g.TEXT, anchor="rm" if side < 0 else "lm")
    vw = fv.getlength(value)
    g.dashed(dr, [min(vx, vx + side * vw) - 3, mid - 12, max(vx, vx + side * vw) + 3, mid + 12], g.GOLD_D)
    px = x + w / 2
    dr.text((px, y + h - ph / 2), "60 | 60%", font=g.f(12, False), fill=g.TEXT, anchor="mm")
    g.dashed(dr, [px - 32, y + h - ph + 2, px + 32, y + h - 2], g.GOLD_D)
    for k in range(3):
        ax = outer - side * (4 + k * 24)
        g.dashed(dr, [min(ax, ax - side * 20), y - 24, max(ax, ax - side * 20), y - 4], g.DIM)


def canvas_window():
    img = Image.new("RGB", (W, H), g.BG)
    dr = ImageDraw.Draw(img)
    g.frame(dr, [0, 14, W - 1, H - 1], fill=g.PANEL)
    title = "Edit mode"
    tw = g.f(15).getlength(title) + 40
    g.frame(dr, [(W - tw) / 2, 0, (W + tw) / 2, 28], fill=g.INK)
    dr.text((W / 2, 14), title, font=g.f(15), fill=g.GOLD_B, anchor="mm")
    dr.text((W - 18, 34), "x", font=g.f(14, False), fill=g.GOLD_B, anchor="mm")
    tree(dr, 12, 44, 12 + TREE_W, H - 14)
    x0, y0, x1, y1 = 12 + TREE_W + 10, 44, W - 12, H - 14
    g.frame(dr, [x0, y0, x1, y1], fill=g.WELL)
    dr.text((x0 + 10, y0 + 8), "Player · Target  >  Name", font=g.f(12), fill=g.GOLD_B)
    dr.text((x1 - 10, y1 - 8), "drag a box · arrows nudge · the frames on screen follow", font=g.f(10, False),
            fill=g.DIM, anchor="rd")
    cw = x1 - x0 - 40
    copy(dr, x0 + 20, y0 + 64, cw, 72, -1, "Ahrymx", "100%", (60, 150, 60))
    copy(dr, x0 + 20, y0 + 182, cw, 72, 1, "Defias Pillager", "82%", (150, 40, 30))
    dr.text((x0 + 20, y0 + 141), "player: the left copy", font=g.f(10, False), fill=g.DIM)
    dr.text((x0 + 20, y0 + 259), "target: its mirror", font=g.f(10, False), fill=g.DIM)
    return img


def main():
    os.makedirs(g.OUT, exist_ok=True)
    editor = g.variant_a().resize((g.W // 2, g.H // 2), Image.LANCZOS)
    cw = canvas_window()
    sheet = Image.new("RGB", (editor.width + cw.width + 60, max(editor.height, cw.height) + 70), g.BG)
    dr = ImageDraw.Draw(sheet)
    dr.text((20, 14), "Edit mode opens the canvas window beside the editor (editor shown at half size)",
            font=g.f(18), fill=g.GOLD_B)
    sheet.paste(editor, (20, 52))
    sheet.paste(cw, (editor.width + 40, 52))
    path = os.path.join(g.OUT, "editor-canvas-draft.png")
    sheet.save(path)
    print(path)


if __name__ == "__main__":
    main()
