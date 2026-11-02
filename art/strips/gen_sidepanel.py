#!/usr/bin/env python3
"""The right-hand panel: the chat panel's mirror on the right strip, with two
tabs, Loot and Meter (mockup only; nothing is exported yet).

The user's calls (2026-11-01): the two sides "pretty much identical"; the loot
log is the group's loot including personal, and is not a second chat log; the
meter is Medalluin's own, a view over the client's C_DamageMeter, and every
part of it can be switched off.

Mirrored: the panel spans the same strip positions as the chat, its button
column on the OUTER edge (the chat's is on the outer left), the scroll bar on
the inner edge, the tabs from the outer end inward.

The bag drawer used to open upward beside the backpack, where the panel now
stands. Two ways out are drawn:

  D1  the drawer opens as a column above the backpack's medallion, the mirror
      of the timeless-buff column above the portrait
  D2  the drawer opens as a row over the panel's foot, inside its frame

    python3 art/strips/gen_sidepanel.py         -> render/sidepanel.png
    python3 art/strips/gen_sidepanel.py parts   -> assets/strips/side-*.png
    python3 art/strips/gen_sidepanel.py auras   -> render/sidepanel-auras.png (the third tab)

The user chose the mirror, the Meter | Loot tabs (Loot outermost) and the
column buttons as drawn, and the bag drawer went instead (2026-11-01: the
bags are to move into the inventory). "parts" exports the column's pieces,
32x32 each, centred: the well (dim and lit rims) and one glyph per button.
The quality diamond is white, for code to tint with the least quality shown.
"""
import os
import subprocess
import sys
from io import BytesIO

from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_strips as S  # noqa: E402

W, H = S.W, S.H
GOLD, GOLD_D, INK, TEXT = S.GOLD, S.GOLD_D, S.INK, S.TEXT
DIM = "#b3a88c"
FONT = os.path.join(S.ROOT, "WoW", "Interface", "AddOns", "Medalluin", "media", "fonts", "MarcellusSC-Regular.ttf")

# the panel, in screen pixels: the chat's numbers, mirrored
TOP = H - S.STRIP_H - S.CHAT_H
PANEL = {-1: (S.CHAT_LEFT, S.LENGTH), 1: (W - S.LENGTH, W - S.CHAT_LEFT)}
ROW, ROW_GAP, HEAD = 16, 2, 18
MUTE = 0.8

CLASS = {"WARRIOR": "#c69b6d", "PALADIN": "#f48cba", "HUNTER": "#aad372", "ROGUE": "#fff468",
         "PRIEST": "#ffffff", "SHAMAN": "#0070dd", "MAGE": "#3fc7eb", "WARLOCK": "#8788ee", "DRUID": "#ff7c0a"}
QUALITY = {"epic": "#a335ee", "rare": "#0070dd", "uncommon": "#1eff00", "common": "#ffffff"}


def muted(hexa):
    r, g, b = (int(hexa[i:i + 2], 16) for i in (1, 3, 5))
    return f"#{int(r * MUTE):02x}{int(g * MUTE):02x}{int(b * MUTE):02x}"


def esc(s):
    return s.replace("&", "&amp;").replace("<", "&lt;").replace("'", "&#39;")


def text(x, y, s, anchor="start", size=11, fill=TEXT, family="Marcellus SC"):
    return (f'<text x="{x:.1f}" y="{y:.1f}" font-family="{family}" font-size="{size}" fill="{fill}" '
            f'text-anchor="{anchor}" stroke="#000" stroke-width="2" paint-order="stroke">{esc(s)}</text>')


