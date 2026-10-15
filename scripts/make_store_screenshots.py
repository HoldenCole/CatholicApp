#!/usr/bin/env python3
"""Store screenshots for Introibo — App Store and Google Play from one design.

The design (docs/marketing-screenshots.md is the spec; read it first):
  a public-domain painting, blurred and faded to a warm wash, behind a cream
  page; a small maroon badge with a gold cross; the headline in Playfair
  Display Bold, deep maroon, two or three short lines, an imperative that
  ends with a full stop; a short subhead in Inter; the phone upright in a
  dark frame with a real status bar, running off the bottom edge; and one
  zoomed callout card — a piece of the screen enlarged, on a white card
  with a gold hairline — laid over the phone's edge.
  The copy names no counts, so the set never goes stale as content grows.

Inputs : store-screenshots/raw/NN-<name>.png — one in-app capture each,
         portrait, the status bar cropped away (the generator draws one).
         store-screenshots/art/*.jpg, store-screenshots/fonts/*.
Output : store-screenshots/<version>/apple/NN-<size>.png
         store-screenshots/<version>/play/{phone,tablet-7in,tablet-10in}-NN.png
         store-screenshots/<version>/play/feature-graphic-1024x500.png

    python3 scripts/make_store_screenshots.py                 # everything
    python3 scripts/make_store_screenshots.py --only apple     # or play
    pip install Pillow                                         # one-time
"""
import argparse, math, os, sys
from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageEnhance

VERSION = "1.3.0"
ROOT = "store-screenshots"
RAW, ART, FONTS = f"{ROOT}/raw", f"{ROOT}/art", f"{ROOT}/fonts"
OUT_DIR = f"{ROOT}/{VERSION}"

# Palette
PAGE = (247, 241, 229)
MAROON = (104, 18, 26)
INK = (64, 50, 46)
GOLD = (196, 158, 92)
CARD = (253, 250, 244)
FRAME = (24, 21, 21)
FRAME_EDGE = (70, 62, 60)

APPLE = {"6.9": (1320, 2868), "6.5": (1284, 2778), "ipad13": (2048, 2732)}
PLAY = {"phone": (1080, 1920), "tablet-7in": (1200, 2134), "tablet-10in": (1620, 2880)}

TRUST = "AD-FREE  ·  OFFLINE  ·  NO ACCOUNT  ·  NO SUBSCRIPTION"

# ── The set ──────────────────────────────────────────────────────────────────
# raw capture · painting · headline · subhead · callout (x0, y0, x1, y1 as
# fractions of the capture; side; vertical position as a fraction of the
# visible phone) · trust line
SHOTS = [
    ("02-missal.png",    "raphael",  "Pray the Mass\nof the Ages.",
     "The complete 1962 Missal, every Proper woven into the Ordinary, Latin and English side by side.",
     (0.03, 0.335, 0.97, 0.49, "left", 0.42), True),
    ("01-today.png",     "angelico", "Live the\nLiturgical Year.",
     "Today's feast, the Mass propers, the day's penance, and your own rule of prayer, every morning.",
     (0.06, 0.53, 0.94, 0.705, "right", 0.50), False),
    ("06-office.png",    "gentile",  "Pray the\nDivine Office.",
     "Every hour of the Roman Breviary at its proper time, with the psalms, hymns, and lessons of the day.",
     (0.12, 0.475, 0.44, 0.585, "left", 0.47), False),
    ("03-prayers.png",   "raphael",  "Keep a Rule\nof Prayer.",
     "Morning, midday, and evening, built from the traditional prayers of the Church.",
     (0.04, 0.065, 0.96, 0.23, "right", 0.30), False),
    ("07-rosary.png",    "gentile",  "Pray the Rosary,\nBead by Bead.",
     "Every mystery and every prayer, in Latin and English, with your place always kept.",
     (0.04, 0.225, 0.96, 0.345, "right", 0.72), False),
    ("08-stations.png",  "raphael",  "Walk the Way\nof the Cross.",
     "Every station with Tiepolo's engravings, a meditation, and the Stabat Mater.",
     (0.04, 0.63, 0.96, 0.70, "right", 0.56), False),
    ("09-bilingual.png", "angelico", "Latin and English,\nSide by Side.",
     "The Church's own words with a faithful translation beside them, on every page.",
     (0.04, 0.39, 0.96, 0.47, "left", 0.46), False),
    ("04-latin.png",     "gentile",  "Learn the Latin\nof the Mass.",
     "Pronunciation, grammar, and the prayers you hear every Sunday, word by word.",
     (0.04, 0.265, 0.96, 0.425, "right", 0.36), False),
    ("05-library.png",   "raphael",  "Go Deeper.",
     "The history of the Mass, a glossary, articles, and every Proper, searchable.",
     (0.04, 0.095, 0.96, 0.255, "left", 0.30), False),
    ("10-settings.png",  "angelico", "Make It Yours.",
     "Your Missal, your discipline of penance, your language, your look.",
     (0.06, 0.865, 0.94, 0.925, "right", 0.60), True),
]
PAINTINGS = {"raphael": "raphael-disputation.jpg", "angelico": "fra-angelico-annunciation.jpg", "gentile": "gentile-coronation.jpg"}


