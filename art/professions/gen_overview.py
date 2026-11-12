#!/usr/bin/env python3
"""The professions' Overview artwork (professions/window.lua): a background
for each primary profession's pillar and one for the Camping section, in
the engraved look the user chose (2026-11-12, O1): the craft's motif in
faint gold line art, low and to one side of the pillar (clear of its
centred icon, name and bar), over fine hatching that fades in towards the
foot, on nothing (the window's ink shows through).

    python3 art/professions/gen_overview.py   -> assets/professions/*.png,
        media/professions/<skillLine>.tga and camp.tga, render/overview.png

A pillar's art is the top 256x222 of a 256x256 texture (the pillar is
219x190); the camp's the top 512x152 of a 512x256 (its strip is 444x132).
The code crops them by texture coordinates.
"""
import os
import random
import subprocess
import sys

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, os.path.join(ROOT, "art", "console"))
import export  # noqa: E402

GOLD = "#c4a557"
LINE = 2.2                      # a motif's stroke, in the motif's own 200-unit square
MOTIF, HATCH = 0.30, 0.16       # their opacities
PILLAR = (256, 222, 256)        # the art's width and height, the texture's height
CAMP = (512, 152, 256)

S = f'fill="none" stroke="{GOLD}" stroke-width="{LINE}" stroke-linecap="round" stroke-linejoin="round"'
T = f'fill="none" stroke="{GOLD}" stroke-width="{LINE * 0.6}" stroke-linecap="round" stroke-linejoin="round"'


# ------------------------------------------------------------------ motifs
# Each in a 200x200 square, its weight low, drawn in lines only.
def alchemy():
    return f'''
    <g {S}>
      <path d="M78 40 L78 86 L40 160 Q34 176 52 178 L134 178 Q152 176 146 160 L108 86 L108 40"/>
      <path d="M72 40 L114 40"/>
      <path d="M50 140 Q93 128 136 140"/>
      <path d="M108 60 Q150 50 168 76 L176 70"/>
      <circle cx="152" cy="140" r="20"/><path d="M146 112 L158 112 M152 112 L152 120"/>
    </g>
    <g {T}>
      <circle cx="80" cy="156" r="5"/><circle cx="100" cy="150" r="3.5"/><circle cx="92" cy="122" r="3"/>
      <circle cx="104" cy="104" r="2.2"/><path d="M60 150 L72 150 M114 160 L128 160"/>
      <path d="M140 140 Q152 132 164 140"/>
    </g>'''


def blacksmithing():
    return f'''
    <g {S}>
      <path d="M30 104 L140 104 Q170 104 188 90 L188 110 Q166 124 134 124 L126 124 L126 140 L146 162 L44 162
               L64 140 L64 124 L54 124 Q32 124 30 112 Z"/>
      <path d="M68 162 L122 162 L128 182 L62 182 Z"/>
      <path d="M40 112 L120 112"/>
    </g>
    <g {S} transform="rotate(-34 120 64)">
      <rect x="112" y="30" width="14" height="80" rx="3"/>
      <rect x="88" y="16" width="62" height="26" rx="4"/>
    </g>
    <g {T}>
      <path d="M96 92 L90 78 M104 90 L108 74 M112 94 L124 84 M86 96 L74 88"/>
      <circle cx="84" cy="70" r="1.6"/><circle cx="118" cy="68" r="1.6"/><circle cx="130" cy="80" r="1.4"/>
    </g>'''


def enchanting():
    """A rod over a rune circle: two rings, a diamond inside, runes round it."""
    import math
    runes = []
    for i in range(8):
        a = i * math.pi / 4 + math.pi / 8
        x, y = 100 + 62 * math.cos(a), 128 + 62 * math.sin(a)
        runes.append(f'<path d="M{x - 3:.1f} {y - 4:.1f} L{x + 3:.1f} {y + 4:.1f} M{x + 3:.1f} {y - 4:.1f} '
                     f'L{x:.1f} {y:.1f}" />')
    return f'''
    <g {S}>
      <circle cx="100" cy="128" r="70"/><circle cx="100" cy="128" r="54"/>
      <path d="M100 82 L146 128 L100 174 L54 128 Z"/>
      <circle cx="100" cy="128" r="14"/>
      <path d="M170 24 L112 112"/>
      <path d="M164 18 L180 26 L176 36 L160 28 Z"/>
    </g>
    <g {T}>
      {"".join(runes)}
      <path d="M172 12 L176 4 M186 30 L196 28 M158 14 L152 6"/>
      <circle cx="190" cy="14" r="1.8"/><circle cx="150" cy="40" r="1.5"/>
    </g>'''


def gear(cx, cy, r, teeth):
    import math
    pts = []
    for i in range(teeth * 2):
        a = i * math.pi / teeth
        rr = r if i % 2 == 0 else r * 0.8
        a2 = a + math.pi / teeth
        pts.append(f"{cx + rr * math.cos(a):.1f} {cy + rr * math.sin(a):.1f}")
        pts.append(f"{cx + rr * math.cos(a2):.1f} {cy + rr * math.sin(a2):.1f}")
    return f'<path d="M{" L".join(pts)} Z"/><circle cx="{cx}" cy="{cy}" r="{r * 0.32:.1f}"/>'


