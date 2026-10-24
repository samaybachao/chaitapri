#!/usr/bin/env python3
"""Draws every icon / launch image of the game (no artwork files are needed).

Run from the project root:   python tool/make_icons.py
Needs Pillow:                pip install pillow

It (re)creates:
  android/app/src/main/res/mipmap-*/ic_launcher*.png      launcher icons (legacy, round, adaptive)
  android/app/src/main/res/drawable-nodpi/launch_logo.png start-up logo
  assets/images/logo.png                                  logo inside the game
  store/graphics/icon-512.png, feature-graphic-1024x500.png   Google Play listing graphics
"""
import math
import os
import sys

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RES = os.path.join(ROOT, "android", "app", "src", "main", "res")

SAFFRON = (244, 160, 36, 255)
SAFFRON_LIGHT = (255, 190, 70, 255)
CREAM = (255, 244, 224, 255)
CHAI = (139, 74, 26, 255)
CHAI_DARK = (96, 50, 16, 255)
CHAI_LIGHT = (201, 139, 78, 255)
MILK_TEA = (233, 178, 122, 255)
WHITE = (255, 255, 255, 255)
GOLD = (255, 193, 7, 255)
GOLD_DARK = (214, 150, 0, 255)

SUPER = 1024  # drawing canvas; everything is scaled down from here


def cup_picture(mono=False):
    """The cup of chai with steam and a coin, on a transparent 1024x1024 canvas.

    Everything stays inside the centre circle of radius 0.30 * size (the adaptive icon
    "safe zone"), so no launcher mask can cut it.
    """
    s = SUPER
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    def col(c):
        return (0, 0, 0, 255) if mono else c

    cx = s * 0.5
    # Saucer.
    d.ellipse([cx - 0.235 * s, 0.700 * s, cx + 0.235 * s, 0.775 * s], fill=col(CREAM))
    # Cup body (a trapezoid with a round bottom).
    top_y, bot_y = 0.505 * s, 0.735 * s
    top_w, bot_w = 0.195 * s, 0.135 * s
    body = [
        (cx - top_w, top_y), (cx + top_w, top_y),
        (cx + bot_w, bot_y - 0.04 * s), (cx + bot_w - 0.03 * s, bot_y),
        (cx - bot_w + 0.03 * s, bot_y), (cx - bot_w, bot_y - 0.04 * s),
    ]
    d.polygon(body, fill=col(CHAI))
    d.ellipse([cx - bot_w, bot_y - 0.07 * s, cx + bot_w, bot_y + 0.012 * s], fill=col(CHAI))
    def half_width(y):
        return top_w + (bot_w - top_w) * (y - top_y) / (bot_y - top_y)

    if not mono:
        # Darker band and a light highlight on the clay (both follow the slope of the cup).
        y1, y2 = top_y + 0.085 * s, top_y + 0.115 * s
        d.polygon([(cx - half_width(y1) * 0.995, y1), (cx + half_width(y1) * 0.995, y1),
                   (cx + half_width(y2) * 0.995, y2), (cx - half_width(y2) * 0.995, y2)],
                  fill=CHAI_DARK)
        ya, yb = top_y + 0.035 * s, bot_y - 0.05 * s
        d.polygon([(cx - half_width(ya) * 0.84, ya), (cx - half_width(ya) * 0.66, ya),
                   (cx - half_width(yb) * 0.66, yb), (cx - half_width(yb) * 0.84, yb)],
                  fill=CHAI_LIGHT)
    # Rim and the tea inside.
    d.ellipse([cx - top_w - 0.012 * s, top_y - 0.035 * s, cx + top_w + 0.012 * s, top_y + 0.035 * s],
              fill=col(CHAI_LIGHT))
    d.ellipse([cx - top_w + 0.014 * s, top_y - 0.024 * s, cx + top_w - 0.014 * s, top_y + 0.024 * s],
              fill=col(MILK_TEA) if not mono else (0, 0, 0, 0))
    # Steam: three wavy lines, drawn as a smooth chain of dots.
    radius = 0.013 * s
    for i, off in enumerate((-0.085, 0.0, 0.085)):
        base_x = cx + off * s
        for k in range(0, 161):
            t = k / 160.0
            y = top_y - 0.05 * s - t * (0.135 + 0.02 * (i == 1)) * s
            x = base_x + math.sin(t * math.pi * 2 + i) * 0.018 * s
            d.ellipse([x - radius, y - radius, x + radius, y + radius], fill=col(WHITE))
    # Coin (top right of the cup).
    ccx, ccy, r = cx + 0.185 * s, 0.375 * s, 0.075 * s
    d.ellipse([ccx - r, ccy - r, ccx + r, ccy + r], fill=col(GOLD))
    if not mono:
        d.ellipse([ccx - r, ccy - r, ccx + r, ccy + r], outline=GOLD_DARK, width=int(0.012 * s))
        d.ellipse([ccx - r * 0.62, ccy - r * 0.62, ccx + r * 0.62, ccy + r * 0.62],
                  outline=GOLD_DARK, width=int(0.009 * s))
        d.rectangle([ccx - r * 0.07, ccy - r * 0.38, ccx + r * 0.07, ccy + r * 0.38], fill=GOLD_DARK)
    return img