# ── fonts ────────────────────────────────────────────────────────────────────
def serif(size, weight=700, italic=False):
    f = ImageFont.truetype(f"{FONTS}/PlayfairDisplay{'-Italic' if italic else ''}[wght].ttf", size)
    f.set_variation_by_axes([weight])
    return f


def sans(size, weight="Medium"):
    return ImageFont.truetype(f"{FONTS}/Inter-{weight}.otf", size)


# ── background ───────────────────────────────────────────────────────────────
def background(W, H, painting):
    art = Image.open(f"{ART}/{PAINTINGS[painting]}").convert("RGB")
    # cover-fit, biased to the upper part of the painting
    sc = max(W / art.size[0], H / art.size[1])
    art = art.resize((int(art.size[0] * sc) + 1, int(art.size[1] * sc) + 1), Image.LANCZOS)
    x = (art.size[0] - W) // 2
    y = min((art.size[1] - H) // 3, art.size[1] - H)
    art = art.crop((x, y, x + W, y + H))
    art = art.filter(ImageFilter.GaussianBlur(W * 0.038))
    art = ImageEnhance.Color(art).enhance(0.85)
    art = ImageEnhance.Brightness(art).enhance(1.10)
    bg = Image.new("RGBA", (W, H), PAGE + (255,))
    art = art.convert("RGBA"); art.putalpha(int(255 * 0.78))
    bg.alpha_composite(art)
    # a stronger cream wash over the text area, fading out towards the phone
    wash = Image.new("L", (1, H), 0)
    px = wash.load()
    for yy in range(H):
        t = yy / H
        a = 190 if t < 0.08 else max(0, int(190 * (1 - (t - 0.08) / 0.42))) if t < 0.50 else 0
        px[0, yy] = a
    wash = wash.resize((W, H))
    layer = Image.new("RGBA", (W, H), PAGE + (0,)); layer.putalpha(wash)
    bg.alpha_composite(layer)
    return bg


# ── text helpers ─────────────────────────────────────────────────────────────
def wrap(draw, text, font, maxw):
    out, cur = [], ""
    for wd in text.split():
        t = (cur + " " + wd).strip()
        if draw.textlength(t, font=font) <= maxw:
            cur = t
        else:
            if cur:
                out.append(cur)
            cur = wd
    if cur:
        out.append(cur)
    return out


def balanced(draw, text, font, maxw):
    """Wrap, then balance the lines so the last is not a short orphan."""
    lines = wrap(draw, text, font, maxw)
    if len(lines) >= 2:
        for target in range(int(maxw * 0.55), int(maxw), max(8, int(maxw * 0.03))):
            alt = wrap(draw, text, font, target)
            if len(alt) == len(lines):
                widths = [draw.textlength(l, font=font) for l in alt]
                if max(widths) - min(widths) < maxw * 0.30:
                    return alt
    return lines


def centered(draw, lines, font, cx, y, fill, leading):
    asc, desc = font.getmetrics()
    for ln in lines:
        w = draw.textlength(ln, font=font)
        draw.text((cx - w / 2, y), ln, font=font, fill=fill)
        y += int((asc + desc) * leading)
    return y


def tracked(draw, text, font, cx, y, fill, tracking):
    widths = [draw.textlength(ch, font=font) for ch in text]
    total = sum(widths) + tracking * (len(text) - 1)
    x = cx - total / 2
    for ch, w in zip(text, widths):
        draw.text((x, y), ch, font=font, fill=fill)
        x += w + tracking
    asc, desc = font.getmetrics()
    return y + asc + desc


def badge(canvas, cx, cy, r):
    d = ImageDraw.Draw(canvas)
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=MAROON)
    t = max(2, int(r * 0.16))
    d.rectangle([cx - t / 2, cy - r * 0.58, cx + t / 2, cy + r * 0.52], fill=GOLD)
    d.rectangle([cx - r * 0.40, cy - r * 0.22 - t / 2, cx + r * 0.40, cy - r * 0.22 + t / 2], fill=GOLD)


