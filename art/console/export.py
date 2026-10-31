#!/usr/bin/env python3
"""Export the console art in assets/ to the addon's media, and measure its
windows into Lua.

    python3 art/console/export.py

assets/layer0.png (solo) and assets/layer1.png (in a group) are 1920x1081
screen mockups with the frame's windows cut out as transparency. This script:

  * crops both to the frame's bounding box and pads them to power-of-two
    32-bit uncompressed TGA (media/console-solo.tga, media/console-group.tga);
  * writes media/bar.tga, the white status-bar fill the units tint;
  * finds every window (an enclosed transparent region), checks that it is
    mirrored about the centre line, and writes console/windows.lua with each
    window as distances from the centre line. Lua never hard-codes a window,
    so redrawing the art and re-running this keeps code and art in step.
"""
import collections
import os
import subprocess
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
ADDON = os.path.join(ROOT, "WoW", "Interface", "AddOns", "Medaluin")
MEDIA = os.path.join(ADDON, "media")
CENTRE_X = 960                      # the screen's centre line in the mockups


def pow2(n):
    p = 1
    while p < n:
        p *= 2
    return p


def to_tga(img, path):
    """32-bit uncompressed TGA via magick, as the plan specifies."""
    tmp = path + ".png"
    img.save(tmp)
    subprocess.run(["magick", tmp, "-define", "tga:compression=none",
                    "-depth", "8", "-type", "TrueColorAlpha", path], check=True)
    os.remove(tmp)


def windows(alpha, box):
    """Bounding boxes of transparent regions that do not touch the box edge."""
    x0, y0, x1, y1 = box
    px = alpha.load()
    seen, found = set(), []
    for sy in range(y0, y1):
        for sx in range(x0, x1):
            if px[sx, sy] >= 128 or (sx, sy) in seen:
                continue
            q, region, edge = collections.deque([(sx, sy)]), [], False
            seen.add((sx, sy))
            while q:
                x, y = q.popleft()
                region.append((x, y))
                edge |= x in (x0, x1 - 1) or y in (y0, y1 - 1)
                for n in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                    if (x0 <= n[0] < x1 and y0 <= n[1] < y1 and n not in seen
                            and px[n] < 128):
                        seen.add(n)
                        q.append(n)
            if not edge and len(region) > 50:
                xs = [p[0] for p in region]
                ys = [p[1] for p in region]
                found.append((min(xs), min(ys), max(xs) + 1, max(ys) + 1))
    return found


def name_windows(found, top):
    """Pair each left window with its mirror and name it by row and order.

    Returns {name: (inner, outer, top, bottom)}: inner/outer are distances
    from the centre line, top/bottom are measured from the frame's top edge.
    A window that straddles the centre (the ring) has inner = 0.
    """
    rows = collections.defaultdict(list)
    for x0, y0, x1, y1 in found:
        rows[(y0 - top, y1 - top)].append((x0 - CENTRE_X, x1 - CENTRE_X))
    out = {}
    for (t, b), spans in sorted(rows.items()):
        centre = [s for s in spans if s[0] < 0 < s[1]]
        left = sorted((s for s in spans if s[1] <= 0), key=lambda s: -s[1])
        right = sorted((s for s in spans if s[0] >= 0), key=lambda s: s[0])
        for s in centre:
            if s[0] != -s[1]:
                sys.exit(f"centre window {s} is not centred")
            out["ring"] = (0, s[1], t, b)
        if [(-r, -l) for l, r in left] != right:
            sys.exit(f"row {t}..{b} is not mirrored: {left} vs {right}")
        h = b - t
        kind = "xp" if h < 12 else ("unit" if t < 40 else "party")
        for i, (l, r) in enumerate(right):
            out[f"{kind}{i + 1}" if len(right) > 1 else kind] = (l, r, t, b)
    return out


def main():
    os.makedirs(MEDIA, exist_ok=True)
    solo = Image.open(os.path.join(ROOT, "assets", "layer0.png")).convert("RGBA")
    group = Image.open(os.path.join(ROOT, "assets", "layer1.png")).convert("RGBA")
    box = solo.getchannel("A").getbbox()
    if box != group.getchannel("A").getbbox():
        sys.exit("layer0 and layer1 have different bounds")
    x0, y0, x1, y1 = box
    if x0 + x1 != 2 * CENTRE_X:
        sys.exit(f"frame {box} is not centred on x={CENTRE_X}")
    w, h = x1 - x0, y1 - y0
    tw, th = pow2(w), pow2(h)
    for img, name in ((solo, "console-solo"), (group, "console-group")):
        canvas = Image.new("RGBA", (tw, th), (0, 0, 0, 0))
        canvas.paste(img.crop(box), (0, 0))
        to_tga(canvas, os.path.join(MEDIA, f"{name}.tga"))

    # Bar fill: white, lighter above a step at 42% like the H mockup's bars.
    bar = Image.new("RGBA", (8, 64))
    for y in range(64):
        v = 255 if y < 27 else 218
        for x in range(8):
            bar.putpixel((x, y), (v, v, v, 255))
    to_tga(bar, os.path.join(MEDIA, "bar.tga"))

    named = name_windows(windows(group.getchannel("A"), box), y0)
    solo_named = name_windows(windows(solo.getchannel("A"), box), y0)
    for k, v in solo_named.items():
        if named.get(k) != v:
            sys.exit(f"window {k} differs between layers: {v} vs {named.get(k)}")

    lines = [
        "-- Generated by art/console/export.py from assets/layer*.png; do not edit.",
        "-- Every window is { inner, outer, top, bottom }: inner/outer are distances",
        "-- from the centre line (the left copy is the mirror), top/bottom are",
        "-- measured down from the frame's top edge. Units are art pixels.",
        "local _, ns = ...",
        "ns.art = {",
        f"    width = {w}, height = {h}, texWidth = {tw}, texHeight = {th},",
        f"    bottomGap = {solo.height - 1 - y1},",
        "}",
        "ns.windows = {",
    ]
    for k in sorted(named):
        i, o, t, b = named[k]
        solo_only = "" if k in solo_named else "  -- group art only"
        lines.append(f"    {k} = {{ {i}, {o}, {t}, {b} }},{solo_only}")
    lines.append("}")
    with open(os.path.join(ADDON, "console", "windows.lua"), "w") as f:
        f.write("\n".join(lines) + "\n")
    for k in sorted(named):
        print(k, named[k])


if __name__ == "__main__":
    main()
