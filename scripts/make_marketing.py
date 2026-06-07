#!/usr/bin/env python3
"""Generate App Store marketing screenshots in the Introibo house style.

This reproduces the design of `marketing-screenshots/` (the originals).
Read docs/marketing-screenshots.md before changing anything here.

Usage:
    python3 scripts/make_marketing.py            # regenerate all into the output dir
    pip install Pillow                           # one-time dependency

Inputs : the raw in-app captures listed in SHOTS (place them in repo root).
Output : OUT_DIR / "NN-marketing-{6.5,6.9,ipad13}.png"
"""
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import os

# ── House style (do not drift from these without updating the doc) ──────────
FONT_DIR   = "android/app/src/main/res/font"
TITLE_FONT = f"{FONT_DIR}/playfair_display_italic.ttf"   # ITALIC — matches originals
DESC_FONT  = f"{FONT_DIR}/eb_garamond_italic.ttf"        # ITALIC

GOLD      = (214, 178, 110)   # cross, corner brackets, divider
TITLE_COL = (247, 242, 232)   # warm white
DESC_COL  = (231, 214, 180)   # cream
BG_TOP    = (181, 51, 49)     # vertical gradient: brighter red at top …
BG_BOTTOM = (109, 18, 25)     # … to deep maroon at the bottom

# Apple App Store required pixel sizes
SIZES = {"6.5": (1284, 2778), "6.9": (1320, 2868), "ipad13": (2048, 2732)}

# Per-canvas layout fractions (phone vs iPad)
TITLE_FRAC = {"phone": 0.100, "ipad": 0.078}   # title cap-height ÷ width
DESC_FRAC  = {"phone": 0.0335, "ipad": 0.026}
SHOT_WFRAC = {"phone": 0.665, "ipad": 0.40}    # device width ÷ canvas width
TILT_DEG   = 3                                  # uniform; sign alternates L/R


def _gradient(w, h):
    img = Image.new("RGB", (w, h)); px = img.load()
    for y in range(h):
        t = y / (h - 1)
        c = tuple(int(BG_TOP[i] + (BG_BOTTOM[i] - BG_TOP[i]) * t) for i in range(3))
        for x in range(w): px[x, y] = c
    return img

def _wrap(draw, text, font, maxw):
    out, cur = [], ""
    for wd in text.split():
        t = (cur + " " + wd).strip()
        if draw.textlength(t, font=font) <= maxw: cur = t
        else:
            if cur: out.append(cur)
            cur = wd
    if cur: out.append(cur)
    return out

def _centered(draw, lines, font, cx, y, fill, gap, stroke=0):
    for ln in lines:
        w = draw.textlength(ln, font=font); bb = font.getbbox(ln)
        draw.text((cx - w / 2, y), ln, font=font, fill=fill,
                  stroke_width=stroke, stroke_fill=fill)
        y += (bb[3] - bb[1]) + gap
    return y

def _divider(draw, cx, y, half, col):
    gap = int(half * 0.14)
    draw.line([(cx - half, y), (cx - gap, y)], fill=col, width=2)
    draw.line([(cx + gap, y), (cx + half, y)], fill=col, width=2)
    d = int(half * 0.05) + 3
    draw.polygon([(cx, y - d), (cx + d, y), (cx, y + d), (cx - d, y)], fill=col)

def _rounded(img, rad):
    m = Image.new("L", img.size, 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, *img.size], radius=rad, fill=255)
    out = img.convert("RGBA"); out.putalpha(m); return out

def _brackets(draw, w, h, inset, length, thick):
    for cx, cy, dx, dy in [(inset, inset, 1, 1), (w - inset, inset, -1, 1),
                           (inset, h - inset, 1, -1), (w - inset, h - inset, -1, -1)]:
        draw.line([(cx, cy), (cx + dx * length, cy)], fill=GOLD, width=thick)
        draw.line([(cx, cy), (cx, cy + dy * length)], fill=GOLD, width=thick)

def _cross(draw, cx, y, s, thick):
    draw.line([(cx, y), (cx, y + s)], fill=GOLD, width=thick)
    draw.line([(cx - s * 0.34, y + s * 0.32), (cx + s * 0.34, y + s * 0.32)], fill=GOLD, width=thick)