def engineering():
    """Two gears meshing, and an open-ended wrench across them."""
    return f'''
    <g {S}>
      {gear(96, 130, 46, 10)}
      {gear(158, 86, 30, 8)}
    </g>
    <g {S} transform="rotate(-45 70 150)">
      <path d="M62 80 L78 80 L78 196 L62 196 Z"/>
      <path d="M56 80 Q48 58 62 46 L62 64 L78 64 L78 46 Q92 58 84 80 Z"/>
    </g>
    <g {T}><circle cx="96" cy="130" r="6"/><circle cx="158" cy="86" r="4"/></g>'''


def herbalism():
    return f'''
    <g {S}>
      <path d="M100 196 Q98 140 108 70"/>
      <path d="M102 160 Q60 150 44 118 Q80 116 102 150"/>
      <path d="M104 130 Q148 124 164 92 Q126 92 104 122"/>
      <path d="M106 100 Q76 84 74 54 Q100 64 106 92"/>
      <circle cx="110" cy="56" r="12"/>
    </g>
    <g {T}>
      <path d="M110 44 L110 30 M122 50 L132 40 M98 50 L88 40 M124 62 L136 64 M96 62 L84 64"/>
      <path d="M58 128 L94 150 M150 100 L110 124 M84 66 L104 92"/>
      <path d="M60 196 Q100 186 150 196"/>
    </g>'''


def leatherworking():
    return f'''
    <g {S}>
      <path d="M30 40 L170 40 L170 190 L30 190 Z"/>
      <path d="M58 62 Q76 54 92 66 Q110 54 128 64 Q146 56 148 74 Q138 96 150 122 Q156 152 136 168
               Q114 160 100 172 Q84 160 64 168 Q46 150 52 122 Q64 96 52 76 Q52 66 58 62 Z"/>
      <path d="M150 150 L184 192"/>
      <path d="M144 142 L156 136 L162 148 L150 154 Z"/>
    </g>
    <g {T}>
      <path d="M30 40 L58 62 M170 40 L148 74 M30 190 L64 168 M170 190 L136 168"/>
      <path d="M72 90 L72 94 M72 110 L72 114 M72 130 L72 134 M128 90 L128 94 M128 110 L128 114 M128 130 L128 134"/>
    </g>'''


def mining():
    return f'''
    <g {S}>
      <path d="M26 180 L60 140 L96 152 L126 120 L168 146 L190 180 Z"/>
      <path d="M60 140 L72 164 M126 120 L118 150 L96 152"/>
    </g>
    <g {S} transform="rotate(30 110 80)">
      <rect x="104" y="36" width="12" height="104" rx="3"/>
      <path d="M48 46 Q110 14 172 46 Q110 32 48 46 Z"/>
    </g>
    <g {T}>
      <path d="M84 168 L92 158 L100 168 L92 176 Z M146 158 L152 150 L160 160 L152 166 Z"/>
      <path d="M40 176 L50 166 M166 172 L176 168"/>
    </g>'''


def skinning():
    return f'''
    <g {S}>
      <path d="M40 120 Q60 96 64 70 Q86 82 100 76 Q114 82 136 70 Q140 96 160 120 Q150 150 158 176
               Q128 166 100 180 Q72 166 42 176 Q50 150 40 120 Z"/>
      <path d="M64 70 L56 56 M136 70 L144 56"/>
    </g>
    <g {S} transform="rotate(-38 150 70)">
      <path d="M150 20 Q176 40 160 86 L146 86 Q154 48 150 20 Z"/>
      <rect x="144" y="86" width="18" height="40" rx="4"/>
    </g>
    <g {T}><path d="M100 90 L100 168 M70 112 Q100 120 130 112 M66 146 Q100 154 134 146"/></g>'''


def tailoring():
    """A spool, its thread running to a needle, and open scissors."""
    return f'''
    <g {S}>
      <path d="M40 112 L100 112 M40 186 L100 186 M46 112 L46 186 M94 112 L94 186"/>
      <path d="M100 150 Q130 146 136 120 Q142 92 170 84"/>
      <path d="M150 104 L190 40"/>
      <ellipse cx="186" cy="48" rx="2.6" ry="6" transform="rotate(32 186 48)"/>
      <path d="M116 196 L190 150 L186 160 Z"/>
      <path d="M116 168 L190 196 L180 200 Z"/>
      <circle cx="108" cy="198" r="9"/><circle cx="108" cy="166" r="9"/>
    </g>
    <g {T}>
      <path d="M50 122 L90 122 M50 132 L90 132 M50 142 L90 142 M50 152 L90 152 M50 162 L90 162 M50 172 L90 172"/>
    </g>'''