# ------------------------------------------------------------------ chrome
def tab(x, label, selected, uid):
    """The chat's tab, drawn at its label's width (three slices in game)."""
    tw = max(S.TAB_W, int(len(label) * 7.2) + 28)
    top, r, y0 = TOP - S.TAB_H + S.TAB_TOP + 0.5, 5, TOP - S.TAB_H
    b = TOP
    d = (f"M{x + 1.5},{b} L{x + 1.5},{top + r} Q{x + 1.5},{top} {x + 1.5 + r},{top} L{x + tw - 1.5 - r},{top} "
         f"Q{x + tw - 1.5},{top} {x + tw - 1.5},{top + r} L{x + tw - 1.5},{b}")
    a, z = ("#4a5368", "#2c3242") if selected else ("#2c3242", "#1c202b")
    out = [f'<linearGradient id="t{uid}" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{a}"/>'
           f'<stop offset="1" stop-color="{z}"/></linearGradient>',
           f'<path d="{d} Z" fill="url(#t{uid})" fill-opacity="0.9"/>',
           f'<path d="{d}" fill="none" stroke="{"url(#gold)" if selected else GOLD_D}" stroke-width="1.4"/>']
    if selected:
        out.append(f'<line x1="{x + 2 + r}" y1="{top + 1.5}" x2="{x + tw - 2 - r}" y2="{top + 1.5}" '
                   f'stroke="#f0d488" stroke-width="1" opacity="0.6"/>')
    out.append(text(x + tw / 2, y0 + 25, label, "middle", 11, "#ffd200" if selected else "#c8aa50"))
    return "".join(out), tw


def tabs(side, labels, selected):
    """Tabs from the outer end inward, as the chat's run from its column."""
    l, r = PANEL[side]
    out, widths = [], [tab(0, lab, False, "w")[1] for lab in labels]
    if side < 0:
        x = l + S.CHAT_PAD + S.CHAT_COLUMN + 5
        for i, lab in enumerate(labels):
            svg_, tw = tab(x, lab, lab == selected, f"{side}{i}")
            out.append(svg_)
            x += tw + 1
    else:
        x = r - S.CHAT_PAD - S.CHAT_COLUMN - 5
        for i, lab in enumerate(labels):
            x -= widths[i]
            out.append(tab(x, lab, lab == selected, f"{side}{i}")[0])
            x -= 1
    return "".join(out)


def panel(side):
    l, r = PANEL[side]
    return (f'<rect x="{l}" y="{TOP}" width="{r - l}" height="{S.CHAT_H}" fill="url(#panel)"/>')


def column_x(side):
    l, r = PANEL[side]
    return (l + S.CHAT_PAD + S.CHAT_COLUMN / 2) if side < 0 else (r - S.CHAT_PAD - S.CHAT_COLUMN / 2)


def content_box(side):
    """Where lines go: between the column and the scroll bar."""
    l, r = PANEL[side]
    if side < 0:
        return l + S.CHAT_PAD + S.CHAT_COLUMN + 5, r - S.CHAT_RIGHT
    return l + S.CHAT_RIGHT, r - S.CHAT_PAD - S.CHAT_COLUMN - 5


def scrollbar(side):
    l, r = PANEL[side]
    x = (r - S.CHAT_RIGHT + 3) if side < 0 else (l + 3)
    return (f'<rect x="{x}" y="{TOP + 6}" width="8" height="{S.CHAT_H - 12}" rx="3" fill="#000" opacity="0.35"/>'
            f'<rect x="{x + 1}" y="{TOP + S.CHAT_H - 60}" width="6" height="40" rx="3" fill="{GOLD_D}" '
            f'opacity="0.8"/>')


# ---------------------------------------------------------- column glyphs
def well(cx, cy, inner, on=False):
    """A column button: 24x24, gold rim, ink well, a gold glyph."""
    rim = "url(#gold)" if on else GOLD_D
    return (f'<rect x="{cx - 12}" y="{cy - 12}" width="24" height="24" rx="4" fill="{INK}" fill-opacity="0.75" '
            f'stroke="{rim}" stroke-width="1.2"/>{inner}')


def g_clock(cx, cy):          # the current fight
    return (f'<circle cx="{cx}" cy="{cy}" r="7" fill="none" stroke="url(#gold)" stroke-width="1.8"/>'
            f'<path d="M{cx},{cy - 4.5} L{cx},{cy} L{cx + 3.5},{cy + 2}" fill="none" stroke="url(#gold)" '
            f'stroke-width="1.6" stroke-linecap="round"/>')


