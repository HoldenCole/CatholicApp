#!/usr/bin/env python3
"""Generate Android launcher icons from the canonical monstrance SVG.

The Android closed-test build shipped flat dark-red square launcher icons with
no monstrance. This regenerates the full launcher icon set from the vector
source of truth, prototype/icon-assets/introibo-square.svg (the same artwork
behind the iOS / Play Store icon), so nothing is rasterised twice:

  * Adaptive icons (API 26+, the minSdk): a solid red background layer plus a
    transparent monstrance foreground scaled into the adaptive "safe zone" so
    launcher masks (circle / squircle / rounded-square) and parallax never clip
    the monstrance.
  * Legacy PNG fallbacks (ic_launcher / ic_launcher_round).

The SVG is a flat list of rect / circle / line primitives in a 0..100 viewBox,
which we render with Pillow (supersampled, per-primitive alpha compositing).

Run from the repo root:  python3 scripts/make_android_icons.py
"""
import os
import re
from PIL import Image, ImageDraw

SVG = "prototype/icon-assets/introibo-square.svg"
RES = "android/app/src/main/res"
BG_HEX = "#8B1A1A"  # background rect fill, also the adaptive background color

# density -> (legacy launcher px @48dp baseline, adaptive foreground px @108dp)
DENSITIES = {
    "mdpi":    (48, 108),
    "hdpi":    (72, 162),
    "xhdpi":   (96, 216),
    "xxhdpi":  (144, 324),
    "xxxhdpi": (192, 432),
}

# Fraction of the 108dp adaptive canvas the 100-unit artwork is scaled to.
# 0.72 keeps the whole monstrance (incl. cross finial and base) inside the
# 66dp safe zone with comfortable, iOS-matching margins.
FG_SCALE = 0.72

SS = 4          # supersampling factor for anti-aliasing
MASTER = 1024   # master render size (downscaled per density)


def parse_color(s):
    """'#RRGGBB' | 'rgba(r,g,b,a)' | 'none'  ->  (r,g,b,a) or None."""
    if s is None or s == "none":
        return None
    s = s.strip()
    if s.startswith("#"):
        return (int(s[1:3], 16), int(s[3:5], 16), int(s[5:7], 16), 255)
    m = re.match(r"rgba\(([\d.]+),\s*([\d.]+),\s*([\d.]+),\s*([\d.]+)\)", s)
    if m:
        r, g, b, a = m.groups()
        return (int(float(r)), int(float(g)), int(float(b)), int(round(float(a) * 255)))
    raise ValueError(f"unparseable color: {s}")


def attrs(tag):
    return dict(re.findall(r'(\w[\w-]*)="([^"]*)"', tag))


def primitives(skip_background):
    """Yield drawing primitives from the SVG, in document order.

    skip_background drops the opening full-bleed <rect ...100x100...> so the
    foreground layer stays transparent.
    """
    svg = open(SVG).read()
    for tag in re.findall(r"<(?:rect|circle|line)\b[^>]*>", svg):
        kind = re.match(r"<(\w+)", tag).group(1)
        a = attrs(tag)
        if kind == "rect" and skip_background and a.get("width") == "100" and a.get("height") == "100":
            continue
        yield kind, a


def render_master(scale_frac, draw_background):
    """Render the artwork into a MASTER*SS transparent RGBA image.

    The 0..100 viewBox is scaled to `scale_frac` of the canvas and centred.
    """
    W = MASTER * SS
    ppu = scale_frac * W / 100.0
    off = (W - scale_frac * W) / 2.0

    def U(v):       # viewBox unit -> device px
        return off + float(v) * ppu

    def L(v):       # length (no offset)
        return float(v) * ppu

    base = Image.new("RGBA", (W, W), (0, 0, 0, 0))

    for kind, a in primitives(skip_background=not draw_background):
        layer = Image.new("RGBA", (W, W), (0, 0, 0, 0))
        d = ImageDraw.Draw(layer)
        fill = parse_color(a.get("fill"))
        stroke = parse_color(a.get("stroke"))
        sw = max(1, round(L(a.get("stroke-width", "0"))))

        if kind == "rect":
            x, y = U(a["x"]) if "x" in a else off, U(a["y"]) if "y" in a else off
            w, h = L(a["width"]), L(a["height"])
            r = L(a.get("rx", "0"))
            box = [x, y, x + w, y + h]
            if r > 0.5:
                d.rounded_rectangle(box, radius=r, fill=fill)
            else:
                d.rectangle(box, fill=fill)
        elif kind == "circle":
            cx, cy, rad = U(a["cx"]), U(a["cy"]), L(a["r"])
            box = [cx - rad, cy - rad, cx + rad, cy + rad]
            if fill is not None:           # filled disc
                d.ellipse(box, fill=fill)
            if stroke is not None:         # ring
                d.ellipse(box, outline=stroke, width=sw)
        elif kind == "line":
            d.line([U(a["x1"]), U(a["y1"]), U(a["x2"]), U(a["y2"])],
                   fill=stroke, width=sw)

        base = Image.alpha_composite(base, layer)

    return base.resize((MASTER, MASTER), Image.LANCZOS)


def circle_mask(size):
    m = Image.new("L", (size, size), 0)
    ImageDraw.Draw(m).ellipse((0, 0, size - 1, size - 1), fill=255)
    return m


def main():
    fg_master = render_master(FG_SCALE, draw_background=False)   # transparent monstrance
    sq_master = render_master(1.0, draw_background=True)         # full-bleed icon

    for density, (legacy_px, fg_px) in DENSITIES.items():
        d = os.path.join(RES, f"mipmap-{density}")
        os.makedirs(d, exist_ok=True)

        sq = sq_master.resize((legacy_px, legacy_px), Image.LANCZOS)
        sq.convert("RGB").save(os.path.join(d, "ic_launcher.png"))

        rnd = Image.new("RGBA", (legacy_px, legacy_px), (0, 0, 0, 0))
        rnd.paste(sq, (0, 0), circle_mask(legacy_px))
        rnd.save(os.path.join(d, "ic_launcher_round.png"))

        fg = fg_master.resize((fg_px, fg_px), Image.LANCZOS)
        fg.save(os.path.join(d, "ic_launcher_foreground.png"))

        print(f"{density:8s} legacy={legacy_px}px foreground={fg_px}px")

    print("done")


if __name__ == "__main__":
    main()
