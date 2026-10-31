#!/usr/bin/env python3
"""Export the console art in assets/ to the addon's media, and measure its
windows into Lua.

    python3 art/console/export.py

assets/layer0.png (solo) and assets/layer1.png (in a group) are 1920x1081
screen mockups with the frame's windows cut out as transparency. This script:

  * crops both to the frame's bounding box and pads them to power-of-two
    32-bit uncompressed TGA (media/console-solo.tga, media/console-group.tga);
  * writes media/bar.tga, the white status-bar fill the units tint;
  * writes media/console-solo-tint.tga and media/console-group-tint.tga:
    each art's grey surface (its blue-grey stone, never the gold trim) as
    white, its alpha falling from the ring's centre to the frame's ends, for
    the combat colour code (console/frame.lua) to tint;
  * finds every window (an enclosed transparent region), checks that it is
    mirrored about the centre line, and writes console/windows.lua with each
    window as distances from the centre line. Lua never hard-codes a window,
    so redrawing the art and re-running this keeps code and art in step;
  * checks assets/layer2.png, the action bar's plate, against
    assets/layer2.json, its windows (both drawn by art/bars/gen_bar.py), and
    writes media/actionbar.tga, media/bar/*.tga (the page chevrons, the drawer's toolkit) and
    bars/windows.lua;
  * and for assets/layer3.png, the corner strips (art/strips/gen_strips.py):
    the LEFT strip becomes media/strip.tga (the right one is the same art
    mirrored by texture coordinates), its medallion well and the layout
    numbers go to strips/windows.lua, and assets/strips/*.png become
    media/strips/*.tga.
"""
import json
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


# The combat tint: full strength at the ring's centre, this much at the
# frame's ends, falling linearly with the distance (console/frame.lua sets
# the colour and the overall strength).
TINT_FAINT = 0.15
# The grey surface is blue-grey (blue at least 18 above red); the gold trim
# and its bronze shading have red above blue. Nothing in the art sits
# between 1 and 6, so the threshold falls in the gap.
SURFACE_BLUE = 5


def tint_mask(img, box, centre):
    """The art's grey surface as white, its alpha the art's own times the
    fall-off from centre (cx, cy in screen pixels)."""
    x0, y0, x1, y1 = box
    cx, cy = centre
    half = (x1 - x0) / 2
    src = img.load()
    out = Image.new("RGBA", (x1 - x0, y1 - y0), (255, 255, 255, 0))
    px = out.load()
    for y in range(y0, y1):
        for x in range(x0, x1):
            r, g, b, a = src[x, y]
            if a == 0 or b - r < SURFACE_BLUE:
                continue
            d = min(1.0, ((x + 0.5 - cx) ** 2 + (y + 0.5 - cy) ** 2) ** 0.5 / half)
            px[x - x0, y - y0] = (255, 255, 255, round(a * (1 - (1 - TINT_FAINT) * d)))
    # the threshold sits in the art's gap: all the stone is tinted, none of
    # the gold (clear of the gap on either side, so a moved threshold shows)
    for y in range(y0, y1):
        for x in range(x0, x1):
            r, g, b, a = src[x, y]
            t = px[x - x0, y - y0][3]
            if a == 255 and b - r >= 15 and t == 0:
                sys.exit(f"the tint misses the stone at {x},{y}")
            if r - b >= 25 and t:
                sys.exit(f"the tint covers the trim at {x},{y}")
    # strongest at the ring, faintest at the ends
    alphas = [(x, px[x, y][3]) for y in range(out.height) for x in range(out.width) if px[x, y][3]]
    near = max(t for x, t in alphas if abs(x + x0 + 0.5 - cx) < half * 0.2)
    ends = max(t for x, t in alphas if abs(x + x0 + 0.5 - cx) > half * 0.9)
    if near < 200 or ends > 255 * (1 - (1 - TINT_FAINT) * 0.9) + 2:
        sys.exit(f"the tint does not fall off from the centre: {near} near it, {ends} at the ends")
    # the suite's first rule: the tint is the same on both sides
    w = out.width
    a = out.getchannel("A")
    flipped = a.transpose(Image.FLIP_LEFT_RIGHT)
    apx, fpx = a.load(), flipped.load()
    odd = sum(1 for y in range(out.height) for x in range(w) if abs(apx[x, y] - fpx[x, y]) > 8)
    if odd > out.width * out.height // 200:
        sys.exit(f"the tint is not mirrored: {odd} pixels differ from their mirror")
    return out


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


