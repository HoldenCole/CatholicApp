#!/usr/bin/env python3
"""Repaint stale caption text on the (genuine Android) Play screenshots.

The committed google-play-screenshots are real Android emulator captures
wrapped in the Introibo marketing style, but their caption text predates the
1.2.1 number corrections:

    *-02  subtitle  "501 daily Propers"        -> "574 daily Propers"
    *-03  title     "40 Traditional Prayers"   -> "67 Traditional Prayers"
    *-04  subtitle  "...91 flashcards..."        -> "...97 flashcards..."  (data=97)
    *-10  title     "Customise Your Experience" -> "Customize ..."         (US spelling)

We don't have the un-wrapped raw captures, so we repaint *in place*: only the
first line of each caption changes (line 2 is identical), so we detect the
line-1 ink band, erase it by extending the image's own vertical gradient, and
redraw the corrected line. Titles carry the existing drop shadow (offset ~4.6%
of cap height, colour ~(50,8,12)); subtitles (EB Garamond italic) have none.
Font size is fitted to line 2's measured ink width (apples-to-apples with
ImageFont.getbbox), so it matches the untouched line exactly across phone and
both tablet canvases.

Run from repo root:  python3 scripts/fix_play_captions.py [--phone] [--dry]
  --phone  only the three phone files, writing scratch_fixed_*.png
  --dry    write scratch previews instead of overwriting the originals
"""
import sys
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import make_marketing as mm

TITLE_COL = mm.TITLE_COL          # (247,242,232) ivory
DESC_COL  = mm.DESC_COL           # (231,214,180) cream
GOLD      = mm.GOLD               # (214,178,110)
SHADOW    = (50, 8, 12)           # measured title drop-shadow colour

# n -> (kind, corrected line 1, unchanged line 2)
EDITS = {
    2:  ("desc",  "574 daily Propers woven into", "the Ordinary in correct order"),
    3:  ("title", "67 Traditional",               "Prayers"),
    4:  ("desc",  "10 lessons, 97 flashcards,",   "and daily vocabulary"),
    10: ("title", "Customize",                     "Your Experience"),
}


def near(p, c, t):
    return abs(p[0] - c[0]) <= t and abs(p[1] - c[1]) <= t and abs(p[2] - c[2]) <= t


def divider_y(px, W, H):
    best = (0, 0)
    for y in range(int(H * 0.10), int(H * 0.45)):
        n = sum(1 for x in range(0, W, 2) if near(px[x, y], GOLD, 30))
        if n > best[0]:
            best = (n, y)
    return best[1]


def line_bands(px, W, color, tol, y0, y1, min_h=6, bridge=3):
    """Segment `color` ink rows in [y0,y1) into text lines (smoothed profile).

    Gaps up to `bridge` rows are joined (so accents / i-dots merge into their
    line); bands shorter than `min_h` rows are dropped as fragments.
    """
    n = y1 - y0
    cnt = [0] * n; xa = [W] * n; xb = [0] * n
    for i, y in enumerate(range(y0, y1)):
        for x in range(W):
            if near(px[x, y], color, tol):
                cnt[i] += 1
                if x < xa[i]: xa[i] = x
                if x > xb[i]: xb[i] = x
    sm = [sum(cnt[max(0, i - 2):i + 3]) / len(cnt[max(0, i - 2):i + 3]) for i in range(n)]
    peak = max(sm) if sm else 0
    if peak == 0:
        return []
    thr = max(2, peak * 0.12)
    ink = [s >= thr for s in sm]
    for i in range(1, n - 1):
        if not ink[i] and ink[i - 1]:
            j = i
            while j < n and not ink[j]:
                j += 1
            if j < n and (j - i) <= bridge:
                for k in range(i, j):
                    ink[k] = True
    bands, s = [], None
    for i in range(n):
        if ink[i] and s is None:
            s = i
        if (not ink[i] or i == n - 1) and s is not None:
            e = i if not ink[i] else i + 1
            if e - s >= min_h:
                bands.append((y0 + s, y0 + e - 1, min(xa[s:e]), max(xb[s:e])))
            s = None
    return bands


