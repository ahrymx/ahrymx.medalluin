#!/usr/bin/env python3
"""Draw what tools/harness.lua resolved, under the real console art, so a
placement change can be checked without the game client.

    python3 tools/preview.py            -> art/console/render/console-preview.png
"""
import os
import subprocess

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MEDIA = os.path.join(ROOT, "WoW", "Interface", "AddOns", "Medaluin", "media")
FONT = os.path.join(MEDIA, "fonts", "MarcellusSC-Regular.ttf")
INK = (18, 17, 16, 255)
COLOURS = {"health": {"player": (196, 110, 147), "target": (163, 61, 45), "party1": (196, 110, 147),
                      "party2": (196, 110, 147)},
           "power": (0, 0, 204)}


def run(state):
    out = subprocess.run(["lua5.1", "tools/harness.lua", state], cwd=ROOT,
                         capture_output=True, text=True, check=True).stdout
    rects, names = {}, {}
    for line in out.splitlines():
        parts = line.split("\t")
        if parts[0].endswith(".name"):
            names[parts[0][:-5]] = parts[1]
        elif len(parts) >= 5:                   # a rectangle; the rest are tallies
            rects[parts[0]] = ([float(v) for v in parts[1:5]], parts[5] if len(parts) > 5 else "")
    return rects, names


def draw(state, scale=3):
    rects, names = run(state)
    tga = Image.open(os.path.join(MEDIA, f"console-{state}.tga"))
    w, h = 696, 147
    art = tga.crop((0, 0, w, h))
    img = Image.new("RGBA", (w, h), (40, 52, 40, 255))
    d = ImageDraw.Draw(img)
    for key, ((l, t, r, b), extra) in rects.items():
        if key == "minimap":
            d.ellipse((l, t, r, b), fill=(70, 96, 70, 255))
            continue
        unit, part = key.split(".")
        d.rectangle((l, t, r - 1, b - 1), fill=INK)
        fill = float(extra.split()[0].split("=")[1]) / 100
        rev = "rev=true" in extra
        span = (r - l) * fill
        fl, fr = (r - span, r) if rev else (l, l + span)
        colour = COLOURS["power"] if part == "power" else COLOURS["health"].get(unit, (120, 120, 120))
        d.rectangle((fl, t, fr - 1, b - 1), fill=colour + (255,))
    img.alpha_composite(art)
    img = img.resize((w * scale, h * scale), Image.LANCZOS)
    d = ImageDraw.Draw(img)
    for unit, name in names.items():
        (l, t, r, b), extra = rects[unit + ".health"]
        right = "rev=true" in extra
        size = 16 if unit in ("player", "target") else 12
        f = ImageFont.truetype(FONT, size * scale)
        y = (t + b) / 2 * scale
        if right:
            d.text(((r - 10) * scale, y), name, font=f, anchor="rm", fill=(242, 234, 210))
        else:
            d.text(((l + 10) * scale, y), name, font=f, anchor="lm", fill=(242, 234, 210))
    return img


def main():
    a, b = draw("solo"), draw("group")
    sheet = Image.new("RGBA", (a.width, a.height * 2 + 12), (10, 10, 10, 255))
    sheet.paste(a, (0, 0))
    sheet.paste(b, (0, a.height + 12))
    out = os.path.join(ROOT, "art", "console", "render")
    os.makedirs(out, exist_ok=True)
    path = os.path.join(out, "console-preview.png")
    sheet.convert("RGB").save(path)
    print(path)


if __name__ == "__main__":
    main()