def export_bar(console_top):
    """The action bar's plate (assets/layer2.png, by art/bars/gen_bar.py) and
    its layout (assets/layer2.json). Every window listed must be a hole in
    the plate and every row mirrored; then the plate goes to
    media/actionbar.tga and the layout to bars/windows.lua, x signed from the
    centre line and y UP from the console's top edge."""
    img = Image.open(os.path.join(ROOT, "assets", "layer2.png")).convert("RGBA")
    box = img.getchannel("A").getbbox()
    x0, y0, x1, y1 = box
    if x0 + x1 != 2 * CENTRE_X:
        sys.exit(f"bar plate {box} is not centred on x={CENTRE_X}")
    with open(os.path.join(ROOT, "assets", "layer2.json")) as f:
        layout = json.load(f)
    if layout["console_top"] != console_top:
        sys.exit(f"layer2.json stands on y={layout['console_top']}, the console's top is {console_top}")
    alpha = img.getchannel("A").load()

    def hole(w, name, round_=False):
        """A window is a hole with a solid rim above and below it. A round
        one (the lower row's pill) is a hole inside its rounded ends, a
        pixel in from their soft edge, and its rim is checked along the
        straight part."""
        l, t, r, b = w
        rr = (b - t) / 2 if round_ else 0

        def inside(x, y):
            cx = min(max(x + 0.5, l + rr), r - rr)
            return (x + 0.5 - cx) ** 2 + (y + 0.5 - (t + b) / 2) ** 2 <= (rr - 1) ** 2 if round_ else True
        if any(alpha[x, y] for y in range(t, b) for x in range(l, r) if inside(x, y)):
            sys.exit(f"layer2.png: {name} {w} is not a hole")
        if not all(alpha[x, t - 1] and alpha[x, b] for x in range(int(l + rr), int(r - rr))):
            sys.exit(f"layer2.png: {name} {w} is not framed")
        # and a pill's corners are stone, so what shows through is cropped
        if round_ and not (alpha[l, t] and alpha[r - 1, b - 1]):
            sys.exit(f"layer2.png: {name} {w} is not rounded")

    def up(w):
        l, t, r, b = w
        return f"{{ {l - CENTRE_X}, {r - CENTRE_X}, {console_top - t}, {console_top - b} }}"

    rows1 = layout["rows"]["1"][0]
    for i, (l, r, t, b) in enumerate(rows1):
        hole((l, t, r, b), f"slot {i + 1}")
    hole(layout["low"], "lower row", round_=True)
    # the pager's boxes are drawn wells, not holes: inside the upper row's
    # right end
    fl, ft, fr, fb = layout["frame"]
    _, ut, ur, ub = layout["upper"]
    last = rows1[-1][1]
    for k, (l, t, r, b) in layout["pager"].items():
        if not (last < l and r < ur and ut < t and b < ub) or not all(alpha[x, y] for y in range(t, b)
                                                                     for x in range(l, r)):
            sys.exit(f"layer2.json: the pager's {k} box {(l, t, r, b)} is not on the upper row's right end")
    # the drawer's toggle: its box on the left end mirrors the pager's, and
    # its round window is cut there
    l, t, r, b = layout["drawer"]
    pl = min(v[0] for v in layout["pager"].values())
    pr = max(v[2] for v in layout["pager"].values())
    pt = min(v[1] for v in layout["pager"].values())
    pb = max(v[3] for v in layout["pager"].values())
    if (l + pr, r + pl, t, b) != (2 * CENTRE_X, 2 * CENTRE_X, pt, pb):
        sys.exit(f"layer2.json: the drawer's box {(l, t, r, b)} does not mirror the pager's")
    # its round window: open within the hole's radius, stone past the
    # button's, so the plate covers the button's rim
    cx, cy, d = (l + r) / 2, (t + b) / 2, layout["toggle"]
    for x in range(l, r):
        for y in range(t, b):
            dist = ((x + 0.5 - cx) ** 2 + (y + 0.5 - cy) ** 2) ** 0.5
            if (dist < d["hole"] / 2 - 1 and alpha[x, y]) or (dist > d["diameter"] / 2 and not alpha[x, y]):
                sys.exit(f"layer2.png: the drawer's window at {(cx, cy)} is not {d['hole']} across")
    if not d["hole"] < d["diameter"]:
        sys.exit(f"layer2.json: the drawer's window {d['hole']} does not cover the button's rim")
    ll, lt, lr, lb = layout["low"]
    if ll + lr != 2 * CENTRE_X or lt < rows1[0][3]:
        sys.exit(f"layer2.json: the lower row {layout['low']} is not centred under the slots")
    # the outline's stroke reaches a pixel or two past it
    if max(abs(m - n) for m, n in zip((fl, ft, fr, fb), box)) > 2:
        sys.exit(f"layer2.json: the frame {layout['frame']} is not the plate's outline {box}")

    w, h = x1 - x0, y1 - y0
    tw, th = pow2(w), pow2(h)
    canvas = Image.new("RGBA", (tw, th), (0, 0, 0, 0))
    canvas.paste(img.crop(box), (0, 0))
    to_tga(canvas, os.path.join(MEDIA, "actionbar.tga"))
    os.makedirs(os.path.join(MEDIA, "bar"), exist_ok=True)
    for name in layout["parts"]:
        part = Image.open(os.path.join(ROOT, "assets", "bar", f"{name}.png")).convert("RGBA")
        w_, h_ = part.size
        if w_ != h_ or w_ not in (32, 64):
            sys.exit(f"assets/bar/{name}.png is {part.size}, not 32x32 or 64x64")
        to_tga(part, os.path.join(MEDIA, "bar", f"{name}.tga"))

    lines = [
        "-- Generated by art/console/export.py from assets/layer2.png and",
        "-- layer2.json; do not edit. Units are art pixels, as for the console:",
        "-- x is signed from the centre line, y is the height ABOVE the console's",
        "-- top edge (negative below it). Every window is { left, right, top, bottom }.",
        "local _, ns = ...",
        "-- the plate's texture; bottom is how far its foot reaches below the console's top",
        "ns.barArt = {",
        f"    width = {w}, height = {h}, texWidth = {tw}, texHeight = {th}, bottom = {console_top - y1},",
        "}",
        f"ns.barFrame = {up((fl, ft, fr, fb))}",
        f"ns.barLow = {up(layout['low'])}   -- the lower row: the cast bar, the class resource",
        "-- the right end's boxes: the page chevrons and the page number",
        "ns.barPager = {",
        *[f"    {k} = {up(layout['pager'][k])}," for k in ("up", "down", "number")],
        "}",
        "-- the left end's box, the minimap button drawer's toggle, and the drawer's",
        "-- line: a cell per button, the button fitted inside it, the line's padding,",
        "-- and where it stands: its right edge's x when it opens left, its bottom",
        "-- edge's height when it opens up; the toggle is a round button this wide,",
        "-- centred in the box",
        f"ns.barDrawer = {up(layout['drawer'])}",
        f"ns.barDrawerToggle = {layout['toggle']['diameter']}",
        "ns.barDrawerCell = {{ cell = {cell}, button = {button}, pad = {pad}, left = {left}, up = {up} }}".format(
            **dict(layout["drawer_cell"], left=layout["drawer_cell"]["left"] - CENTRE_X,
                   up=console_top - layout["drawer_cell"]["up"])),
        "-- The slots, per row count (the Rows option): rows from the bottom up (row 1",
        "-- is action bar 1, in the frame; the rows above it stand bare).",
        "ns.barWindows = {",
    ]
    for n in sorted(layout["rows"], key=int):
        rows = layout["rows"][n]
        if len(rows) != int(n):
            sys.exit(f"layer2.json: {n} rows expected, {len(rows)} found")
        lines.append("    {")
        for row in rows:
            spans = sorted((l - CENTRE_X, r - CENTRE_X) for l, r, _, _ in row)
            if len(row) != 12 or [(-r, -l) for l, r in reversed(spans)] != spans:
                sys.exit(f"layer2.json: a row of {n} is not 12 mirrored slots: {spans}")
            lines.append("        {")
            lines += [f"            {up((l, t, r, b))}," for l, r, t, b in row]
            lines.append("        },")
        lines.append("    },")
    lines.append("}")
    with open(os.path.join(ADDON, "bars", "windows.lua"), "w") as f:
        f.write("\n".join(lines) + "\n")
    print("bar plate", box, "frame", layout["frame"], "lower row", layout["low"])