def generate(shot_path, title, desc, tilt, size_key, out):
    W, H = SIZES[size_key]; ipad = size_key == "ipad13"; key = "ipad" if ipad else "phone"
    canvas = _gradient(W, H).convert("RGBA"); d = ImageDraw.Draw(canvas)
    _brackets(d, W, H, int(W * 0.035), int(W * 0.05), max(2, int(W * 0.0024)))
    _cross(d, W // 2, int(H * 0.030), int(W * 0.026), max(2, int(W * 0.0026)))
    tsize = int(W * TITLE_FRAC[key]); dsize = int(W * DESC_FRAC[key])
    tfont = ImageFont.truetype(TITLE_FONT, tsize); dfont = ImageFont.truetype(DESC_FONT, dsize)
    y = int(H * 0.080)
    y = _centered(d, _wrap(d, title, tfont, int(W * 0.84)), tfont, W // 2, y,
                  TITLE_COL, int(tsize * 0.12), stroke=max(1, int(tsize * 0.012)))
    y += int(H * 0.016); _divider(d, W // 2, y, int(W * 0.10), GOLD); y += int(H * 0.016)
    y = _centered(d, _wrap(d, desc, dfont, int(W * 0.70)), dfont, W // 2, y, DESC_COL, int(dsize * 0.20))
    shot = Image.open(shot_path).convert("RGB"); rw, rh = shot.size
    tw = int(W * SHOT_WFRAC[key]); sc = tw / rw
    shot = _rounded(shot.resize((tw, int(rh * sc)), Image.LANCZOS), int(tw * 0.058))
    shadow = Image.new("RGBA", (shot.size[0] + 90, shot.size[1] + 90), (0, 0, 0, 0))
    sh = Image.new("RGBA", shot.size, (8, 4, 6, 255)); sh.putalpha(shot.split()[3])
    shadow.paste(sh, (45, 48), sh); shadow = shadow.filter(ImageFilter.GaussianBlur(30))
    shot_r = shot.rotate(tilt, expand=True, resample=Image.BICUBIC)
    shadow_r = shadow.rotate(tilt, expand=True, resample=Image.BICUBIC)
    top = int(y + H * 0.05); cx = W // 2
    canvas.alpha_composite(shadow_r, (cx - shadow_r.size[0] // 2, max(0, top - 45)))
    canvas.alpha_composite(shot_r, (cx - shot_r.size[0] // 2, top))
    canvas.convert("RGB").save(out, "PNG")


# ── This release's content. Map EACH raw capture to its feature by VIEWING it;
#    the App Store export order is NOT sequential. Verify every quoted number
#    against the data (see the doc) before regenerating. ──────────────────────
OUT_DIR = "1.2.1 screenshots"
SHOTS = [
    # n, raw capture,    title,                       description,                                                  tilt
    (1,  "IMG_8461.jpg", "Your Daily Companion",      "Liturgical calendar, propers, penance, and prayer rule",    -TILT_DEG),
    (2,  "IMG_8462.jpg", "The Complete 1962 Missal",  "574 daily Propers woven into the Ordinary in correct order", TILT_DEG),
    (3,  "IMG_8463.jpg", "67 Traditional Prayers",    "Personal prayer rule with morning, midday, and evening",     -TILT_DEG),
    (4,  "IMG_8464.jpg", "Learn Latin",               "10 lessons, 91 flashcards, and daily vocabulary",           TILT_DEG),
    (5,  "IMG_8465.jpg", "Reference Library",         "Articles, propers search, history, and glossary",           -TILT_DEG),
    (6,  "IMG_8466.jpg", "The Divine Office",         "All 8 canonical hours of the 1962 Roman Breviary",          TILT_DEG),
    (7,  "IMG_8468.jpg", "The Holy Rosary",           "Bead-by-bead with Joyful, Sorrowful, and Glorious mysteries", -TILT_DEG),
    (8,  "IMG_8467.jpg", "Stations of the Cross",     "14 stations with meditations and Stabat Mater",             TILT_DEG),
    (9,  "IMG_8470.jpg", "Regina Caeli",              "Every prayer in Latin and English side-by-side",            -TILT_DEG),
    (10, "IMG_8469.jpg", "Customize Your Experience", "Missal rite, penance discipline, language, and appearance", TILT_DEG),
]

if __name__ == "__main__":
    os.makedirs(OUT_DIR, exist_ok=True)
    n = 0
    for num, shot, title, desc, tilt in SHOTS:
        for size in SIZES:
            generate(shot, title, desc, tilt, size, f"{OUT_DIR}/{num:02d}-marketing-{size}.png")
            n += 1
    print(f"Wrote {n} images to {OUT_DIR}/")
