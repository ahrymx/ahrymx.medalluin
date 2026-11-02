r"""The resurrect icon on a dead friend's frame (dead.lua): the user's
wings.png (a black glyph, its alpha the shape) in the console's gold, with
a dark rim so it reads on any dead colour. Saved as media/dead-wings.tga.
"""
import os

from PIL import Image, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
MEDIA = os.path.join(HERE, "..", "..", "WoW", "Interface", "AddOns", "Medalluin", "media")
RENDER = os.path.join(HERE, "render")
GOLD = (224, 184, 74, 255)
SIZE = 64


def main():
    mask = Image.open(os.path.join(HERE, "wings.png")).convert("RGBA").getchannel("A")
    mask = mask.crop(mask.getbbox())
    # square, with room for the rim
    side = max(mask.size) + 40
    sq = Image.new("L", (side, side), 0)
    sq.paste(mask, ((side - mask.size[0]) // 2, (side - mask.size[1]) // 2))
    gold = Image.new("RGBA", sq.size, GOLD)
    gold.putalpha(sq)
    rim = Image.new("RGBA", sq.size, (0, 0, 0, 255))
    rim.putalpha(sq.filter(ImageFilter.MaxFilter(15)))
    out = Image.alpha_composite(rim, gold).resize((SIZE, SIZE), Image.Resampling.LANCZOS)
    out.save(os.path.join(MEDIA, "dead-wings.tga"))
    out.save(os.path.join(RENDER, "dead-wings.png"))
    print("Generated dead-wings.tga")


if __name__ == "__main__":
    main()
