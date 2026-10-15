#!/usr/bin/env python3
"""Store screenshots for Introibo — App Store and Google Play, one design.

The design (read docs/marketing-screenshots.md before changing it):
  a deep-red vertical gradient with a soft glow behind the device; a small
  gold cross; an eyebrow line in gold letterspaced capitals; the headline in
  Playfair Display Italic; a one-sentence subhead in EB Garamond; the phone
  upright in a dark device frame, centred, bleeding off the bottom edge.
  The copy names no counts (prayers, propers, lessons...), so the set never
  goes stale when content is added.

Inputs : store-screenshots/raw/NN-<name>.png — one in-app capture per
         screenshot, any size, portrait, no device frame (the status bar may
         be cropped away). SHOTS below maps each to its copy.
Output : store-screenshots/<version>/apple/NN-<size>.png
         store-screenshots/<version>/play/{phone,tablet-7in,tablet-10in}-NN.png
         store-screenshots/<version>/play/feature-graphic-1024x500.png

    python3 scripts/make_store_screenshots.py                 # everything
    python3 scripts/make_store_screenshots.py --only apple     # or play
    pip install Pillow                                         # one-time
"""
import argparse, os, sys
from PIL import Image, ImageDraw, ImageFont, ImageFilter

VERSION = "1.3.0"
RAW_DIR = "store-screenshots/raw"
OUT_DIR = f"store-screenshots/{VERSION}"

FONT_DIR = "android/app/src/main/res/font"
TITLE_FONT = f"{FONT_DIR}/playfair_display_italic.ttf"
SUB_FONT = f"{FONT_DIR}/eb_garamond_regular.ttf"
EYEBROW_FONT = f"{FONT_DIR}/eb_garamond_regular.ttf"

# Palette
BG_TOP = (176, 46, 46)
BG_BOTTOM = (96, 14, 22)
GLOW = (214, 74, 62)
GOLD = (214, 178, 110)
TITLE_COL = (250, 245, 234)
SUB_COL = (235, 220, 190)
FRAME = (22, 18, 18)
FRAME_EDGE = (62, 54, 52)

# Canvases
APPLE = {"6.9": (1320, 2868), "6.5": (1284, 2778), "ipad13": (2048, 2732)}
PLAY = {"phone": (1080, 1920), "tablet-7in": (1200, 2134), "tablet-10in": (1620, 2880)}

# ── The set: raw capture, eyebrow, headline, subhead, pills ──────────────────
SHOTS = [
    ("01-today.png",     "HODIE · TODAY",            "Your Daily Companion",
     "The feast, the propers of the Mass, the day's penance, and your own rule of prayer — all at a glance.",
     ["AD-FREE", "OFFLINE", "NO ACCOUNT"]),
    ("02-missal.png",    "MISSA · THE MASS",          "The Complete 1962 Missal",
     "Every Proper woven into the Ordinary in its right place, Latin and English side by side.", []),
    ("06-office.png",    "OFFICIUM DIVINUM",          "The Divine Office",
     "Every canonical hour of the Roman Breviary at its proper time, with the psalms, hymns, and lessons of the day.", []),
    ("03-prayers.png",   "ORATIO · PRAYER",           "A Rule of Prayer",
     "Traditional prayers for morning, midday, and evening, gathered into a rule you keep.", []),
    ("07-rosary.png",    "ROSARIUM",                  "The Holy Rosary",
     "Bead by bead, mystery by mystery, with every prayer in Latin and English.", []),
    ("08-stations.png",  "VIA CRUCIS",                "The Stations of the Cross",
     "With Tiepolo's engravings, meditations at every station, and the Stabat Mater.", []),
    ("09-bilingual.png", "LATINE ET ANGLICE",         "Latin and English, Side by Side",
     "The Church's own words with a faithful translation beside them, on every page.", []),
    ("04-latin.png",     "SCHOLA LATINA",             "Learn to Pray in Latin",
     "Pronunciation, grammar, and the prayers of the Mass, word by word.", []),
    ("05-library.png",   "LIBER · REFERENCE",         "A Library of the Faith",
     "The history of the Mass, a glossary, articles, and every Proper, searchable.", []),
    ("10-settings.png",  "RITUS · SETTINGS",          "Make It Yours",
     "Choose your Missal, your discipline of penance, your language, and your look.",
     ["AD-FREE", "OFFLINE", "NO ACCOUNT"]),
]


# ── drawing helpers ──────────────────────────────────────────────────────────
def gradient(w, h):
    base = Image.new("RGB", (1, h))
    px = base.load()
    for y in range(h):
        t = y / (h - 1)
        px[0, y] = tuple(int(BG_TOP[i] + (BG_BOTTOM[i] - BG_TOP[i]) * t) for i in range(3))
    return base.resize((w, h), Image.BILINEAR)


def glow(canvas, cx, cy, rx, ry):
    layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(layer).ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=GLOW + (120,))
    layer = layer.filter(ImageFilter.GaussianBlur(rx * 0.45))
    canvas.alpha_composite(layer)


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


