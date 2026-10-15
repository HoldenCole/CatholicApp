#!/usr/bin/env python3
"""Store screenshots for Introibo — App Store and Google Play from one table.

Four designs share the same bones (a real phone, a big headline, a painting
blurred into the background, no counts in the copy) and differ in layout
and ornament; `--style` picks one (see docs/marketing-screenshots.md):

  wash       cream wash over the painting, centred headline, one zoomed
             callout card over the phone's edge
  vellum     a missal page: double-rule border, running head, a drop cap on
             the headline, the painting showing past the page's edges
  nocturne   the painting deep and dark, cream headline, gold rules, the
             phone turned a few degrees, a faint Latin word behind the text
  asymmetric headline set left with an italic maroon second line, the phone
             pushed to one side and off two edges, alternating sides, a
             roman numeral index and a gold hairline

Inputs : store-screenshots/raw/NN-<name>.png (portrait captures without a
         status bar), store-screenshots/art/*.jpg, store-screenshots/fonts/*.
Output : store-screenshots/<version>[-<style>]/apple/NN-<size>.png,
         .../play/<key>-NN.png, .../play/feature-graphic-1024x500.png

    python3 scripts/make_store_screenshots.py --style vellum
    python3 scripts/make_store_screenshots.py --style nocturne --only apple --sizes 6.9 --shots 1,2,3
"""
import argparse, os, sys
from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageEnhance

VERSION = "1.3.0"
ROOT = "store-screenshots"
RAW, ART, FONTS = f"{ROOT}/raw", f"{ROOT}/art", f"{ROOT}/fonts"

PAGE = (247, 241, 229)
MAROON = (104, 18, 26)
INK = (64, 50, 46)
GOLD = (196, 158, 92)
CREAM = (250, 245, 234)
CARD = (253, 250, 244)
FRAME = (24, 21, 21)
FRAME_EDGE = (70, 62, 60)
NIGHT = (34, 10, 14)

APPLE = {"6.9": (1320, 2868), "6.5": (1284, 2778), "ipad13": (2048, 2732)}
PLAY = {"phone": (1080, 1920), "tablet-7in": (1200, 2134), "tablet-10in": (1620, 2880)}
TRUST = "AD-FREE  ·  OFFLINE  ·  NO ACCOUNT  ·  NO SUBSCRIPTION"
ROMAN = ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI", "XII"]

# raw · painting · latin word · headline (explicit break) · subhead · callout crop (fractions of
# the capture), side, height on the visible phone · trust line
SHOTS = [
    ("02-missal.png",    "raphael",  "MISSA",     "Pray the Mass\nof the Ages.",
     "The complete 1962 Missal, every Proper woven into the Ordinary, Latin and English side by side.",
     (0.03, 0.335, 0.97, 0.49, "left", 0.42), True),
    ("01-today.png",     "angelico", "HODIE",     "Live the\nLiturgical Year.",
     "Today's feast, the Mass propers, the day's penance, and your own rule of prayer, every morning.",
     (0.06, 0.53, 0.94, 0.705, "right", 0.50), False),
    ("06-office.png",    "gentile",  "OFFICIUM",  "Pray the\nDivine Office.",
     "Every hour of the Roman Breviary at its proper time, with the psalms, hymns, and lessons of the day.",
     (0.12, 0.475, 0.44, 0.585, "left", 0.47), False),
    ("03-prayers.png",   "raphael",  "ORATIO",    "Keep a Rule\nof Prayer.",
     "Morning, midday, and evening, built from the traditional prayers of the Church.",
     (0.04, 0.065, 0.96, 0.23, "right", 0.30), False),
    ("07-rosary.png",    "gentile",  "ROSARIUM",  "Pray the Rosary,\nBead by Bead.",
     "Every mystery and every prayer, in Latin and English, with your place always kept.",
     (0.04, 0.225, 0.96, 0.345, "right", 0.72), False),
    ("08-stations.png",  "raphael",  "VIA CRUCIS", "Walk the Way\nof the Cross.",
     "Every station with Tiepolo's engravings, a meditation, and the Stabat Mater.",
     (0.04, 0.63, 0.96, 0.70, "right", 0.56), False),
    ("09-bilingual.png", "angelico", "LATINE",    "Latin and English,\nSide by Side.",
     "The Church's own words with a faithful translation beside them, on every page.",
     (0.04, 0.39, 0.96, 0.47, "left", 0.46), False),
    ("04-latin.png",     "gentile",  "SCHOLA",    "Learn the Latin\nof the Mass.",
     "Pronunciation, grammar, and the prayers you hear every Sunday, word by word.",
     (0.04, 0.265, 0.96, 0.425, "right", 0.36), False),
    ("05-library.png",   "raphael",  "LIBER",     "Go Deeper.",
     "The history of the Mass, a glossary, articles, and every Proper, searchable.",
     (0.04, 0.095, 0.96, 0.255, "left", 0.30), False),
    ("10-settings.png",  "angelico", "RITUS",     "Make It Yours.",
     "Your Missal, your discipline of penance, your language, your look.",
     (0.06, 0.865, 0.94, 0.925, "right", 0.60), True),
]
PAINTINGS = {"raphael": "raphael-disputation.jpg", "angelico": "fra-angelico-annunciation.jpg", "gentile": "gentile-coronation.jpg"}


