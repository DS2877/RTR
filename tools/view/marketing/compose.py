#!/usr/bin/env python3
"""Store art: puts the DIG OUT! logo and a caption on the rendered shots (tools/view render.mjs with
marketing/views.json + actors.json) and writes the files to upload in Creator Hub:
  icon.png (512x512) and thumb-*.jpg (1920x1080).

    python3 compose.py <dir with the renders> <output dir>
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

BLACK = "/usr/share/fonts/opentype/inter/Inter-Black.otf"
BOLD = "/usr/share/fonts/opentype/inter/Inter-ExtraBold.otf"
ORANGE = (255, 138, 30)
INK = (20, 18, 24)

# (name, caption[, "low"]): "low" puts the logo bottom-left so it keeps the building's signs clear
THUMBS = [
    ("hero", "PUNCH THROUGH THE WALL"),
    ("prison", "BREAK OUT OF THE STATE PEN", "low"),
    ("crystal", "10 ZONES. DIG DEEPER."),
    ("yardGym", "GET STRONG. LIFT A TOILET."),
    ("corridorNight", "DON'T GET CAUGHT"),
    ("prisonNight", "ESCAPE BEFORE ROLL CALL", "low"),
]


def logo(size: int) -> Image.Image:
    """The DIG OUT! wordmark on a transparent canvas, tilted a little."""
    font = ImageFont.truetype(BLACK, size)
    text = "DIG OUT!"
    pad = size // 2
    probe = ImageDraw.Draw(Image.new("RGBA", (1, 1)))
    l, t, r, b = probe.textbbox((0, 0), text, font=font, stroke_width=size // 9)
    w, h = r - l + pad * 2, b - t + pad * 2
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # drop shadow
    shadow = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).text(
        (pad - l + size // 18, pad - t + size // 12), text, font=font, fill=(0, 0, 0, 170),
        stroke_width=size // 9, stroke_fill=(0, 0, 0, 170),
    )
    img.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(size // 25)))
    d.text((pad - l, pad - t), text, font=font, fill=ORANGE, stroke_width=size // 9, stroke_fill=INK)
    # a light top highlight on the letters
    hi = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(hi).text((pad - l, pad - t - size // 30), text, font=font, fill=(255, 205, 120, 255))
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).rectangle([0, 0, w, pad - t + size * 0.45], fill=110)
    img.alpha_composite(Image.composite(hi, Image.new("RGBA", (w, h), (0, 0, 0, 0)), mask))
    return img.rotate(4, resample=Image.BICUBIC, expand=True)


def caption(img: Image.Image, text: str):
    d = ImageDraw.Draw(img, "RGBA")
    W, H = img.size
    font = ImageFont.truetype(BOLD, 64)
    l, t, r, b = d.textbbox((0, 0), text, font=font)
    tw = r - l
    band_h = 118
    d.rectangle([0, H - band_h, W, H], fill=(10, 10, 14, 175))
    d.rectangle([0, H - band_h, W, H - band_h + 5], fill=ORANGE + (255,))
    d.text(((W - tw) / 2 - l, H - band_h + (band_h - (b - t)) / 2 - t + 2), text, font=font, fill=(255, 255, 255))


def main():
    src, dst = sys.argv[1], sys.argv[2]
    os.makedirs(dst, exist_ok=True)
    mark = logo(190)
    for i, (name, text, *where) in enumerate(THUMBS, 1):
        path = os.path.join(src, name + ".png")
        if not os.path.exists(path):
            print("missing", path)
            continue
        img = Image.open(path).convert("RGBA").resize((1920, 1080))
        caption(img, text)
        at = (40, 1080 - 118 - mark.height + 30) if where == ["low"] else (40, 20)
        img.alpha_composite(mark, at)
        img.convert("RGB").save(os.path.join(dst, f"thumb-{i}-{name}.jpg"), quality=90)
        print("thumb", i, name)
    icon_src = os.path.join(src, "icon.png")
    if os.path.exists(icon_src):
        icon = Image.open(icon_src).convert("RGBA").resize((1024, 1024))
        # darken the bottom so the logo pops
        grad = Image.new("L", (1, 1024))
        for y in range(1024):
            grad.putpixel((0, y), max(0, int((y - 560) / 464 * 200)))
        shade = Image.new("RGBA", (1024, 1024), (8, 8, 12, 255))
        icon = Image.composite(shade, icon, grad.resize((1024, 1024)))
        m = logo(230)
        m.thumbnail((1000, 1000))
        icon.alpha_composite(m, ((1024 - m.width) // 2, 1024 - m.height - 10))
        icon.convert("RGB").resize((512, 512), Image.LANCZOS).save(os.path.join(dst, "icon.png"))
        print("icon")


main()