def export_strips():
    img = Image.open(os.path.join(ROOT, "assets", "layer3.png")).convert("RGBA")
    W, H = img.size
    alpha = img.getchannel("A")
    left = alpha.crop((0, 0, CENTRE_X, H)).getbbox()
    right = alpha.crop((CENTRE_X, 0, W, H)).getbbox()
    x0, y0, x1, y1 = left
    if x0 != 0 or y1 != H:
        sys.exit(f"left strip {left} is not in the bottom-left corner")
    rx0, rx1 = CENTRE_X + right[0], CENTRE_X + right[2]
    if (rx0, right[1], rx1, right[3]) != (W - x1, y0, W - x0, y1):
        sys.exit(f"right strip {right} does not mirror the left {left}")
    w, h = x1 - x0, y1 - y0
    tw, th = pow2(w), pow2(h)
    canvas = Image.new("RGBA", (tw, th), (0, 0, 0, 0))
    canvas.paste(img.crop(left), (0, 0))
    to_tga(canvas, os.path.join(MEDIA, "strip.tga"))

    found = windows(alpha, left)
    if len(found) != 1:
        sys.exit(f"the left strip should have one well, found {found}")
    l, t, r, b = found[0]

    parts = os.path.join(ROOT, "assets", "strips")
    os.makedirs(os.path.join(MEDIA, "strips"), exist_ok=True)
    for name in sorted(os.listdir(parts)):
        if name.endswith(".png"):
            to_tga(Image.open(os.path.join(parts, name)).convert("RGBA"),
                   os.path.join(MEDIA, "strips", name[:-4] + ".tga"))
    with open(os.path.join(parts, "layout.json")) as f:
        layout = json.load(f)

    # the chat panel, on the left strip only: its own texture (layer3 must mirror)
    panel = Image.open(os.path.join(ROOT, "assets", "chat.png")).convert("RGBA")
    pw, ph = panel.size
    if (pw, ph) != (layout["chatWidth"], layout["chatHeight"]):
        sys.exit(f"chat panel {panel.size} is not the layout's {layout['chatWidth']}x{layout['chatHeight']}")
    if layout["chatLeft"] + pw != layout["length"]:
        sys.exit("the chat panel should end where the strip's top edge does")
    if layout["chatLeft"] < r - x0 + 4:          # the well, and the ring round it
        sys.exit("the chat panel overlaps the medallion")
    pa = panel.getchannel("A")
    if min(pa.getpixel((x, ph - 1)) for x in range(pw)) == 0:
        sys.exit("the chat panel's foot has a gap, so the world shows between it and the strip")
    canvas = Image.new("RGBA", (pow2(pw), pow2(ph)), (0, 0, 0, 0))
    canvas.paste(panel, (0, 0))
    to_tga(canvas, os.path.join(MEDIA, "chat.tga"))
    layout["chatTexWidth"], layout["chatTexHeight"] = pow2(pw), pow2(ph)

    lines = [
        "-- Generated by art/console/export.py from assets/layer3.png, assets/chat.png",
        "-- and assets/strips/layout.json; do not edit. The LEFT strip, in art pixels",
        "-- from its top-left; the right strip is its mirror.",
        "local _, ns = ...",
        "ns.stripArt = {",
        f"    width = {w}, height = {h}, texWidth = {tw}, texHeight = {th},",
        "}",
        "ns.stripWindows = {",
        "    -- the medallion's well: { left, right, top, bottom }",
        f"    well = {{ {l - x0}, {r - x0}, {t - y0}, {b - y0} }},",
        "}",
        "ns.stripLayout = {",
    ]
    for k in sorted(layout):
        lines.append(f"    {k} = {layout[k]},")
    lines.append("}")
    os.makedirs(os.path.join(ADDON, "strips"), exist_ok=True)
    with open(os.path.join(ADDON, "strips", "windows.lua"), "w") as f:
        f.write("\n".join(lines) + "\n")
    print("strip", left, "well", found[0])


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

    ring = named["ring"]
    centre = (CENTRE_X, y0 + (ring[2] + ring[3]) / 2)
    for img, name in ((solo, "console-solo"), (group, "console-group")):
        canvas = Image.new("RGBA", (tw, th), (255, 255, 255, 0))
        canvas.paste(tint_mask(img, box, centre), (0, 0))
        to_tga(canvas, os.path.join(MEDIA, f"{name}-tint.tga"))

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
    export_bar(y0)
    export_strips()


if __name__ == "__main__":
    main()