def fit_size(text, font_path, target_w):
    """Largest size whose rendered ink width for `text` is <= target_w."""
    lo, hi = 8, 500
    while lo < hi:
        mid = (lo + hi + 1) // 2
        bb = ImageFont.truetype(font_path, mid).getbbox(text)
        if (bb[2] - bb[0]) <= target_w:
            lo = mid
        else:
            hi = mid - 1
    return lo


def erase_box(img, W, top, bot):
    px = img.load()
    for y in range(max(0, top), min(img.size[1], bot + 1)):
        c = px[4, y]
        for x in range(W):
            px[x, y] = c


def draw_title_line(img, text, font, cx, ink_top):
    bb = font.getbbox(text)
    x = cx - (bb[2] - bb[0]) // 2 - bb[0]
    y = ink_top - bb[1]
    off = max(2, round(font.size * 0.046))
    sh = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(sh).text((x + off, y + off), text, font=font, fill=SHADOW + (255,))
    img.alpha_composite(sh.filter(ImageFilter.GaussianBlur(1)))
    ImageDraw.Draw(img).text((x, y), text, font=font, fill=TITLE_COL + (255,),
                             stroke_width=max(1, round(font.size * 0.012)),
                             stroke_fill=TITLE_COL + (255,))


def draw_desc_line(img, text, font, cx, ink_top):
    bb = font.getbbox(text)
    x = cx - (bb[2] - bb[0]) // 2 - bb[0]
    ImageDraw.Draw(img).text((x, ink_top - bb[1]), text, font=font, fill=DESC_COL + (255,))


def repaint(path, kind, line1, line2, out):
    img = Image.open(path).convert("RGBA")
    W, H = img.size
    px = img.load()
    cx = W // 2
    dy = divider_y(px, W, H)

    # The Android Play renders use make_marketing's size fractions (verified:
    # phone title 0.10*W = 108 matches exactly). Detection-derived sizing is
    # too noisy (anti-alias clipping), so use the fraction directly.
    frac = 0.100 if kind == "title" else 0.0335
    size = round(W * frac)
    min_h = round(size * 0.30); bridge = round(size * 0.14)

    if kind == "title":
        color, font_path = TITLE_COL, mm.TITLE_FONT
        top_bound = int(H * 0.05)
        bands = line_bands(px, W, color, 26, top_bound, dy - 6, min_h, bridge)
    else:
        color, font_path = DESC_COL, mm.DESC_FONT
        top_bound = dy + 4
        bands = line_bands(px, W, color, 13, top_bound, dy + int(H * 0.060), min_h, bridge)

    if len(bands) < 2:
        raise SystemExit(f"{path}: detected {len(bands)} {kind} line(s) (<2): {bands}")

    bt, bb_, x0, x1 = bands[0]
    l2 = bands[1]
    font = ImageFont.truetype(font_path, size)

    e_top = max(top_bound + 2, bt - round(size * 0.30))
    e_bot = min(l2[0] - 3, bb_ + round(size * 0.35))
    erase_box(img, W, e_top, e_bot)

    (draw_title_line if kind == "title" else draw_desc_line)(img, line1, font, cx, bt)

    img.convert("RGB").save(out, "PNG")
    print(f"{out}: {kind} size {size} rows {bt}-{bb_} erase {e_top}-{e_bot} div@{dy}")


if __name__ == "__main__":
    dry = "--dry" in sys.argv or "--phone" in sys.argv
    prefixes = ("phone",) if "--phone" in sys.argv else ("phone", "tablet-7in", "tablet-10in")
    for n, (kind, l1, l2) in EDITS.items():
        for pre in prefixes:
            p = f"google-play-screenshots/{pre}-{n:02d}.png"
            try:
                open(p, "rb").close()
            except FileNotFoundError:
                continue
            out = f"scratch_fixed_{pre}-{n:02d}.png" if dry else p
            repaint(p, kind, l1, l2, out)