def g_sigma(cx, cy):          # overall
    return (f'<path d="M{cx + 5},{cy - 6.5} L{cx - 5},{cy - 6.5} L{cx + 1},{cy} L{cx - 5},{cy + 6.5} '
            f'L{cx + 5},{cy + 6.5}" fill="none" stroke="url(#gold)" stroke-width="1.8" stroke-linejoin="round"/>')


def g_columns(cx, cy, two):   # one column or two
    if two:
        return (f'<rect x="{cx - 7}" y="{cy - 6}" width="6" height="12" fill="url(#gold)"/>'
                f'<rect x="{cx + 1}" y="{cy - 6}" width="6" height="12" fill="url(#gold)"/>')
    return f'<rect x="{cx - 6}" y="{cy - 6}" width="12" height="12" fill="url(#gold)"/>'


def g_rate(cx, cy):           # per second vs total: "/s"
    return text(cx, cy + 4, "/s", "middle", 11, "#f0d488")


def g_reset(cx, cy):
    return (f'<path d="M{cx + 5.5},{cy - 2} A6,6 0 1,0 {cx + 5},{cy + 3.5}" fill="none" stroke="url(#gold)" '
            f'stroke-width="1.8"/><polygon points="{cx + 2.5},{cy - 4} {cx + 7.5},{cy - 5} {cx + 6.5},{cy}" '
            f'fill="url(#gold)"/>')


def g_filter(cx, cy):         # loot: who (group / mine)
    return (f'<path d="M{cx - 7},{cy - 6} L{cx + 7},{cy - 6} L{cx + 2},{cy} L{cx + 2},{cy + 6} L{cx - 2},{cy + 4} '
            f'L{cx - 2},{cy} Z" fill="url(#gold)"/>')


def g_quality(cx, cy):        # loot: least quality shown
    return (f'<polygon points="{cx},{cy - 7} {cx + 6},{cy} {cx},{cy + 7} {cx - 6},{cy}" fill="{QUALITY["epic"]}" '
            f'stroke="url(#gold)" stroke-width="1"/>')


def column(side, glyphs):
    """The column's buttons, top down; the last one sits at the foot."""
    cx = column_x(side)
    out = []
    for i, (g, on) in enumerate(glyphs[:-1]):
        cy = TOP + 16 + i * 30
        out.append(well(cx, cy, g(cx, cy), on))
    g, on = glyphs[-1]
    cy = TOP + S.CHAT_H - 16
    out.append(well(cx, cy, g(cx, cy), on))
    return "".join(out)


# ------------------------------------------------------------ the chat side
def chat_side():
    x0, _ = content_box(-1)
    lines = ["[Guild] Aldren: anyone for the raid tonight?", "You are no longer Away.",
             "[Trade] Selling Flask of the Currents", "[Party] Mira: pull in 3"]
    out = [panel(-1), tabs(-1, ["General", "Log", "Trade"], "General"), scrollbar(-1)]
    for i, s in enumerate(lines):
        out.append(text(x0, H - S.STRIP_H - 8 - 14 * (len(lines) - 1 - i), s, size=11))
    cx = column_x(-1)
    for cy in (TOP + 16, TOP + 46, TOP + S.CHAT_H - 16):
        out.append(f'<rect x="{cx - 12}" y="{cy - 12}" width="24" height="24" rx="4" fill="none" '
                   f'stroke="{GOLD}" stroke-width="1"/>')
    return "".join(out)


# ---------------------------------------------------------------- the loot
def item_icon(x, y, quality, hue):
    return (f'<rect x="{x}" y="{y}" width="{ROW}" height="{ROW}" fill="#000"/>'
            f'<rect x="{x + 1}" y="{y + 1}" width="{ROW - 2}" height="{ROW - 2}" fill="{hue}"/>'
            f'<rect x="{x + 0.5}" y="{y + 0.5}" width="{ROW - 1}" height="{ROW - 1}" fill="none" '
            f'stroke="{QUALITY[quality]}" stroke-width="1"/>')


