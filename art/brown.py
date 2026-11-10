#!/usr/bin/env python3
"""The suite's navy turned dark brown (2026-11-10, the user's call): the
console, its strips, plates, wells and trays were drawn in a slate navy
(#3a4154 to #252a37); they are now the brown of a selected tab (#483c20 to
#2e2614).

brown(rgba) recolours an image: a dark, greyish blue pixel (the navy and
its shades) takes the brown's hue, a little more saturated and a little
darker, so #3a4154 becomes #483c20. Bright or vivid blues (the tank's
shield, a quality colour) are left as they are, and the Medalluin logo is
never passed to it; a
pixel at the edge of the navy's range is blended part way, so edges stay
smooth. rgb(colour) is the same for one colour, for the generators.

    python3 art/brown.py <file> ...           recolour PNGs or TGAs in place
    python3 art/brown.py --bright <file> ...  light navy too (striped fills)
"""
import os
import subprocess
import sys

import numpy as np
from PIL import Image

HUE = 42 / 360          # the brown's hue
SAT, SAT_MAX = 1.85, 0.62
VALUE = 0.86


def ramp(x, a, b):
    """0 at a, 1 at b (either way round), linear between."""
    return np.clip((x - a) / (b - a), 0, 1)


def weights(h, s, v, bright=False):
    hue = np.minimum(ramp(h, 0.52, 0.56), ramp(h, 0.78, 0.74))
    sat = ramp(s, 0.06, 0.12)
    val = ramp(v, 0.85, 0.75) if bright else ramp(v, 0.62, 0.50)
    ink = ramp(v, 0.07, 0.10)       # near-black inks with a cool cast stay ink
    return hue * sat * val * ink


def brown(img, bright=False):
    a = np.asarray(img.convert("RGBA")).astype(np.float64) / 255
    rgb = a[..., :3]
    mx, mn = rgb.max(-1), rgb.min(-1)
    v = mx
    s = np.where(mx > 0, (mx - mn) / np.where(mx > 0, mx, 1), 0)
    d = np.where(mx > mn, mx - mn, 1)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    h = np.where(mx == r, (g - b) / d % 6, np.where(mx == g, (b - r) / d + 2, (r - g) / d + 4)) / 6
    h = np.where(mx > mn, h, 0)
    w = weights(h, s, v, bright)[..., None]
    s2, v2 = np.minimum(SAT_MAX, s * SAT), v * VALUE
    # HSV back to RGB at the one hue: HUE lies in the 0..1/6 sector (red to yellow)
    f = HUE * 6
    out = np.stack([v2, v2 * (1 - s2 * (1 - f)), v2 * (1 - s2)], -1)
    a[..., :3] = rgb * (1 - w) + out * w
    return Image.fromarray(np.round(a * 255).astype(np.uint8), "RGBA")


def rgb(colour):
    """One colour, (r, g, b) or "#rrggbb", as brown() turns it, in kind."""
    t = tuple(int(colour.lstrip("#")[i:i + 2], 16) for i in (0, 2, 4)) if isinstance(colour, str) else colour
    p = brown(Image.new("RGBA", (1, 1), tuple(t[:3]) + (255,))).getpixel((0, 0))[:3]
    return "#%02x%02x%02x" % p if isinstance(colour, str) else p


if __name__ == "__main__":
    args = sys.argv[1:]
    bright = "--bright" in args
    for path in (a for a in args if a != "--bright"):
        was = Image.open(path).convert("RGBA")
        img = brown(was, bright)
        if np.array_equal(np.asarray(was), np.asarray(img)):
            continue                    # nothing navy in it
        if path.endswith(".tga"):
            # as art/console/export.py writes them: 32-bit, uncompressed
            tmp = path + ".png"
            img.save(tmp)
            subprocess.run(["magick", tmp, "-define", "tga:compression=none",
                            "-depth", "8", "-type", "TrueColorAlpha", path], check=True)
            os.remove(tmp)
        else:
            img.save(path)
        print(path)