# ── the device ───────────────────────────────────────────────────────────────
def edge_color(img, rows, bottom=False):
    strip = img.crop((0, img.size[1] - rows, img.size[0], img.size[1])) if bottom else img.crop((0, 0, img.size[0], rows))
    return strip.resize((1, 1), Image.BOX).getpixel((0, 0))[:3]


def luminance(c):
    return 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]


def prepare(shot):
    """Trim the capture's anti-aliased edge, paint its rounded corners in the app's own
    colours, and add a status bar (9:41, signal, wifi, battery) in the header colour."""
    w, h = shot.size
    t = max(2, int(w * 0.006))
    shot = shot.crop((t, t, w - t, h - t)); w, h = shot.size
    rows = max(2, int(h * 0.01))
    top, bottom = edge_color(shot, rows), edge_color(shot, rows, bottom=True)
    rad = int(w * 0.07)
    corners = Image.new("L", (w, h), 255)
    ImageDraw.Draw(corners).rounded_rectangle([0, 0, w - 1, h - 1], radius=rad, fill=0)
    fill = Image.new("RGB", (w, h), bottom); ImageDraw.Draw(fill).rectangle([0, 0, w, h // 2], fill=top)
    shot = Image.composite(fill, shot, corners)
    band = int(w * 0.125)
    out = Image.new("RGB", (w, h + band), bottom)
    d = ImageDraw.Draw(out)
    d.rectangle([0, 0, w, band], fill=top)
    out.paste(shot, (0, band))
    ink = (250, 246, 238) if luminance(top) < 110 else (28, 24, 22)
    # 9:41 on the left, the icons on the right — iOS proportions
    f = sans(int(w * 0.046), "SemiBold")
    ty = int(band * 0.50) - f.getmetrics()[0] // 2 - int(w * 0.004)
    d.text((int(w * 0.095), ty), "9:41", font=f, fill=ink)
    cy = int(band * 0.50) - int(w * 0.004)
    # signal bars
    bx = int(w * 0.705); bw = max(2, int(w * 0.011)); gap = int(w * 0.006)
    for i, hh in enumerate([0.012, 0.018, 0.024, 0.030]):
        x = bx + i * (bw + gap); hb = int(w * hh)
        d.rounded_rectangle([x, cy + int(w * 0.015) - hb, x + bw, cy + int(w * 0.015)], radius=1, fill=ink)
    # wifi: three arcs
    wx = int(w * 0.795)
    for k, r in enumerate([0.030, 0.021, 0.012]):
        rr = int(w * r)
        d.arc([wx - rr, cy - rr + int(w * 0.012), wx + rr, cy + rr + int(w * 0.012)], 225, 315, fill=ink, width=max(2, int(w * 0.0065)))
    d.ellipse([wx - int(w * 0.004), cy + int(w * 0.008), wx + int(w * 0.004), cy + int(w * 0.016)], fill=ink)
    # battery
    bx = int(w * 0.845); bW, bH = int(w * 0.058), int(w * 0.028)
    d.rounded_rectangle([bx, cy - bH // 2, bx + bW, cy + bH // 2], radius=int(bH * 0.3), outline=ink, width=max(2, int(w * 0.004)))
    d.rounded_rectangle([bx + int(bH * 0.18), cy - bH // 2 + int(bH * 0.18), bx + bW - int(bH * 0.18), cy + bH // 2 - int(bH * 0.18)], radius=int(bH * 0.18), fill=ink)
    d.rectangle([bx + bW + 2, cy - int(bH * 0.18), bx + bW + 2 + max(2, int(w * 0.005)), cy + int(bH * 0.18)], fill=ink)
    return out, band


def device(shot, frame_w):
    """The prepared capture inside a dark phone frame with a Dynamic Island.
    Returns (frame image RGBA, screen image RGB at frame scale, bezel, band height at frame scale)."""
    bezel = int(frame_w * 0.026)
    screen_w = frame_w - 2 * bezel
    prepared, band = prepare(shot)
    sc = screen_w / prepared.size[0]
    screen = prepared.resize((screen_w, int(prepared.size[1] * sc)), Image.LANCZOS)
    frame_h = screen.size[1] + 2 * bezel
    img = Image.new("RGBA", (frame_w, frame_h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([0, 0, frame_w - 1, frame_h - 1], radius=int(frame_w * 0.135), fill=FRAME, outline=FRAME_EDGE, width=max(2, int(frame_w * 0.004)))
    mask = Image.new("L", screen.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, screen_w - 1, screen.size[1] - 1], radius=int(screen_w * 0.112), fill=255)
    scr = screen.convert("RGBA"); scr.putalpha(mask)
    img.alpha_composite(scr, (bezel, bezel))
    pw, ph = int(screen_w * 0.29), int(screen_w * 0.082)
    d.rounded_rectangle([(frame_w - pw) // 2, bezel + int(screen_w * 0.030), (frame_w + pw) // 2, bezel + int(screen_w * 0.030) + ph], radius=ph // 2, fill=(6, 6, 6))
    return img, screen, bezel, int(band * sc)


def shadow_of(img, blur, offset, alpha=0.55):
    sh = Image.new("RGBA", (img.size[0] + blur * 6, img.size[1] + blur * 6), (0, 0, 0, 0))
    dark = Image.new("RGBA", img.size, (40, 20, 16, 255))
    dark.putalpha(img.split()[3].point(lambda a: int(a * alpha)))
    sh.paste(dark, (blur * 3, blur * 3 + offset), dark)
    return sh.filter(ImageFilter.GaussianBlur(blur)), blur * 3


def callout(screen, band, crop, zoom, max_w, pad, radius, border):
    """A piece of the screen, enlarged, on a white card with a gold hairline."""
    sw, sh_ = screen.size
    body_h = sh_ - band
    x0, y0, x1, y1 = crop
    box = (int(x0 * sw), band + int(y0 * body_h), int(x1 * sw), band + int(y1 * body_h))
    piece = screen.crop(box)
    tw = min(int(piece.size[0] * zoom), max_w)
    piece = piece.resize((tw, int(piece.size[1] * tw / piece.size[0])), Image.LANCZOS)
    cw, ch = piece.size[0] + 2 * pad, piece.size[1] + 2 * pad
    card = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
    d = ImageDraw.Draw(card)
    d.rounded_rectangle([0, 0, cw - 1, ch - 1], radius=radius, fill=CARD, outline=GOLD, width=border)
    m = Image.new("L", piece.size, 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, piece.size[0] - 1, piece.size[1] - 1], radius=max(4, radius - pad), fill=255)
    p = piece.convert("RGBA"); p.putalpha(m)
    card.alpha_composite(p, (pad, pad))
    return card


# ── one screenshot ───────────────────────────────────────────────────────────
def render(shot_path, painting, title, sub, co, trust, size, tablet):
    W, H = size
    canvas = background(W, H, painting)
    d = ImageDraw.Draw(canvas)
    k = 0.70 if tablet else 1.0
    t_size = int(W * 0.108 * k)
    s_size = int(W * 0.037 * k)
    tfont, sfont = serif(t_size, 760), sans(s_size, "Medium")
    col = int(W * (0.62 if tablet else 0.88))

    y = int(H * 0.040)
    r = int(W * 0.026 * k)
    badge(canvas, W // 2, y + r, r)
    y += 2 * r + int(t_size * 0.40)
    tlines = title.split("\n") if "\n" in title else balanced(d, title, tfont, col)
    y = centered(d, tlines, tfont, W // 2, y, MAROON, 1.02)
    y += int(s_size * 0.35)
    y = centered(d, balanced(d, sub, sfont, int(col * 0.80)), sfont, W // 2, y, INK, 1.32)
    if trust:
        y += int(s_size * 0.55)
        y = tracked(d, TRUST, sans(int(s_size * 0.56), "SemiBold"), W // 2, y, GOLD, s_size * 0.10)

    fw = int(W * (0.60 if tablet else 0.84))
    shot = Image.open(shot_path).convert("RGB")
    top = int(y + H * 0.035)
    dev, screen, bezel, band = device(shot, fw)
    sh, pad = shadow_of(dev, int(W * 0.028), int(W * 0.02))
    dx = (W - dev.size[0]) // 2
    canvas.alpha_composite(sh, (dx - pad, top - pad))
    canvas.alpha_composite(dev, (dx, top))

    # the callout card over the phone's edge
    x0, y0, x1, y1, side, cy = co
    card = callout(screen, band, (x0, y0, x1, y1), 1.42 if not tablet else 1.30, int(W * (0.56 if tablet else 0.74)),
                   int(W * 0.012), int(W * 0.03), max(2, int(W * 0.0028)))
    visible = H - top
    cyy = int(top + visible * cy - card.size[1] / 2)
    margin = int(W * 0.035)
    cx = margin if side == "left" else W - margin - card.size[0]
    if tablet:
        cx = dx - int(W * 0.06) if side == "left" else dx + dev.size[0] + int(W * 0.06) - card.size[0]
    csh, cpad = shadow_of(card, int(W * 0.022), int(W * 0.012), 0.45)
    canvas.alpha_composite(csh, (cx - cpad, cyy - cpad))
    canvas.alpha_composite(card, (cx, cyy))
    return canvas.convert("RGB")


def feature_graphic(path):
    W, H = 1024, 500
    canvas = background(W, H, "raphael")
    icon = Image.open("prototype/icon-assets/introibo-appstore-1024.png").convert("RGBA").resize((300, 300), Image.LANCZOS)
    m = Image.new("L", icon.size, 0); ImageDraw.Draw(m).rounded_rectangle([0, 0, 299, 299], radius=66, fill=255); icon.putalpha(m)
    sh, pad = shadow_of(icon, 18, 10, 0.5)
    canvas.alpha_composite(sh, (90 - pad, 100 - pad)); canvas.alpha_composite(icon, (90, 100))
    d = ImageDraw.Draw(canvas)
    d.text((450, 120), "Introibo", font=serif(118, 760), fill=MAROON)
    f = sans(33, "Medium")
    d.text((456, 268), "A prayer companion for the", font=f, fill=INK)
    d.text((456, 310), "traditional Catholic life.", font=f, fill=INK)
    tracked(d, TRUST, sans(16, "SemiBold"), 456 + 262, 372, MAROON, 2)
    canvas.convert("RGB").save(path, "PNG")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", choices=["apple", "play"])
    ap.add_argument("--sizes", help="comma-separated size keys to render (default: all)")
    args = ap.parse_args()
    want = set(args.sizes.split(",")) if args.sizes else None
    n = 0
    if args.only in (None, "apple"):
        out = f"{OUT_DIR}/apple"; os.makedirs(out, exist_ok=True)
        for i, (raw, painting, title, sub, co, trust) in enumerate(SHOTS, 1):
            for key, size in APPLE.items():
                if want and key not in want: continue
                render(f"{RAW}/{raw}", painting, title, sub, co, trust, size, key == "ipad13").save(f"{out}/{i:02d}-{key}.png", "PNG"); n += 1
    if args.only in (None, "play"):
        out = f"{OUT_DIR}/play"; os.makedirs(out, exist_ok=True)
        for i, (raw, painting, title, sub, co, trust) in enumerate(SHOTS, 1):
            for key, size in PLAY.items():
                if want and key not in want: continue
                render(f"{RAW}/{raw}", painting, title, sub, co, trust, size, key != "phone").save(f"{out}/{key}-{i:02d}.png", "PNG"); n += 1
        if not want:
            feature_graphic(f"{out}/feature-graphic-1024x500.png"); n += 1
    print(f"Wrote {n} images under {OUT_DIR}/")


if __name__ == "__main__":
    sys.exit(main())