def how_glyph(x, y, how):
    """Right of the winner: the roll (die + number), personal (a hand), money."""
    if how.startswith("need") or how.startswith("greed"):
        kind, n = how.split()
        col = "#e8c050" if kind == "need" else "#7fb860"
        return (f'<rect x="{x}" y="{y + 3}" width="10" height="10" rx="2" fill="none" stroke="{col}" '
                f'stroke-width="1.3"/><circle cx="{x + 5}" cy="{y + 8}" r="1.3" fill="{col}"/>'
                + text(x + 13, y + 12, n, size=10, fill=col))
    if how == "personal":
        return text(x, y + 12, "personal", size=9, fill=DIM)
    return ""


def loot_side(selected="Loot"):
    x0, x1 = content_box(1)
    out = [panel(1), tabs(1, ["Loot", "Meter"], selected), scrollbar(1),
           column(1, [(g_filter, True), (g_quality, False), (g_reset, False)])]
    rows = [
        ("head", "Gurtogg Bloodboil", "21:14  ·  14g 20s"),
        ("item", "epic", "#6a3a8a", "Shoulderpads of Renewed Life", "Mira", "PRIEST", "need 87"),
        ("item", "epic", "#3a5a8a", "Girdle of Lordaeron's Fallen", "Aldren", "WARRIOR", "need 64"),
        ("item", "rare", "#2a5a6a", "Bloodboil's Severed Fang", "Ahrymx", "HUNTER", "personal"),
        ("head", "Trash  ·  Black Temple", "21:02  ·  6g 75s"),
        ("item", "rare", "#5a4a2a", "Ashtongue Signet", "Thalen", "MAGE", "greed 51"),
        ("item", "uncommon", "#3a6a3a", "Felsteel Bar  x4", "Ahrymx", "HUNTER", "personal"),
        ("item", "uncommon", "#4a3a3a", "Netherweave Cloth  x12", "Mira", "PRIEST", "personal"),
    ]
    y = TOP + 4
    for r in rows:
        if r[0] == "head":
            out.append(f'<line x1="{x0}" y1="{y + HEAD - 2}" x2="{x1}" y2="{y + HEAD - 2}" stroke="{GOLD_D}" '
                       f'stroke-width="0.8" opacity="0.8"/>')
            out.append(text(x0 + 2, y + 12, r[1], size=11, fill="#f0d488"))
            out.append(text(x1 - 2, y + 12, r[2], "end", 10, DIM, family="Arial"))
            y += HEAD + 1
            continue
        _, q, hue, name, who, cls, how = r
        out.append(item_icon(x0 + 2, y, q, hue))
        out.append(f'<clipPath id="lc{y}"><rect x="{x0 + 22}" y="{y}" width="{x1 - x0 - 140}" height="{ROW}"/>'
                   f'</clipPath><g clip-path="url(#lc{y})">'
                   + text(x0 + 22, y + 12, f"[{name}]", size=10, fill=QUALITY[q], family="Arial") + '</g>')
        out.append(text(x1 - 62, y + 12, who, "end", 10, CLASS[cls]))
        out.append(how_glyph(x1 - 56, y, how))
        y += ROW + ROW_GAP
    return "".join(out)


# --------------------------------------------------------------- the meter
DPS = [("Thalen", "MAGE", 12400), ("Aldren", "WARRIOR", 11050), ("Ahrymx", "HUNTER", 10380),
       ("Kesh", "ROGUE", 9720), ("Varo", "WARLOCK", 8840), ("Mira", "PRIEST", 1220), ("Brann", "PALADIN", 640)]
HPS = [("Mira", "PRIEST", 9880), ("Brann", "PALADIN", 7310), ("Ylla", "SHAMAN", 5120), ("Aldren", "WARRIOR", 610),
       ("Ahrymx", "HUNTER", 240)]


def short(n):
    return f"{n / 1000:.1f}K" if n >= 1000 else str(n)