def gradient_square(size, top, bottom):
    img = Image.new("RGBA", (size, size))
    px = img.load()
    for y in range(size):
        t = y / max(1, size - 1)
        c = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(4))
        for x in range(size):
            px[x, y] = c
    return img


def save(img, path, size=None):
    full = os.path.join(ROOT, path)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    out = img if size is None else img.resize((size, size), Image.LANCZOS)
    out.save(full, optimize=True)
    print("wrote", path, out.size)


def legacy_icon(fg, size, round_shape):
    """Old-style icon (Android 7): coloured shape with the cup enlarged inside it."""
    big = SUPER
    bg = gradient_square(big, SAFFRON_LIGHT, SAFFRON)
    crop = int(big / 1.42)
    off = (big - crop) // 2
    cup = fg.crop((off, off, off + crop, off + crop)).resize((big, big), Image.LANCZOS)
    bg.alpha_composite(cup)
    mask = Image.new("L", (big, big), 0)
    md = ImageDraw.Draw(mask)
    if round_shape:
        md.ellipse([0, 0, big - 1, big - 1], fill=255)
    else:
        md.rounded_rectangle([0, 0, big - 1, big - 1], radius=int(big * 0.2), fill=255)
    out = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    out.paste(bg, (0, 0), mask)
    return out.resize((size, size), Image.LANCZOS)


def main():
    fg = cup_picture()
    mono = cup_picture(mono=True)
    densities = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}
    for name, scale in densities.items():
        folder = f"android/app/src/main/res/mipmap-{name}"
        save(fg, f"{folder}/ic_launcher_foreground.png", int(round(108 * scale)))
        save(mono, f"{folder}/ic_launcher_monochrome.png", int(round(108 * scale)))
        px = int(round(48 * scale))
        for fname, rnd in (("ic_launcher.png", False), ("ic_launcher_round.png", True)):
            out = legacy_icon(fg, px, rnd)
            full = os.path.join(ROOT, folder, fname)
            out.save(full, optimize=True)
            print("wrote", f"{folder}/{fname}", out.size)

    # Start-up logo and in-game logo: the cup, cropped to its content.
    box = fg.getbbox()
    pad = 40
    cropped = fg.crop((box[0] - pad, box[1] - pad, box[2] + pad, box[3] + pad))
    side = max(cropped.size)
    square = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    square.alpha_composite(cropped, ((side - cropped.width) // 2, (side - cropped.height) // 2))
    save(square, "android/app/src/main/res/drawable-nodpi/launch_logo.png", 288)
    save(square, "assets/images/logo.png", 256)

    # Google Play: 512x512 icon (full square, Google rounds the corners itself).
    play = gradient_square(SUPER, SAFFRON_LIGHT, SAFFRON)
    crop = int(SUPER / 1.42)
    off = (SUPER - crop) // 2
    play.alpha_composite(fg.crop((off, off, off + crop, off + crop)).resize((SUPER, SUPER), Image.LANCZOS))
    play.convert("RGB").resize((512, 512), Image.LANCZOS).save(
        os.path.join(ROOT, "store/graphics/icon-512.png"), optimize=True)
    print("wrote store/graphics/icon-512.png")

    # Google Play: 1024x500 feature graphic.
    feature_graphic(square)


def feature_graphic(logo):
    w, h = 1024, 500
    img = Image.new("RGBA", (w, h))
    px = img.load()
    for y in range(h):
        for x in range(w):
            t = (x / w * 0.55 + y / h * 0.45)
            px[x, y] = tuple(int(SAFFRON_LIGHT[i] + (SAFFRON[i] - SAFFRON_LIGHT[i]) * t) for i in range(3)) + (255,)
    d = ImageDraw.Draw(img)
    # Soft circles for depth.
    for cxy, r, a in (((120, 420), 230, 40), ((980, 60), 200, 35)):
        layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        ImageDraw.Draw(layer).ellipse([cxy[0] - r, cxy[1] - r, cxy[0] + r, cxy[1] + r], fill=(255, 255, 255, a))
        img.alpha_composite(layer)
    cup = logo.resize((380, 380), Image.LANCZOS)
    img.alpha_composite(cup, (50, 60))
    font_path = "/usr/share/fonts/truetype/google-fonts/Poppins-Bold.ttf"
    try:
        title = ImageFont.truetype(font_path, 84)
        sub = ImageFont.truetype(font_path, 38)
    except OSError:
        title = sub = ImageFont.load_default()
    shadow = (110, 60, 10, 255)
    for text, font, y, fill in (("Chai Tapri", title, 120, WHITE), ("Tycoon", title, 215, WHITE),
                                ("Grow your chai stall!", sub, 335, CREAM)):
        d.text((472 + 3, y + 4), text, font=font, fill=shadow)
        d.text((472, y), text, font=font, fill=fill)
    img.convert("RGB").save(os.path.join(ROOT, "store/graphics/feature-graphic-1024x500.png"), optimize=True)
    print("wrote store/graphics/feature-graphic-1024x500.png")


if __name__ == "__main__":
    sys.exit(main())
