r"""The dead and offline frame art (dead.lua):
  * media/dead-wings.tga:   angel-investor.png in the console's gold with
                            sculpted wing/medallion relief and a dark rim (64x64)
  * media/disconnected.tga: disconnected.png in cool silver-steel with a
                            sculpted sheen and dark rim (64x64)
  * media/dead-bar.tga:     smooth 45-degree (///) chiseled tomb-stone bands
                            with obsidian fracture veins and a dark crimson
                            mortuary sheen (512x128, cropped 1:1 by TexCoord)
  * media/offline-bar.tga:  smooth 135-degree (\\\) steel hazard bands crossed
                            by horizontal signal scanlines in cool slate-blue
                            (512x128, cropped 1:1 by TexCoord)
"""
import os

import numpy as np
from PIL import Image, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
MEDIA = os.path.join(HERE, "..", "..", "WoW", "Interface", "AddOns", "Medalluin", "media")
RENDER = os.path.join(HERE, "render")
SIZE = 64


def smoothstep(edge0, edge1, x):
    t = np.clip((x - edge0) / (edge1 - edge0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def make_dead_icon(src_path):
    mask_img = Image.open(src_path).convert("RGBA").getchannel("A")
    arr_m = np.array(mask_img)
    arr_m = np.maximum(arr_m, np.fliplr(arr_m))
    # Sculpt the medallion disc (cx=255.5, cy=298.5, R=127.5) and wing feathers
    # inside the 512x512 source before cropping so it reads crisply at 16-20px
    y5, x5 = np.mgrid[0:512, 0:512].astype(np.float32)
    r_disc = np.hypot(x5 - 255.5, y5 - 298.5)
    # Dark bronze seam where the wings meet the central orb (r ~ 125..131)
    # and a subtle inner medallion ring (r ~ 88..94)
    seam_outer = np.exp(-((r_disc - 126.5) / 5.5) ** 2) * np.clip((295.0 - y5) / 25.0, 0.0, 1.0)
    ring_groove = np.exp(-((r_disc - 90.0) / 4.5) ** 2)
    ring_hilite = np.exp(-((r_disc - 83.0) / 4.0) ** 2)
    disc_dome = np.clip(1.0 - (r_disc / 127.5) ** 2, 0.0, 1.0) * 0.18

    mask_crop = Image.fromarray(arr_m).crop(Image.fromarray(arr_m).getbbox())
    bx0, by0, bx1, by1 = Image.fromarray(arr_m).getbbox()
    pad = 24
    side = max(mask_crop.size) + 2 * pad
    sq = Image.new("L", (side, side), 0)
    ox, oy = (side - mask_crop.size[0]) // 2, (side - mask_crop.size[1]) // 2
    sq.paste(mask_crop, (ox, oy))

    # Map relief arrays into sq coordinates
    relief = np.ones((side, side), dtype=np.float32)
    carve = (1.0 - 0.52 * seam_outer - 0.38 * ring_groove + 0.22 * ring_hilite + disc_dome)
    relief[oy:oy + (by1 - by0), ox:ox + (bx1 - bx0)] = carve[by0:by1, bx0:bx1]

    sq_arr = np.array(sq, dtype=np.float32) / 255.0
    eroded = np.array(sq.filter(ImageFilter.MinFilter(9)), dtype=np.float32) / 255.0
    inner_bevel = np.clip(sq_arr - eroded * 0.35, 0, 1)

    y_grad = np.linspace(0.0, 1.0, side, dtype=np.float32)[:, None]
    top_col, bot_col = (248, 214, 112), (194, 146, 46)
    r = top_col[0] * (1 - y_grad) + bot_col[0] * y_grad
    g = top_col[1] * (1 - y_grad) + bot_col[1] * y_grad
    b = top_col[2] * (1 - y_grad) + bot_col[2] * y_grad

    shade = (0.84 + 0.22 * inner_bevel) * relief
    rgb = np.dstack([
        np.clip(r * shade, 0, 255),
        np.clip(g * shade, 0, 255),
        np.clip(b * shade, 0, 255),
        sq_arr * 255.0,
    ]).astype(np.uint8)
    glyph = Image.fromarray(rgb, "RGBA")

    rim = Image.new("RGBA", sq.size, (6, 6, 8, 255))
    rim.putalpha(sq.filter(ImageFilter.MaxFilter(15)))
    return Image.alpha_composite(rim, glyph).resize((SIZE, SIZE), Image.Resampling.LANCZOS)


def make_offline_icon(src_path):
    mask_img = Image.open(src_path).convert("RGBA").getchannel("A")
    mask = mask_img.crop(mask_img.getbbox())
    pad = 24
    side = max(mask.size) + 2 * pad
    sq = Image.new("L", (side, side), 0)
    sq.paste(mask, ((side - mask.size[0]) // 2, (side - mask.size[1]) // 2))

    sq_arr = np.array(sq, dtype=np.float32) / 255.0
    eroded = np.array(sq.filter(ImageFilter.MinFilter(9)), dtype=np.float32) / 255.0
    inner_bevel = np.clip(sq_arr - eroded * 0.35, 0, 1)

    y_grad = np.linspace(0.0, 1.0, side, dtype=np.float32)[:, None]
    top_col, bot_col = (236, 242, 250), (160, 175, 196)
    r = top_col[0] * (1 - y_grad) + bot_col[0] * y_grad
    g = top_col[1] * (1 - y_grad) + bot_col[1] * y_grad
    b = top_col[2] * (1 - y_grad) + bot_col[2] * y_grad
    shade = 0.84 + 0.22 * inner_bevel
    rgb = np.dstack([
        np.clip(r * shade, 0, 255),
        np.clip(g * shade, 0, 255),
        np.clip(b * shade, 0, 255),
        sq_arr * 255.0,
    ]).astype(np.uint8)
    glyph = Image.fromarray(rgb, "RGBA")

    rim = Image.new("RGBA", sq.size, (6, 6, 8, 255))
    rim.putalpha(sq.filter(ImageFilter.MaxFilter(15)))
    return Image.alpha_composite(rim, glyph).resize((SIZE, SIZE), Image.Resampling.LANCZOS)


def make_dead_bar(w=512, h=128, seed=107):
    """512x128 RGBA overlay for dead frames: anti-aliased 45-degree (///)
    chiseled bands, Voronoi stone fractures, and a dark crimson-bronze tone."""
    np.random.seed(seed)
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)

    # 1. Anti-aliased 45-degree (///) chiseled diagonal bands (12px period)
    period = 12.0
    phase = ((x + y) % period) / period
    # Smoothly transition at both edges of the band so there is no stair-stepping
    up = smoothstep(0.0, 0.14, phase)
    down = 1.0 - smoothstep(0.46, 0.60, phase)
    band = up * down
    ridge = np.exp(-((phase - 0.12) / 0.08) ** 2)
    groove = np.exp(-((phase - 0.78) / 0.15) ** 2)

    # 2. Subtle Voronoi stone fracture cracks across the surface
    pts_x = np.random.uniform(-20, w + 20, 220).astype(np.float32)
    pts_y = np.random.uniform(-20, h + 20, 220).astype(np.float32)
    qx = x + 2.2 * np.sin(y / 7.0)
    qy = y + 2.2 * np.cos(x / 9.0)
    dx = qx[:, :, None] - pts_x[None, None, :]
    dy = qy[:, :, None] - pts_y[None, None, :]
    d2 = dx * dx + dy * dy
    part = np.partition(d2, 2, axis=2)[:, :, :2]
    crack_dist = (np.sqrt(part[:, :, 1]) - np.sqrt(part[:, :, 0])) * 0.5
    crack_dark = np.clip(1.0 - crack_dist / 1.35, 0, 1) ** 1.8
    crack_lip = np.clip(1.0 - np.abs(crack_dist - 1.55) / 0.85, 0, 1) * 0.45

    # 3. Blend smoothly between deep blood-charcoal grooves and crimson-bronze bands
    t_light = np.clip(band * (1.0 - crack_dark * 0.85), 0.0, 1.0)
    dark_rgb = np.array([12.0, 5.0, 7.0], dtype=np.float32)
    light_rgb = np.array([138.0, 58.0, 54.0], dtype=np.float32)

    rgb = (
        dark_rgb[None, None, :] * (1.0 - t_light[:, :, None])
        + light_rgb[None, None, :] * t_light[:, :, None]
        + (ridge + crack_lip * 0.5)[:, :, None] * np.array([38.0, 24.0, 18.0])[None, None, :]
    )
    alpha = np.clip(
        0.46 * (1.0 - t_light) + 0.22 * groove + 0.42 * crack_dark + 0.36 * t_light + 0.26 * ridge,
        0.0,
        0.74,
    )

    out = np.dstack([
        np.clip(rgb[:, :, 0], 0, 255),
        np.clip(rgb[:, :, 1], 0, 255),
        np.clip(rgb[:, :, 2], 0, 255),
        np.clip(alpha * 255.0, 0, 255),
    ]).astype(np.uint8)
    return Image.fromarray(out, "RGBA")


def make_offline_bar(w=512, h=128):
    """512x128 RGBA overlay for offline frames: anti-aliased 135-degree (\\\\\\)
    hazard bands crossed by horizontal signal scanlines in cool steel-slate."""
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)

    # 1. Anti-aliased 135-degree (\\\) opposite-angle diagonal bands (14px period)
    period = 14.0
    phase = ((x - y) % period) / period
    up = smoothstep(0.0, 0.14, phase)
    down = 1.0 - smoothstep(0.44, 0.58, phase)
    band = up * down
    ridge = np.exp(-((phase - 0.12) / 0.08) ** 2)

    # 2. Smooth horizontal signal scanlines (3px period)
    scan = 0.5 + 0.5 * np.cos(2.0 * np.pi * y / 3.0)
    scan_groove = np.clip(1.0 - scan, 0.0, 1.0)

    t_light = np.clip(band * (0.45 + 0.55 * scan), 0.0, 1.0)
    dark_rgb = np.array([7.0, 10.0, 15.0], dtype=np.float32)
    light_rgb = np.array([92.0, 114.0, 142.0], dtype=np.float32)

    rgb = (
        dark_rgb[None, None, :] * (1.0 - t_light[:, :, None])
        + light_rgb[None, None, :] * t_light[:, :, None]
        + (ridge * scan)[:, :, None] * np.array([28.0, 36.0, 46.0])[None, None, :]
    )
    alpha = np.clip(
        0.48 * (1.0 - band) + 0.30 * scan_groove + 0.34 * t_light + 0.24 * ridge,
        0.0,
        0.74,
    )

    out = np.dstack([
        np.clip(rgb[:, :, 0], 0, 255),
        np.clip(rgb[:, :, 1], 0, 255),
        np.clip(rgb[:, :, 2], 0, 255),
        np.clip(alpha * 255.0, 0, 255),
    ]).astype(np.uint8)
    return Image.fromarray(out, "RGBA")


def main():
    os.makedirs(MEDIA, exist_ok=True)
    os.makedirs(RENDER, exist_ok=True)

    dead_icon = make_dead_icon(os.path.join(HERE, "angel-investor.png"))
    dead_icon.save(os.path.join(MEDIA, "dead-wings.tga"))
    dead_icon.save(os.path.join(RENDER, "dead-wings.png"))

    off_icon = make_offline_icon(os.path.join(HERE, "disconnected.png"))
    off_icon.save(os.path.join(MEDIA, "disconnected.tga"))
    off_icon.save(os.path.join(RENDER, "disconnected.png"))

    dead_bar = make_dead_bar()
    dead_bar.save(os.path.join(MEDIA, "dead-bar.tga"))
    dead_bar.save(os.path.join(RENDER, "dead-bar.png"))

    off_bar = make_offline_bar()
    off_bar.save(os.path.join(MEDIA, "offline-bar.tga"))
    off_bar.save(os.path.join(RENDER, "offline-bar.png"))
    print("Generated dead-wings.tga, disconnected.tga, dead-bar.tga, offline-bar.tga")


if __name__ == "__main__":
    main()