def centered(draw, lines, font, cx, y, fill, gap):
    for ln in lines:
        w = draw.textlength(ln, font=font)
        asc, desc = font.getmetrics()
        draw.text((cx - w / 2, y), ln, font=font, fill=fill)
        y += asc + desc * 0.4 + gap
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


def cross(draw, cx, cy, size, thick):
    draw.rectangle([cx - thick / 2, cy - size, cx + thick / 2, cy + size * 0.9], fill=GOLD)
    draw.rectangle([cx - size * 0.62, cy - size * 0.42 - thick / 2, cx + size * 0.62, cy - size * 0.42 + thick / 2], fill=GOLD)


def pills(draw, labels, font, cx, y, tracking):
    pad_x, pad_y, gap = int(font.size * 0.9), int(font.size * 0.42), int(font.size * 0.7)
    asc, desc = font.getmetrics()
    ws = [sum(draw.textlength(ch, font=font) for ch in l) + tracking * (len(l) - 1) + 2 * pad_x for l in labels]
    x = cx - (sum(ws) + gap * (len(ws) - 1)) / 2
    h = asc + desc + 2 * pad_y
    for l, w in zip(labels, ws):
        draw.rounded_rectangle([x, y, x + w, y + h], radius=h / 2, outline=GOLD, width=max(2, int(font.size * 0.07)))
        tracked(draw, l, font, x + w / 2, y + pad_y, GOLD, tracking)
        x += w + gap
    return y + h


def edge_color(img, rows, bottom=False):
    """The average colour of the first (or last) `rows` rows — the app's own background there."""
    strip = img.crop((0, img.size[1] - rows, img.size[0], img.size[1])) if bottom else img.crop((0, 0, img.size[0], rows))
    px = strip.resize((1, 1), Image.BOX).getpixel((0, 0))
    return px[:3]


