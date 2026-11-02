r"""Draft: the redesigned dead and offline unit frames (dead.lua).

Dead:
    [Icon] [Time]   angel-investor.png in gold beside the death timer
       [Name]       over the 45-degree (///) crimson-stone fractured bar

Offline:
       [Icon]       disconnected.png in silver-steel
       [Name]       over the 135-degree (\\\) scanline steel-slate bar

Each shown on the player frame (267x54), the console's party window (129x43)
and a raid cell (112x36). Drawn at the game's size, then shown 3x.
"""
import os

from PIL import Image, ImageDraw

from gen_widgets import GOLD, GOLD_D, font

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "render")
MEDIA = os.path.join(HERE, "..", "..", "WoW", "Interface", "AddOns", "Medalluin", "media")
SCALE = 3
DEAD = (64, 66, 74)
OFFLINE = (52, 56, 66)
LINE_DEAD = GOLD_D
LINE_OFFLINE = (118, 132, 152)

FRAMES = [("Player", 267, 54), ("Party (console)", 129, 43), ("Raid cell", 112, 36)]
WHO = [("Ahrymx", (244, 140, 186), "0:42"), ("Thalric", (64, 199, 235), "3:07"), ("Velis", (255, 245, 105), "12:55")]
SIZES = [(50, 20, 11, 13), (40, 18, 10, 11), (0, 16, 9, 10)]


def bar_surface(img, x, y, w, h, state):
    base = DEAD if state == "dead" else OFFLINE
    tex_name = "dead-bar.tga" if state == "dead" else "offline-bar.tga"
    line_col = LINE_DEAD if state == "dead" else LINE_OFFLINE

    cell = Image.new("RGBA", (w, h), base + (255,))
    tex = Image.open(os.path.join(MEDIA, tex_name)).convert("RGBA").crop((0, 0, w, h))
    cell.alpha_composite(tex)

    # Edge vignette (Shade in dead.lua)
    shade = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shade)
    for i in range(6):
        sd.rectangle([i, i, w - 1 - i, h - 1 - i], outline=(0, 0, 0, 95 - i * 15))
    cell.alpha_composite(shade)

    # Inner border line (Line in dead.lua)
    ImageDraw.Draw(cell).rectangle([1, 1, w - 2, h - 2], outline=line_col + (255,))
    img.alpha_composite(cell, (x, y))


ICONS = []  # (kind, x, y, size): pasted after 3x scale for crisp icon sampling


def frame(img, x, y, w, h, who, state):
    bar_surface(img, x, y, w, h, state)
    dr = ImageDraw.Draw(img)
    name, col, timer = who
    icon, t_sz, n_sz = 16, 9, 10
    for min_h, ic, ts, ns_ in SIZES:
        if h >= min_h:
            icon, t_sz, n_sz = ic, ts, ns_
            break
    fn, ft = font(n_sz), font(t_sz)
    row_gap, col_gap = 2, 4
    cy = y + h // 2
    cx = x + w // 2
    top_cy = cy - (n_sz + row_gap) // 2
    bot_cy = cy + (icon + row_gap) // 2

    if state == "dead":
        tw = int(ft.getlength(timer))
        ix = cx - (tw + col_gap) // 2 - icon // 2
        ICONS.append(("dead-wings.tga", ix, top_cy - icon // 2, icon))
        tx = ix + icon + col_gap
        for dx, dy, c in ((1, 1, (0, 0, 0)), (0, 0, (225, 218, 200))):
            dr.text((tx + dx, top_cy + dy), timer, font=ft, fill=c, anchor="lm")
    else:
        ICONS.append(("disconnected.tga", cx - icon // 2, top_cy - icon // 2, icon))

    nc = tuple(int(c * 0.85) for c in col) if state == "dead" else (195, 202, 214)
    for dx, dy, c in ((1, 1, (0, 0, 0)), (0, 0, nc)):
        dr.text((cx + dx, bot_cy + dy), name, font=fn, fill=c, anchor="mm")


def main():
    os.makedirs(OUT, exist_ok=True)
    pad = 14
    label_h = 14
    col_w = [f[1] + pad for f in FRAMES]
    row_h = max(f[2] for f in FRAMES) + label_h + pad
    W = 36 + sum(col_w) + 20
    H = 16 + 2 * (row_h + 18)
    img = Image.new("RGBA", (W, H), (32, 35, 42, 255))
    dr = ImageDraw.Draw(img)
    rows = [("dead", "Dead   —   [Icon] [Time] / [Name]   (45° crimson-stone fracture bar)"),
            ("offline", "Offline   —   [Icon] / [Name]   (135° steel-slate scanline bar)")]
    for r, (state, title) in enumerate(rows):
        y0 = 8 + r * (row_h + 18)
        dr.text((pad, y0), title, font=font(11), fill=GOLD)
        x = 24
        for c, (label, w, h) in enumerate(FRAMES):
            dr.text((x, y0 + 16), f"{label} ({w}x{h})", font=font(8), fill=(155, 155, 155))
            frame(img, x, y0 + 16 + label_h, w, h, WHO[c], state)
            x += col_w[c]

    img = img.resize((W * SCALE, H * SCALE), Image.Resampling.NEAREST)
    for tex_name, ix, iy, size in ICONS:
        src = Image.open(os.path.join(MEDIA, tex_name)).convert("RGBA")
        ic = src.resize((size * SCALE, size * SCALE), Image.Resampling.LANCZOS)
        img.alpha_composite(ic, (ix * SCALE, iy * SCALE))
    out_path = os.path.join(OUT, "dead-draft.png")
    img.save(out_path)
    print(out_path)


if __name__ == "__main__":
    main()