# ── fonts & text ─────────────────────────────────────────────────────────────
def serif(size, weight=700, italic=False):
    f = ImageFont.truetype(f"{FONTS}/PlayfairDisplay{'-Italic' if italic else ''}[wght].ttf", max(8, int(size)))
    f.set_variation_by_axes([weight])
    return f


def sans(size, weight="Medium"):
    return ImageFont.truetype(f"{FONTS}/Inter-{weight}.otf", max(8, int(size)))


def garamond(size, italic=False):
    return ImageFont.truetype(f"android/app/src/main/res/font/eb_garamond_{'italic' if italic else 'regular'}.ttf", max(8, int(size)))


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
    lines = wrap(draw, text, font, maxw)
    if len(lines) >= 2:
        for target in range(int(maxw * 0.55), int(maxw), max(8, int(maxw * 0.03))):
            alt = wrap(draw, text, font, target)
            if len(alt) == len(lines):
                widths = [draw.textlength(l, font=font) for l in alt]
                if max(widths) - min(widths) < maxw * 0.30:
                    return alt
    return lines


def text_block(draw, lines, font, x, y, fill, leading, align="center", cx=None):
    asc, desc = font.getmetrics()
    for ln in lines:
        w = draw.textlength(ln, font=font)
        xx = (cx - w / 2) if align == "center" else x
        draw.text((xx, y), ln, font=font, fill=fill)
        y += int((asc + desc) * leading)
    return y


def tracked(draw, text, font, x, y, fill, tracking, align="center"):
    widths = [draw.textlength(ch, font=font) for ch in text]
    total = sum(widths) + tracking * (len(text) - 1)
    xx = x - total / 2 if align == "center" else x
    for ch, w in zip(text, widths):
        draw.text((xx, y), ch, font=font, fill=fill)
        xx += w + tracking
    asc, desc = font.getmetrics()
    return y + asc + desc