def camp():
    """The camp: a ridge, a tent, a fire and stars, 512x152."""
    random.seed(7)
    stars = "".join(
        f'<path d="M{x:.0f} {y:.0f} m-2.4 0 l4.8 0 m-2.4 -2.4 l0 4.8" {T}/>' if random.random() < 0.3 else
        f'<circle cx="{x:.0f}" cy="{y:.0f}" r="1.3" fill="{GOLD}"/>'
        for x, y in ((random.uniform(10, 500), random.uniform(8, 70)) for _ in range(28)))
    return f'''
    {stars}
    <g {S}>
      <path d="M0 132 Q60 104 120 116 Q170 96 230 112 Q300 92 360 108 Q430 96 512 116"/>
      <path d="M300 136 L352 58 L404 136 Z M352 58 L352 136 M336 136 L352 104 L368 136"/>
      <path d="M420 136 Q424 112 434 122 Q436 100 450 118 Q456 106 460 136"/>
      <path d="M410 140 L470 132 M412 132 L472 142"/>
    </g>
    <g {T}><path d="M436 104 L440 94 M452 100 L458 92"/></g>'''


PRIMARIES = {
    171: ("Alchemy", alchemy), 164: ("Blacksmithing", blacksmithing), 333: ("Enchanting", enchanting),
    202: ("Engineering", engineering), 182: ("Herbalism", herbalism), 165: ("Leatherworking", leatherworking),
    186: ("Mining", mining), 393: ("Skinning", skinning), 197: ("Tailoring", tailoring),
}


def hatch(w, h):
    """Fine diagonals, fading in towards the foot."""
    lines = "".join(f'<path d="M{x} {h} L{x + h} 0" stroke="{GOLD}" stroke-width="0.7"/>' for x in range(-h, w, 9))
    return f'''<defs>
      <linearGradient id="fade" x1="0" y1="0" x2="0" y2="1">
        <stop offset="0.35" stop-color="#fff" stop-opacity="0"/>
        <stop offset="1" stop-color="#fff" stop-opacity="1"/>
      </linearGradient>
      <mask id="m"><rect width="{w}" height="{h}" fill="url(#fade)"/></mask>
    </defs>
    <g opacity="{HATCH}" mask="url(#m)">{lines}</g>'''


def render(doc, w, h, path):
    subprocess.run(["rsvg-convert", "-w", str(w), "-h", str(h), "-o", path], input=doc.encode(), check=True)


def piece(name, body, size, place):
    """The art at its size, on a texture of its height, saved as PNG and TGA."""
    w, h, th = size
    doc = f'''<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">
      {hatch(w, h)}
      <g opacity="{MOTIF}" transform="{place}">{body}</g>
    </svg>'''
    parts = os.path.join(ROOT, "assets", "professions")
    os.makedirs(parts, exist_ok=True)
    png = os.path.join(parts, f"{name}.png")
    render(doc, w, h, png)
    art = Image.open(png).convert("RGBA")
    tex = Image.new("RGBA", (w, th), (0, 0, 0, 0))
    tex.paste(art, (0, 0))
    tex.save(png)
    media = os.path.join(ROOT, "WoW", "Interface", "AddOns", "Medalluin", "media", "professions")
    os.makedirs(media, exist_ok=True)
    export.to_tga(tex, os.path.join(media, f"{name}.tga"))
    return art


def sheet(arts):
    """render/overview.png: each on the ink, at 2x, named."""
    pad, cols = 16, 3
    cw, ch = PILLAR[0] * 2, PILLAR[1] * 2
    rows = (len(arts) - 1 + cols - 1) // cols
    W = cols * (cw + pad) + pad
    H = rows * (ch + pad + 24) + pad + CAMP[1] * 2 + 40
    img = Image.new("RGBA", (W, H), (19, 17, 12, 255))
    d = ImageDraw.Draw(img)
    for i, (label, art) in enumerate(arts[:-1]):
        x = pad + (i % cols) * (cw + pad)
        y = pad + (i // cols) * (ch + pad + 24)
        d.rectangle([x - 1, y - 1, x + cw, y + ch], outline=(138, 112, 52))
        img.alpha_composite(art.resize((cw, ch), Image.LANCZOS), (x, y))
        d.text((x, y + ch + 4), label, fill=(240, 212, 136))
    label, art = arts[-1]
    y = pad + rows * (ch + pad + 24)
    img.alpha_composite(art.resize((CAMP[0] * 2, CAMP[1] * 2), Image.LANCZOS), (pad, y))
    d.text((pad, y + CAMP[1] * 2 + 4), label, fill=(240, 212, 136))
    out = os.path.join(HERE, "render")
    os.makedirs(out, exist_ok=True)
    path = os.path.join(out, "overview.png")
    img.convert("RGB").save(path)
    print(path)


def main():
    arts = []
    # low and to the right, 0.72 of its square, a little cropped at the edge
    place = "translate(118 82) scale(0.72)"
    for skill, (label, fn) in PRIMARIES.items():
        arts.append((f"{label} ({skill})", piece(str(skill), fn(), PILLAR, place)))
    arts.append(("Camping", piece("camp", camp(), CAMP, "translate(0 0)")))
    sheet(arts)


if __name__ == "__main__":
    main()