def prepare(shot, _unused=0.0):
    """A capture ready for the frame: its anti-aliased edges trimmed and a status-bar
    band added above it in the app's own header colour (captures are taken without one)."""
    w, h = shot.size
    t = max(2, int(w * 0.006))
    shot = shot.crop((t, t, w - t, h - t))
    w, h = shot.size
    band = int(w * 0.115)
    rows = max(2, int(h * 0.01))
    top, bottom = edge_color(shot, rows), edge_color(shot, rows, bottom=True)
    # a capture with rounded corners (one recovered from an older render) shows
    # whatever lay behind them: paint the corners in the app's own colours
    rad = int(w * 0.07)
    corners = Image.new("L", (w, h), 255)
    ImageDraw.Draw(corners).rounded_rectangle([0, 0, w - 1, h - 1], radius=rad, fill=0)
    fill = Image.new("RGB", (w, h), bottom)
    ImageDraw.Draw(fill).rectangle([0, 0, w, h // 2], fill=top)
    shot = Image.composite(fill, shot, corners)
    out = Image.new("RGB", (w, h + band), bottom)
    ImageDraw.Draw(out).rectangle([0, 0, w, band], fill=top)
    out.paste(shot, (0, band))
    return out


def device(shot, frame_w):
    """The capture inside a dark phone frame; returns an RGBA image (frame width = frame_w)."""
    bezel = int(frame_w * 0.028)
    screen_w = frame_w - 2 * bezel
    shot = prepare(shot)
    sc = screen_w / shot.size[0]
    screen = shot.resize((screen_w, int(shot.size[1] * sc)), Image.LANCZOS).convert("RGBA")
    frame_h = screen.size[1] + 2 * bezel
    r_out = int(frame_w * 0.135)
    r_in = int(screen_w * 0.112)
    img = Image.new("RGBA", (frame_w, frame_h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([0, 0, frame_w - 1, frame_h - 1], radius=r_out, fill=FRAME, outline=FRAME_EDGE, width=max(2, int(frame_w * 0.004)))
    mask = Image.new("L", screen.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, screen_w - 1, screen.size[1] - 1], radius=r_in, fill=255)
    screen.putalpha(mask)
    img.alpha_composite(screen, (bezel, bezel))
    # Dynamic Island
    pw, ph = int(screen_w * 0.30), int(screen_w * 0.082)
    px, py = (frame_w - pw) // 2, bezel + int(screen_w * 0.035)
    d.rounded_rectangle([px, py, px + pw, py + ph], radius=ph // 2, fill=(8, 8, 8))
    return img


def shadow_of(img, blur, offset):
    sh = Image.new("RGBA", (img.size[0] + blur * 6, img.size[1] + blur * 6), (0, 0, 0, 0))
    dark = Image.new("RGBA", img.size, (20, 6, 8, 200))
    dark.putalpha(img.split()[3].point(lambda a: int(a * 0.85)))
    sh.paste(dark, (blur * 3, blur * 3 + offset), dark)
    return sh.filter(ImageFilter.GaussianBlur(blur)), blur * 3


# ── one screenshot ───────────────────────────────────────────────────────────
def render(shot_path, eyebrow, title, sub, pill_labels, size, tablet):
    W, H = size
    canvas = gradient(W, H).convert("RGBA")
    d = ImageDraw.Draw(canvas)
    # type scale (fractions of the width; tablets carry a narrower column)
    k = 0.68 if tablet else 1.0
    t_size = int(W * 0.094 * k)
    s_size = int(W * 0.0335 * k)
    e_size = int(W * 0.0245 * k)
    tfont = ImageFont.truetype(TITLE_FONT, t_size)
    sfont = ImageFont.truetype(SUB_FONT, s_size)
    efont = ImageFont.truetype(EYEBROW_FONT, e_size)
    pfont = ImageFont.truetype(EYEBROW_FONT, int(e_size * 0.86))
    col = int(W * (0.64 if tablet else 0.84))

    y = int(H * (0.060 if tablet else 0.052))
    cross(d, W // 2, y + int(e_size * 0.9), int(e_size * 0.9), max(2, int(W * 0.0022)))
    y += int(e_size * 2.4)
    y = tracked(d, eyebrow, efont, W // 2, y, GOLD, e_size * 0.28)
    y += int(t_size * 0.22)
    y = centered(d, wrap(d, title, tfont, col), tfont, W // 2, y, TITLE_COL, int(t_size * 0.04))
    y += int(s_size * 0.55)
    y = centered(d, wrap(d, sub, sfont, int(col * 0.92)), sfont, W // 2, y, SUB_COL, int(s_size * 0.18))
    if pill_labels:
        y += int(s_size * 0.7)
        y = pills(d, pill_labels, pfont, W // 2, y, e_size * 0.18)

    # the device
    shot = Image.open(shot_path).convert("RGB")
    top = int(y + H * (0.045 if tablet else 0.040))
    # the frame runs off the bottom edge, so a capture is cropped by the canvas, never
    # padded: when a capture is too short to reach the bottom at full width, the frame
    # is narrowed until its bottom edge just passes the canvas edge
    avail = H - top + int(W * 0.06)
    pw, ph = prepare(shot, 0.0).size
    per_width = (1 - 2 * 0.028) * ph / pw + 2 * 0.028      # frame height per unit of frame width
    fw = min(int(W * (0.56 if tablet else 0.76)), int(avail / per_width))
    dev = device(shot, fw)
    glow(canvas, W // 2, top + int(dev.size[1] * 0.25), int(fw * 0.95), int(fw * 0.95))
    sh, pad = shadow_of(dev, int(W * 0.03), int(W * 0.02))
    canvas.alpha_composite(sh, ((W - dev.size[0]) // 2 - pad, top - pad))
    canvas.alpha_composite(dev, ((W - dev.size[0]) // 2, top))
    return canvas.convert("RGB")


def feature_graphic(path):
    W, H = 1024, 500
    canvas = gradient(W, H).convert("RGBA")
    glow(canvas, 250, 250, 330, 330)
    icon = Image.open("prototype/icon-assets/introibo-appstore-1024.png").convert("RGBA").resize((300, 300), Image.LANCZOS)
    m = Image.new("L", icon.size, 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, 299, 299], radius=66, fill=255)
    icon.putalpha(m)
    sh, pad = shadow_of(icon, 18, 10)
    canvas.alpha_composite(sh, (100 - pad, 100 - pad))
    canvas.alpha_composite(icon, (100, 100))
    d = ImageDraw.Draw(canvas)
    tracked(d, "INTROIBO AD ALTARE DEI", ImageFont.truetype(EYEBROW_FONT, 24), 680, 128, GOLD, 6)
    d.text((470, 165), "Introibo", font=ImageFont.truetype(TITLE_FONT, 118), fill=TITLE_COL)
    sub = ImageFont.truetype(SUB_FONT, 34)
    d.text((474, 310), "A prayer companion for the", font=sub, fill=SUB_COL)
    d.text((474, 350), "traditional Catholic life.", font=sub, fill=SUB_COL)
    pills(d, ["AD-FREE", "OFFLINE", "NO ACCOUNT"], ImageFont.truetype(EYEBROW_FONT, 20), 680, 412, 4)
    canvas.convert("RGB").save(path, "PNG")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", choices=["apple", "play"])
    args = ap.parse_args()
    n = 0
    if args.only in (None, "apple"):
        out = f"{OUT_DIR}/apple"; os.makedirs(out, exist_ok=True)
        for i, (raw, eyebrow, title, sub, pl) in enumerate(SHOTS, 1):
            for key, size in APPLE.items():
                render(f"{RAW_DIR}/{raw}", eyebrow, title, sub, pl, size, key == "ipad13").save(f"{out}/{i:02d}-{key}.png", "PNG"); n += 1
    if args.only in (None, "play"):
        out = f"{OUT_DIR}/play"; os.makedirs(out, exist_ok=True)
        for i, (raw, eyebrow, title, sub, pl) in enumerate(SHOTS, 1):
            for key, size in PLAY.items():
                render(f"{RAW_DIR}/{raw}", eyebrow, title, sub, pl, size, key != "phone").save(f"{out}/{key}-{i:02d}.png", "PNG"); n += 1
        feature_graphic(f"{out}/feature-graphic-1024x500.png"); n += 1
    print(f"Wrote {n} images under {OUT_DIR}/")


if __name__ == "__main__":
    sys.exit(main())