def meter_list(x0, x1, title, data, rate=True):
    """A header (what, which fight, how long), then one bar per player: spec
    icon, name, value; bar length against the session's top amount."""
    out = [f'<line x1="{x0}" y1="{TOP + 4 + HEAD - 2}" x2="{x1}" y2="{TOP + 4 + HEAD - 2}" stroke="{GOLD_D}" '
           f'stroke-width="0.8" opacity="0.8"/>',
           text(x0 + 2, TOP + 16, title, size=11, fill="#f0d488"),
           text(x1 - 2, TOP + 16, "Current  1:42", "end", 10, DIM, family="Arial")]
    top = max(v for _, _, v in data)
    y = TOP + 4 + HEAD + 1
    for name, cls, v in data:
        w = (x1 - x0) * v / top
        out.append(f'<rect x="{x0}" y="{y}" width="{x1 - x0}" height="{ROW}" fill="#000" opacity="0.35"/>')
        out.append(f'<rect x="{x0}" y="{y}" width="{w:.1f}" height="{ROW}" fill="{muted(CLASS[cls])}" '
                   f'opacity="0.85"/>')
        out.append(f'<rect x="{x0}" y="{y}" width="{w:.1f}" height="{ROW / 2}" fill="#fff" opacity="0.08"/>')
        out.append(f'<rect x="{x0 + 1}" y="{y + 1}" width="{ROW - 2}" height="{ROW - 2}" fill="{INK}" '
                   f'stroke="{GOLD_D}" stroke-width="0.8"/>'
                   f'<circle cx="{x0 + ROW / 2}" cy="{y + ROW / 2}" r="4.5" fill="{CLASS[cls]}" opacity="0.9"/>')
        out.append(text(x0 + ROW + 3, y + 12, name, size=10))
        out.append(text(x1 - 3, y + 12, short(v) if rate else short(v * 102), "end", 10))
        y += ROW + ROW_GAP
    return "".join(out)


def meter_side(two):
    x0, x1 = content_box(1)
    out = [panel(1), tabs(1, ["Loot", "Meter"], "Meter"), scrollbar(1),
           column(1, [(g_clock, True), (g_rate, True), (lambda cx, cy: g_columns(cx, cy, two), two),
                      (g_reset, False)])]
    if two:
        mid = (x0 + x1) / 2
        out.append(meter_list(x0, mid - 3, "DPS", DPS))
        out.append(meter_list(mid + 3, x1, "HPS", HPS))
    else:
        out.append(meter_list(x0, x1, "Damage per second", DPS))
    return "".join(out)


# ----------------------------------------------------------- the bag drawer
SLOT = 30


def bag_slot(x, y):
    return (f'<rect x="{x}" y="{y}" width="{SLOT - 4}" height="{SLOT - 4}" rx="3" fill="{INK}" '
            f'stroke="{GOLD_D}" stroke-width="1.2"/>' + S.backpack(x + 13, y + 13))


def drawer_column():
    """D1: the drawer as a column over the backpack's medallion: key ring,
    reagent, bags 3..0, bottom up, the mirror of the buff column."""
    cx = W - S.MED_R - 10
    n = 6
    h = n * SLOT + 8
    x, y = cx - SLOT / 2 - 2, S.MED_Y - S.MED_R - 6 - h
    out = [f'<rect x="{x}" y="{y}" width="{SLOT + 4}" height="{h}" rx="4" fill="url(#navy)" stroke="{GOLD_D}" '
           f'stroke-width="1.4"/>']
    for i in range(n):
        out.append(bag_slot(x + 4, y + 4 + i * SLOT))
    return "".join(out)


def drawer_row():
    """D2: the drawer as a row lying over the panel's foot, from the column inward."""
    x0, x1 = content_box(1)
    n = 6
    w = n * SLOT + 8
    x, y = x1 - w, TOP + S.CHAT_H - SLOT - 10
    out = [f'<rect x="{x}" y="{y}" width="{w}" height="{SLOT + 6}" rx="4" fill="url(#navy)" stroke="{GOLD}" '
           f'stroke-width="1.4"/>']
    for i in range(n):
        out.append(bag_slot(x + 4 + i * SLOT, y + 4))
    return "".join(out)