# ── painting backgrounds ─────────────────────────────────────────────────────
def painting(W, H, key, blur=0.038, color=0.85, bright=1.10, bias=3):
    art = Image.open(f"{ART}/{PAINTINGS[key]}").convert("RGB")
    sc = max(W / art.size[0], H / art.size[1])
    art = art.resize((int(art.size[0] * sc) + 1, int(art.size[1] * sc) + 1), Image.LANCZOS)
    x = (art.size[0] - W) // 2
    y = min((art.size[1] - H) // bias, art.size[1] - H)
    art = art.crop((x, y, x + W, y + H)).filter(ImageFilter.GaussianBlur(W * blur))
    art = ImageEnhance.Color(art).enhance(color)
    return ImageEnhance.Brightness(art).enhance(bright)


def vgradient(W, H, stops):
    """stops: list of (t, alpha) → an L mask interpolated down the canvas."""
    m = Image.new("L", (1, H)); px = m.load()
    for yy in range(H):
        t = yy / H
        a = stops[-1][1]
        for (t0, a0), (t1, a1) in zip(stops, stops[1:]):
            if t0 <= t <= t1:
                a = a0 + (a1 - a0) * (t - t0) / max(1e-6, t1 - t0); break
        if t < stops[0][0]: a = stops[0][1]
        px[0, yy] = int(a)
    return m.resize((W, H))


def bg_wash(W, H, key):
    bg = Image.new("RGBA", (W, H), PAGE + (255,))
    art = painting(W, H, key).convert("RGBA"); art.putalpha(int(255 * 0.78)); bg.alpha_composite(art)
    layer = Image.new("RGBA", (W, H), PAGE + (0,)); layer.putalpha(vgradient(W, H, [(0, 190), (0.08, 190), (0.50, 0)]))
    bg.alpha_composite(layer)
    return bg


# ── the device ───────────────────────────────────────────────────────────────
def edge_color(img, rows, bottom=False):
    strip = img.crop((0, img.size[1] - rows, img.size[0], img.size[1])) if bottom else img.crop((0, 0, img.size[0], rows))
    return strip.resize((1, 1), Image.BOX).getpixel((0, 0))[:3]


def prepare(shot):
    """Trim the capture's edge, paint its rounded corners in the app's colours, add a status bar."""
    w, h = shot.size
    t = max(2, int(w * 0.006))
    shot = shot.crop((t, t, w - t, h - t)); w, h = shot.size
    rows = max(2, int(h * 0.01))
    top, bottom = edge_color(shot, rows), edge_color(shot, rows, bottom=True)
    corners = Image.new("L", (w, h), 255)
    ImageDraw.Draw(corners).rounded_rectangle([0, 0, w - 1, h - 1], radius=int(w * 0.07), fill=0)
    fill = Image.new("RGB", (w, h), bottom); ImageDraw.Draw(fill).rectangle([0, 0, w, h // 2], fill=top)
    shot = Image.composite(fill, shot, corners)
    band = int(w * 0.125)
    out = Image.new("RGB", (w, h + band), bottom)
    d = ImageDraw.Draw(out); d.rectangle([0, 0, w, band], fill=top); out.paste(shot, (0, band))
    lum = 0.299 * top[0] + 0.587 * top[1] + 0.114 * top[2]
    ink = (250, 246, 238) if lum < 110 else (28, 24, 22)
    f = sans(w * 0.046, "SemiBold")
    d.text((int(w * 0.095), int(band * 0.50) - f.getmetrics()[0] // 2 - int(w * 0.004)), "9:41", font=f, fill=ink)
    cy = int(band * 0.50) - int(w * 0.004)
    bx = int(w * 0.705); bw = max(2, int(w * 0.011)); gap = int(w * 0.006)
    for i, hh in enumerate([0.012, 0.018, 0.024, 0.030]):
        x = bx + i * (bw + gap); hb = int(w * hh)
        d.rounded_rectangle([x, cy + int(w * 0.015) - hb, x + bw, cy + int(w * 0.015)], radius=1, fill=ink)
    wx = int(w * 0.795)
    for r in [0.030, 0.021, 0.012]:
        rr = int(w * r)
        d.arc([wx - rr, cy - rr + int(w * 0.012), wx + rr, cy + rr + int(w * 0.012)], 225, 315, fill=ink, width=max(2, int(w * 0.0065)))
    d.ellipse([wx - int(w * 0.004), cy + int(w * 0.008), wx + int(w * 0.004), cy + int(w * 0.016)], fill=ink)
    bx = int(w * 0.845); bW, bH = int(w * 0.058), int(w * 0.028)
    d.rounded_rectangle([bx, cy - bH // 2, bx + bW, cy + bH // 2], radius=int(bH * 0.3), outline=ink, width=max(2, int(w * 0.004)))
    d.rounded_rectangle([bx + int(bH * 0.18), cy - bH // 2 + int(bH * 0.18), bx + bW - int(bH * 0.18), cy + bH // 2 - int(bH * 0.18)], radius=int(bH * 0.18), fill=ink)
    d.rectangle([bx + bW + 2, cy - int(bH * 0.18), bx + bW + 2 + max(2, int(w * 0.005)), cy + int(bH * 0.18)], fill=ink)
    return out, band


def device(shot, frame_w):
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
    return img, screen, int(band * sc)


def shadow_of(img, blur, offset, alpha=0.55):
    sh = Image.new("RGBA", (img.size[0] + blur * 6, img.size[1] + blur * 6), (0, 0, 0, 0))
    dark = Image.new("RGBA", img.size, (40, 20, 16, 255))
    dark.putalpha(img.split()[3].point(lambda a: int(a * alpha)))
    sh.paste(dark, (blur * 3, blur * 3 + offset), dark)
    return sh.filter(ImageFilter.GaussianBlur(blur)), blur * 3


def place(canvas, img, x, y, blur, offset, alpha=0.55):
    sh, pad = shadow_of(img, blur, offset, alpha)
    canvas.alpha_composite(sh, (x - pad, y - pad))
    canvas.alpha_composite(img, (x, y))


def callout(screen, band, crop, zoom, max_w, pad, radius, border, outline=GOLD, fill=CARD):
    sw, sh_ = screen.size
    body_h = sh_ - band
    x0, y0, x1, y1 = crop
    piece = screen.crop((int(x0 * sw), band + int(y0 * body_h), int(x1 * sw), band + int(y1 * body_h)))
    tw = min(int(piece.size[0] * zoom), max_w)
    piece = piece.resize((tw, int(piece.size[1] * tw / piece.size[0])), Image.LANCZOS)
    cw, ch = piece.size[0] + 2 * pad, piece.size[1] + 2 * pad
    card = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
    ImageDraw.Draw(card).rounded_rectangle([0, 0, cw - 1, ch - 1], radius=radius, fill=fill, outline=outline, width=border)
    m = Image.new("L", piece.size, 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, piece.size[0] - 1, piece.size[1] - 1], radius=max(4, radius - pad), fill=255)
    p = piece.convert("RGBA"); p.putalpha(m)
    card.alpha_composite(p, (pad, pad))
    return card


def badge(canvas, cx, cy, r, disc=MAROON, cross=GOLD):
    d = ImageDraw.Draw(canvas)
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=disc)
    t = max(2, int(r * 0.16))
    d.rectangle([cx - t / 2, cy - r * 0.58, cx + t / 2, cy + r * 0.52], fill=cross)
    d.rectangle([cx - r * 0.40, cy - r * 0.22 - t / 2, cx + r * 0.40, cy - r * 0.22 + t / 2], fill=cross)


def diamond_rule(d, cx, y, half, col, w=2):
    gap = int(half * 0.12)
    d.line([(cx - half, y), (cx - gap, y)], fill=col, width=w)
    d.line([(cx + gap, y), (cx + half, y)], fill=col, width=w)
    s = int(half * 0.045) + 3
    d.polygon([(cx, y - s), (cx + s, y), (cx, y + s), (cx - s, y)], fill=col)


# ── STYLE: wash ──────────────────────────────────────────────────────────────
def render_wash(i, shot, art, latin, title, sub, co, trust, size, tablet):
    W, H = size
    canvas = bg_wash(W, H, art); d = ImageDraw.Draw(canvas)
    k = 0.70 if tablet else 1.0
    tfont, sfont = serif(W * 0.108 * k, 760), sans(W * 0.037 * k)
    col = int(W * (0.62 if tablet else 0.88))
    y = int(H * 0.040); r = int(W * 0.026 * k)
    badge(canvas, W // 2, y + r, r); y += 2 * r + int(tfont.size * 0.40)
    y = text_block(d, title.split("\n"), tfont, 0, y, MAROON, 1.02, cx=W // 2)
    y += int(sfont.size * 0.35)
    y = text_block(d, balanced(d, sub, sfont, int(col * 0.80)), sfont, 0, y, INK, 1.32, cx=W // 2)
    if trust:
        y += int(sfont.size * 0.55); y = tracked(d, TRUST, sans(sfont.size * 0.56, "SemiBold"), W // 2, y, GOLD, sfont.size * 0.10)
    fw = int(W * (0.60 if tablet else 0.84)); top = int(y + H * 0.035)
    dev, screen, band = device(shot, fw); dx = (W - dev.size[0]) // 2
    place(canvas, dev, dx, top, int(W * 0.028), int(W * 0.02))
    x0, y0, x1, y1, side, cy = co
    card = callout(screen, band, (x0, y0, x1, y1), 1.30 if tablet else 1.42, int(W * (0.56 if tablet else 0.74)), int(W * 0.012), int(W * 0.03), max(2, int(W * 0.0028)))
    cyy = int(top + (H - top) * cy - card.size[1] / 2); margin = int(W * 0.035)
    cx = margin if side == "left" else W - margin - card.size[0]
    if tablet: cx = dx - int(W * 0.06) if side == "left" else dx + dev.size[0] + int(W * 0.06) - card.size[0]
    place(canvas, card, cx, cyy, int(W * 0.022), int(W * 0.012), 0.45)
    return canvas.convert("RGB")


# ── STYLE: vellum (a missal page) ────────────────────────────────────────────
def render_vellum(i, shot, art, latin, title, sub, co, trust, size, tablet):
    W, H = size
    canvas = painting(W, H, art, blur=0.03, color=0.95, bright=1.0).convert("RGBA")
    k = 0.70 if tablet else 1.0
    m = int(W * 0.055)                       # the page sits inside the painting
    page = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    pd = ImageDraw.Draw(page)
    pd.rounded_rectangle([m, m, W - m, H + m], radius=int(W * 0.02), fill=PAGE + (248,))
    canvas.alpha_composite(page)
    d = ImageDraw.Draw(canvas)
    # double rule border, the outer heavier
    b1, b2 = m + int(W * 0.022), m + int(W * 0.034)
    d.rectangle([b1, b1, W - b1, H + 40], outline=MAROON, width=max(2, int(W * 0.0025)))
    d.rectangle([b2, b2, W - b2, H + 40], outline=GOLD, width=max(1, int(W * 0.0012)))
    # running head: small caps, maroon, a cross in the middle
    rh = garamond(W * 0.024 * k)
    yy = b2 + int(W * 0.02)
    tracked(d, "INTROIBO", rh, b2 + int(W * 0.035), yy, MAROON, W * 0.004, align="left")
    tracked(d, latin, rh, W - b2 - int(W * 0.035) - d.textlength(latin, font=rh) - len(latin) * W * 0.004, yy, MAROON, W * 0.004, align="left")
    tracked(d, ROMAN[i - 1], rh, W // 2, yy, GOLD, W * 0.004)
    # headline with a drop cap in maroon italic, body of the headline in ink
    tfont = serif(W * 0.100 * k, 700); dfont = serif(W * 0.19 * k, 700, italic=True)
    lines = title.split("\n")
    y = yy + int(W * 0.075)
    first, rest = lines[0][0], lines[0][1:]
    cap_w = d.textlength(first, font=dfont)
    # block width to centre: drop cap + first line
    col = int(W * 0.80)
    widths = [cap_w + d.textlength(rest, font=tfont)] + [d.textlength(l, font=tfont) for l in lines[1:]]
    x0 = W // 2 - widths[0] / 2
    asc_t = tfont.getmetrics()[0]; asc_d = dfont.getmetrics()[0]
    d.text((x0, y + asc_t - asc_d + int(W * 0.005)), first, font=dfont, fill=MAROON)
    d.text((x0 + cap_w, y), rest, font=tfont, fill=INK)
    y += int((tfont.getmetrics()[0] + tfont.getmetrics()[1]) * 1.0)
    for l in lines[1:]:
        w = d.textlength(l, font=tfont)
        d.text((W // 2 - w / 2, y), l, font=tfont, fill=INK)
        y += int((tfont.getmetrics()[0] + tfont.getmetrics()[1]) * 1.0)
    y += int(W * 0.015)
    diamond_rule(d, W // 2, y, int(W * 0.12), GOLD, max(2, int(W * 0.002))); y += int(W * 0.03)
    sfont = garamond(W * 0.040 * k, italic=True)
    y = text_block(d, balanced(d, sub, sfont, int(W * 0.72)), sfont, 0, y, INK, 1.25, cx=W // 2)
    if trust:
        y += int(sfont.size * 0.45); y = tracked(d, TRUST, garamond(W * 0.021 * k), W // 2, y, MAROON, W * 0.003)
    fw = int(W * (0.58 if tablet else 0.78)); top = int(y + H * 0.035)
    dev, screen, band = device(shot, fw); dx = (W - dev.size[0]) // 2
    place(canvas, dev, dx, top, int(W * 0.026), int(W * 0.018))
    return canvas.convert("RGB")


# ── STYLE: nocturne ──────────────────────────────────────────────────────────
def render_nocturne(i, shot, art, latin, title, sub, co, trust, size, tablet):
    W, H = size
    k = 0.70 if tablet else 1.0
    base = painting(W, H, art, blur=0.032, color=1.05, bright=0.55).convert("RGBA")
    night = Image.new("RGBA", (W, H), NIGHT + (0,)); night.putalpha(vgradient(W, H, [(0, 150), (0.35, 110), (1.0, 235)]))
    base.alpha_composite(night)
    # a warm glow behind the phone
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse([W * 0.05, H * 0.38, W * 0.95, H * 0.95], fill=(150, 48, 44, 110))
    base.alpha_composite(glow.filter(ImageFilter.GaussianBlur(W * 0.18)))
    canvas = base; d = ImageDraw.Draw(canvas)
    # the faint Latin word behind the headline
    wf = serif(W * 0.24 * k, 800, italic=True)
    wm = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(wm).text((W // 2 - d.textlength(latin, font=wf) / 2, int(H * 0.035)), latin, font=wf, fill=GOLD + (22,))
    canvas.alpha_composite(wm)
    y = int(H * 0.055)
    diamond_rule(d, W // 2, y, int(W * 0.09), GOLD, max(2, int(W * 0.002)))
    y += int(W * 0.035)
    y = tracked(d, latin, garamond(W * 0.026 * k), W // 2, y, GOLD, W * 0.006)
    y += int(W * 0.02)
    tfont = serif(W * 0.112 * k, 500, italic=True)
    y = text_block(d, title.split("\n"), tfont, 0, y, CREAM, 1.0, cx=W // 2)
    y += int(W * 0.02)
    sfont = garamond(W * 0.040 * k)
    y = text_block(d, balanced(d, sub, sfont, int(W * 0.72)), sfont, 0, y, (225, 205, 180), 1.25, cx=W // 2)
    if trust:
        y += int(sfont.size * 0.5); y = tracked(d, TRUST, sans(W * 0.019 * k, "SemiBold"), W // 2, y, GOLD, W * 0.004)
    fw = int(W * (0.56 if tablet else 0.80)); top = int(y + H * 0.045)
    dev, screen, band = device(shot, fw)
    tilt = -5 if i % 2 else 5
    rot = dev.rotate(tilt, resample=Image.BICUBIC, expand=True)
    dx = (W - rot.size[0]) // 2
    place(canvas, rot, dx, top, int(W * 0.035), int(W * 0.025), 0.7)
    x0, y0, x1, y1, side, cy = co
    card = callout(screen, band, (x0, y0, x1, y1), 1.25 if tablet else 1.36, int(W * (0.5 if tablet else 0.68)), int(W * 0.010), int(W * 0.026), max(2, int(W * 0.0028)), outline=GOLD, fill=(28, 18, 18))
    cyy = int(top + (H - top) * cy - card.size[1] / 2); margin = int(W * 0.04)
    cx = margin if side == "left" else W - margin - card.size[0]
    place(canvas, card, cx, cyy, int(W * 0.022), int(W * 0.012), 0.6)
    return canvas.convert("RGB")


# ── STYLE: asymmetric ────────────────────────────────────────────────────────
def render_asym(i, shot, art, latin, title, sub, co, trust, size, tablet):
    W, H = size
    k = 0.70 if tablet else 1.0
    left_phone = (i % 2 == 0)                 # the phone alternates sides
    canvas = Image.new("RGBA", (W, H), PAGE + (255,))
    a = painting(W, H, art, blur=0.04, color=0.9, bright=1.08).convert("RGBA")
    a.putalpha(vgradient(W, H, [(0, 40), (0.30, 120), (1.0, 215)]))
    canvas.alpha_composite(a)
    d = ImageDraw.Draw(canvas)
    mx = int(W * 0.075)
    # index and hairline
    nf = serif(W * 0.05 * k, 500, italic=True)
    y = int(H * 0.050)
    d.text((mx, y), ROMAN[i - 1], font=nf, fill=GOLD)
    d.line([(mx + int(W * 0.09), y + nf.size * 0.62), (W - mx, y + nf.size * 0.62)], fill=GOLD, width=max(1, int(W * 0.0012)))
    y += int(nf.size * 1.6)
    y = tracked(d, latin, sans(W * 0.021 * k, "SemiBold"), mx, y, MAROON, W * 0.006, align="left")
    y += int(W * 0.018)
    lines = title.split("\n")
    t1 = serif(W * 0.112 * k, 760); t2 = serif(W * 0.112 * k, 500, italic=True)
    d.text((mx, y), lines[0], font=t1, fill=INK); y += int((t1.getmetrics()[0] + t1.getmetrics()[1]) * 0.98)
    for l in lines[1:]:
        d.text((mx, y), l, font=t2, fill=MAROON); y += int((t2.getmetrics()[0] + t2.getmetrics()[1]) * 0.98)
    y += int(W * 0.015)
    sfont = sans(W * 0.035 * k)
    y = text_block(d, wrap(d, sub, sfont, int(W * 0.70)), sfont, mx, y, INK, 1.32, align="left")
    if trust:
        y += int(sfont.size * 0.6); y = tracked(d, TRUST, sans(W * 0.018 * k, "SemiBold"), mx, y, GOLD, W * 0.004, align="left")
    fw = int(W * (0.62 if tablet else 0.86)); top = int(y + H * 0.04)
    dev, screen, band = device(shot, fw)
    dx = -int(fw * 0.16) if left_phone else W - fw + int(fw * 0.16)
    place(canvas, dev, dx, top, int(W * 0.03), int(W * 0.02))
    x0, y0, x1, y1, side, cy = co
    card = callout(screen, band, (x0, y0, x1, y1), 1.30 if tablet else 1.42, int(W * 0.60), int(W * 0.012), int(W * 0.03), max(2, int(W * 0.0028)))
    cyy = int(top + (H - top) * max(0.25, cy) - card.size[1] / 2)
    cx = W - int(W * 0.045) - card.size[0] if left_phone else int(W * 0.045)
    place(canvas, card, cx, cyy, int(W * 0.022), int(W * 0.012), 0.45)
    return canvas.convert("RGB")


STYLES = {"wash": render_wash, "vellum": render_vellum, "nocturne": render_nocturne, "asymmetric": render_asym}


def feature_graphic(path, style):
    W, H = 1024, 500
    dark = style == "nocturne"
    canvas = painting(W, H, "raphael", blur=0.04, bright=0.55 if dark else 1.08).convert("RGBA")
    veil = Image.new("RGBA", (W, H), (NIGHT if dark else PAGE) + (150 if dark else 170,)); canvas.alpha_composite(veil)
    icon = Image.open("prototype/icon-assets/introibo-appstore-1024.png").convert("RGBA").resize((300, 300), Image.LANCZOS)
    m = Image.new("L", icon.size, 0); ImageDraw.Draw(m).rounded_rectangle([0, 0, 299, 299], radius=66, fill=255); icon.putalpha(m)
    place(canvas, icon, 90, 100, 18, 10, 0.5)
    d = ImageDraw.Draw(canvas)
    d.text((450, 120), "Introibo", font=serif(118, 760, italic=dark), fill=CREAM if dark else MAROON)
    f = sans(33)
    d.text((456, 268), "A prayer companion for the", font=f, fill=(225, 205, 180) if dark else INK)
    d.text((456, 310), "traditional Catholic life.", font=f, fill=(225, 205, 180) if dark else INK)
    tracked(d, TRUST, sans(16, "SemiBold"), 456 + 262, 372, GOLD if dark else MAROON, 2)
    canvas.convert("RGB").save(path, "PNG")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--style", choices=list(STYLES), default="wash")
    ap.add_argument("--only", choices=["apple", "play"])
    ap.add_argument("--sizes", help="comma-separated size keys (default: all)")
    ap.add_argument("--shots", help="comma-separated screenshot numbers (default: all)")
    ap.add_argument("--out", help="output folder (default: store-screenshots/<version>[-<style>])")
    args = ap.parse_args()
    want = set(args.sizes.split(",")) if args.sizes else None
    nums = set(int(x) for x in args.shots.split(",")) if args.shots else None
    out_dir = args.out or f"{ROOT}/{VERSION}" + ("" if args.style == "wash" else f"-{args.style}")
    render = STYLES[args.style]
    n = 0
    for store, sizes in (("apple", APPLE), ("play", PLAY)):
        if args.only and args.only != store: continue
        out = f"{out_dir}/{store}"; os.makedirs(out, exist_ok=True)
        for i, (raw, art, latin, title, sub, co, trust) in enumerate(SHOTS, 1):
            if nums and i not in nums: continue
            shot = Image.open(f"{RAW}/{raw}").convert("RGB")
            for key, size in sizes.items():
                if want and key not in want: continue
                tablet = key in ("ipad13", "tablet-7in", "tablet-10in")
                img = render(i, shot, art, latin, title, sub, co, trust, size, tablet)
                name = f"{i:02d}-{key}.png" if store == "apple" else f"{key}-{i:02d}.png"
                img.save(f"{out}/{name}", "PNG"); n += 1
        if store == "play" and not want and not nums:
            feature_graphic(f"{out}/feature-graphic-1024x500.png", args.style); n += 1
    print(f"Wrote {n} images under {out_dir}/")


if __name__ == "__main__":
    sys.exit(main())