def buff_column():
    """The timeless buffs over the portrait (already in game), for comparison."""
    cx = S.MED_R + 10
    out = []
    for i, hue in enumerate(("#c0603a", "#5a6ab0", "#8a5ab0")):
        y = S.MED_Y - S.MED_R - 8 - (i + 1) * 26
        out.append(f'<rect x="{cx - 11}" y="{y}" width="22" height="22" fill="#000"/>'
                   f'<rect x="{cx - 10}" y="{y + 1}" width="20" height="20" fill="{hue}"/>')
    return "".join(out)


# ------------------------------------------------------------------ render
def defs():
    return ('<linearGradient id="panel" x1="0" y1="0" x2="0" y2="1">'
            '<stop offset="0" stop-color="#000000" stop-opacity="0"/>'
            '<stop offset="1" stop-color="#000000" stop-opacity="0.80"/></linearGradient>')


def screen(right, drawer=None):
    body = defs() + chat_side() + buff_column() + right + (drawer or "")
    doc = S.svg(body)
    png = subprocess.run(["rsvg-convert"], input=doc.encode(), check=True, capture_output=True).stdout
    base = Image.open(os.path.join(S.OUT, "strips-B-screen.png")).convert("RGBA")
    over = Image.open(BytesIO(png)).convert("RGBA")
    img = Image.alpha_composite(base, over)
    return img


def corner(img, side):
    l, r = PANEL[side]
    box = (0, TOP - 50, S.LENGTH + 60, H) if side < 0 else (W - S.LENGTH - 60, TOP - 50, W, H)
    c = img.crop(box).convert("RGB")
    return c.resize((c.width * 2, c.height * 2), Image.LANCZOS)


def main():
    font = ImageFont.truetype(FONT, 26)
    tiles = []
    both = screen(loot_side(), drawer_column())
    band = both.crop((0, TOP - 260, W, H)).convert("RGB")
    tiles.append(("Both corners: chat on the left, its mirror on the right (Loot tab; drawer D1 open)", band))
    tiles.append(("Loot: by encounter, newest first; item, winner (class colour), how (roll, personal)",
                  corner(screen(loot_side()), 1)))
    tiles.append(("Meter, one column: what / which fight / how long, then bars against the top amount",
                  corner(screen(meter_side(False)), 1)))
    tiles.append(("Meter, two columns: DPS | HPS, each its own list", corner(screen(meter_side(True)), 1)))
    tiles.append(("D1: the bag drawer as a column over the backpack (mirrors the buff column)",
                  corner(screen(meter_side(True), drawer_column()), 1)))
    tiles.append(("D2: the bag drawer as a row over the panel's foot", corner(screen(meter_side(True),
                                                                                       drawer_row()), 1)))
    lab = 44
    band_label, band_img = tiles[0]
    grid = tiles[1:]
    cw, ch = grid[0][1].width, grid[0][1].height
    cols = 2
    rows = (len(grid) + cols - 1) // cols
    width = max(band_img.width, cols * cw + 8)
    sheet = Image.new("RGB", (width, band_img.height + lab + rows * (ch + lab)), "#0b0c10")
    d = ImageDraw.Draw(sheet)
    d.text((16, 8), band_label, font=font, fill=TEXT)
    sheet.paste(band_img, (0, lab))
    y0 = band_img.height + lab
    small = ImageFont.truetype(FONT, 22)
    for i, (label, t) in enumerate(grid):
        x, y = (i % cols) * (cw + 8), y0 + (i // cols) * (ch + lab)
        d.text((x + 14, y + 10), label, font=small, fill=TEXT)
        sheet.paste(t, (x, y + lab))
    path = os.path.join(S.OUT, "sidepanel.png")
    sheet.save(path)
    print(path, sheet.size)


# --------------------------------------------------------------- the auras
# (2026-11-01) A third tab: the player's buffs and debuffs, longest time left
# first. The client sorts them (C_UnitAuras.GetUnitAuras, ExpirationOnly,
# Reverse), so the order holds in combat, when the times are secret.
DISPEL = {"Magic": "#3399ff", "Curse": "#9933ff", "Poison": "#009900", "Disease": "#996600", None: "#c03030"}
# name, kind (buff / debuff type), time left (s, None = timeless), full duration, stacks, icon hue
AURAS = [
    ("Aspect of the Hawk", "buff", None, None, 0, "#7a6a2a"),
    ("Flask of the Currents", "buff", 4360, 7200, 0, "#2a5a7a"),
    ("Arcane Intellect", "buff", 3500, 3600, 0, "#4a3a8a"),
    ("Power Word: Fortitude", "buff", 2465, 3600, 0, "#6a6a6a"),
    ("Well Fed", "buff", 1450, 3600, 0, "#7a5a2a"),
    ("Sated", None, 492, 600, 0, "#5a2a2a"),
    ("Bloodlust", "buff", 28, 40, 0, "#8a2a2a"),
    ("Fel Rage", "Magic", 18, 30, 3, "#3a6a2a"),
    ("Rejuvenation", "buff", 11, 15, 0, "#3a7a3a"),
    ("Crippling Poison", "Poison", 6, 12, 0, "#2a6a3a"),
]


def clock(t):
    if t is None:
        return ""
    if t >= 3600:
        return f"{t // 3600}:{t % 3600 // 60:02d}:{t % 60:02d}"
    if t >= 60:
        return f"{t // 60}:{t % 60:02d}"
    return f"{t}s"


def g_timeless(cx, cy):       # auras: the timeless ones shown or not
    return (f'<path d="M{cx},{cy} C{cx - 3},{cy - 5} {cx - 8},{cy - 5} {cx - 8},{cy} C{cx - 8},{cy + 5} {cx - 3},{cy + 5} '
            f'{cx},{cy} C{cx + 3},{cy - 5} {cx + 8},{cy - 5} {cx + 8},{cy} C{cx + 8},{cy + 5} {cx + 3},{cy + 5} {cx},{cy} Z" '
            f'fill="none" stroke="url(#gold)" stroke-width="1.8"/>')


def aura_list(x0, x1, title, data, timeless=True):
    """A heading (what, how many), then one row per aura: its icon (edged in
    the debuff's dispel colour, or gold), its name, a bar of the time left
    against its full duration, the time left. Timeless ones first, barless."""
    shown = [a for a in data if timeless or a[2] is not None]
    out = [f'<line x1="{x0}" y1="{TOP + 4 + HEAD - 2}" x2="{x1}" y2="{TOP + 4 + HEAD - 2}" stroke="{GOLD_D}" '
           f'stroke-width="0.8" opacity="0.8"/>',
           text(x0 + 2, TOP + 16, title, size=11, fill="#f0d488"),
           text(x1 - 2, TOP + 16, f"{len(shown)}", "end", 10, DIM, family="Arial")]
    y = TOP + 4 + HEAD + 1
    for name, kind, left, full, stacks, hue in shown:
        if y + ROW > TOP + S.CHAT_H - 4:
            break
        debuff = kind != "buff"
        edge = DISPEL[kind] if debuff else GOLD_D
        tone = "#8a3a30" if debuff else "#8a7034"
        out.append(f'<rect x="{x0}" y="{y}" width="{x1 - x0}" height="{ROW}" fill="#000" opacity="0.35"/>')
        bx = x0 + ROW + 2
        if left is not None:
            w = (x1 - bx) * left / full
            out.append(f'<rect x="{bx}" y="{y}" width="{w:.1f}" height="{ROW}" fill="{tone}" opacity="0.75"/>'
                       f'<rect x="{bx}" y="{y}" width="{w:.1f}" height="{ROW / 2}" fill="#fff" opacity="0.07"/>')
        out.append(f'<rect x="{x0 + 0.5}" y="{y + 0.5}" width="{ROW - 1}" height="{ROW - 1}" fill="{hue}" '
                   f'stroke="{edge}" stroke-width="1.2"/>')
        if stacks:
            out.append(text(x0 + ROW - 1, y + ROW - 1, str(stacks), "end", 9, "#fff", family="Arial"))
        out.append(f'<clipPath id="ac{x0}{y}"><rect x="{bx + 2}" y="{y}" width="{x1 - bx - 46}" height="{ROW}"/>'
                   f'</clipPath><g clip-path="url(#ac{x0}{y})">' + text(bx + 3, y + 12, name, size=10) + '</g>')
        out.append(text(x1 - 3, y + 12, clock(left), "end", 10, "#ff8070" if debuff and left and left < 10
                        else TEXT, family="Arial"))
        y += ROW + ROW_GAP
    return "".join(out)


def auras_side(two, timeless=True):
    x0, x1 = content_box(1)
    out = [panel(1), tabs(1, ["Loot", "Meter", "Auras"], "Auras"), scrollbar(1),
           column(1, [(lambda cx, cy: g_columns(cx, cy, two), two), (g_timeless, timeless)])]
    if two:
        mid = (x0 + x1) / 2
        out.append(aura_list(x0, mid - 3, "Buffs", [a for a in AURAS if a[1] == "buff"], timeless))
        out.append(aura_list(mid + 3, x1, "Debuffs", [a for a in AURAS if a[1] != "buff"], timeless))
    else:
        out.append(aura_list(x0, x1, "Buffs and debuffs", AURAS, timeless))
    return "".join(out)


def auras_sheet():
    font = ImageFont.truetype(FONT, 22)
    tiles = [("A: one list, buffs and debuffs together, longest first (timeless at the top)",
              corner(screen(auras_side(False)), 1)),
             ("B: Buffs | Debuffs side by side, each longest first (the meter's two-list button)",
              corner(screen(auras_side(True)), 1)),
             ("A with the timeless ones hidden (the infinity button)",
              corner(screen(auras_side(False, False)), 1))]
    lab = 40
    cw, ch = tiles[0][1].width, tiles[0][1].height
    sheet = Image.new("RGB", (2 * cw + 8, 2 * (ch + lab)), "#0b0c10")
    d = ImageDraw.Draw(sheet)
    for i, (label, t) in enumerate(tiles):
        x, y = (i % 2) * (cw + 8), (i // 2) * (ch + lab)
        d.text((x + 14, y + 8), label, font=font, fill=TEXT)
        sheet.paste(t, (x, y + lab))
    path = os.path.join(S.OUT, "sidepanel-auras.png")
    sheet.save(path)
    print(path, sheet.size)


def parts():
    out = os.path.join(S.ROOT, "assets", "strips")
    c = 16
    white = (f'<polygon points="{c},{c - 7} {c + 6},{c} {c},{c + 7} {c - 6},{c}" fill="#fff" '
             f'stroke="#2a1e08" stroke-width="1"/>')
    pieces = {
        "side-well": well(c, c, "", False),
        "side-well-on": well(c, c, "", True),
        "side-current": g_clock(c, c),
        "side-overall": g_sigma(c, c),
        "side-rate": (f'<text x="{c}" y="{c + 4.5}" font-family="DejaVu Sans" font-weight="bold" font-size="13" '
                      f'fill="#e8c96e" stroke="#2a1e08" stroke-width="0.4" text-anchor="middle">/s</text>'),
        "side-one": g_columns(c, c, False),
        "side-two": g_columns(c, c, True),
        "side-reset": g_reset(c, c),
        "side-filter": g_filter(c, c),
        "side-quality": white,
        "side-timeless": g_timeless(c, c),
    }
    for name, inner in pieces.items():
        doc = S.svg(inner).replace(f'width="{W}" height="{H}"', 'width="32" height="32"')
        subprocess.run(["rsvg-convert", "-o", os.path.join(out, name + ".png")], input=doc.encode(), check=True)
    # Medalluin's own minimap button: the medal of assets/medalluin-icon.svg
    # (its letters want the Cinzel fonts installed), at twice the button's
    # 32 pixels so a UI scale over 1 stays sharp
    subprocess.run(["rsvg-convert", "-w", "64", "-h", "64", "-o", os.path.join(out, "minimap-button.png"),
                    os.path.join(S.ROOT, "assets", "medalluin-icon.svg")], check=True)
    print(out, len(pieces) + 1, "side parts")


if __name__ == "__main__":
    if sys.argv[1:] == ["parts"]:
        parts()
    elif sys.argv[1:] == ["auras"]:
        auras_sheet()
    else:
        main()
