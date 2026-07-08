#!/usr/bin/env python3
"""Generate Google Play marketing screenshots in the Introibo house style.

Counterpart to scripts/make_marketing.py — same house style (Playfair italic
title, EB Garamond italic description, gold cross + corner brackets +
divider, alternating ±3° tilt, parchment-red gradient) but rendered at the
Google Play canvas sizes:

    phone        1080 x 1920
    tablet-7in   1200 x 2134
    tablet-10in  1620 x 2880

Read docs/marketing-screenshots.md before changing the style — same rules
apply here.

Usage:
    python3 scripts/make_play_marketing.py    # regenerate all into google-play-screenshots/
    pip install Pillow                        # one-time

Inputs : raw Android captures listed in SHOTS (drop them in the repo root).
         A capture file name like 'phone-01-today.png' is matched only by
         its base path; what matters is the SHOT_FILES table below.
Output : google-play-screenshots/
           phone-NN.png          1080 x 1920
           tablet-7in-NN.png     1200 x 2134
           tablet-10in-NN.png    1620 x 2880

If a raw capture is missing, the slot is skipped with a warning so a
partial regeneration (e.g. only the phone set) is fine.
"""
import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import make_marketing as mm

# ── House style (mirrors make_marketing.py — keep in sync) ──────────────────
TITLE_FONT = mm.TITLE_FONT
DESC_FONT  = mm.DESC_FONT
GOLD       = mm.GOLD
TITLE_COL  = mm.TITLE_COL
DESC_COL   = mm.DESC_COL

# Google Play required pixel sizes (portrait)
SIZES = {
    "phone":        (1080, 1920),
    "tablet-7in":   (1200, 2134),
    "tablet-10in":  (1620, 2880),
}

# Per-canvas layout fractions (phone vs tablet) — same numbers as Apple set
TITLE_FRAC = {"phone": 0.100, "tablet": 0.078}
DESC_FRAC  = {"phone": 0.0335, "tablet": 0.026}
SHOT_WFRAC = {"phone": 0.665, "tablet": 0.50}
TILT_DEG   = 3


def _generate(shot_path, title, desc, tilt, size_key, out):
    W, H = SIZES[size_key]
    key = "phone" if size_key == "phone" else "tablet"

    canvas = mm._gradient(W, H).convert("RGBA")
    d = ImageDraw.Draw(canvas)

    # Corner brackets + tiny gold cross at top.
    mm._brackets(d, W, H, int(W * 0.035), int(W * 0.05), max(2, int(W * 0.0024)))
    mm._cross(d, W // 2, int(H * 0.030), int(W * 0.026), max(2, int(W * 0.0026)))

    # Title block.
    tsize = int(W * TITLE_FRAC[key]); dsize = int(W * DESC_FRAC[key])
    tfont = ImageFont.truetype(TITLE_FONT, tsize)
    dfont = ImageFont.truetype(DESC_FONT, dsize)
    y = int(H * 0.080)
    y = mm._centered(d, mm._wrap(d, title, tfont, int(W * 0.84)), tfont,
                     W // 2, y, TITLE_COL, int(tsize * 0.12),
                     stroke=max(1, int(tsize * 0.012)))

    # Divider.
    y += int(H * 0.016)
    mm._divider(d, W // 2, y, int(W * 0.10), GOLD)
    y += int(H * 0.016)

    # Description.
    y = mm._centered(d, mm._wrap(d, desc, dfont, int(W * 0.70)), dfont,
                     W // 2, y, DESC_COL, int(dsize * 0.20))

    # Device shot.
    shot = Image.open(shot_path).convert("RGB")
    rw, rh = shot.size
    tw = int(W * SHOT_WFRAC[key]); sc = tw / rw
    shot = mm._rounded(shot.resize((tw, int(rh * sc)), Image.LANCZOS),
                       int(tw * 0.058))

    shadow = Image.new("RGBA", (shot.size[0] + 90, shot.size[1] + 90), (0, 0, 0, 0))
    sh = Image.new("RGBA", shot.size, (8, 4, 6, 255))
    sh.putalpha(shot.split()[3])
    shadow.paste(sh, (45, 48), sh)
    shadow = shadow.filter(ImageFilter.GaussianBlur(30))

    shot_r   = shot.rotate(tilt, expand=True, resample=Image.BICUBIC)
    shadow_r = shadow.rotate(tilt, expand=True, resample=Image.BICUBIC)

    top = int(y + H * 0.05); cx = W // 2
    canvas.alpha_composite(shadow_r, (cx - shadow_r.size[0] // 2, max(0, top - 45)))
    canvas.alpha_composite(shot_r,   (cx - shot_r.size[0] // 2, top))

    canvas.convert("RGB").save(out, "PNG")


# ── Raw Android captures, by slot. Drop these in the repo root before
#    running. File names are intentionally explicit so the mapping never
#    drifts: phone-NN-<feature>.png; tablet-NN-<feature>.png. Same raw
#    capture is used for all three canvas sizes (it's resized to fit). ──────
OUT_DIR = "google-play-screenshots"

# (n, raw capture, title, description, tilt) — captions verified for 1.2.2
SHOTS = [
    (1,  "android-01-today.png",     "Your Daily Companion",         "Liturgical calendar, propers, penance, and prayer rule",      -TILT_DEG),
    (2,  "android-02-missal.png",    "The Complete 1962 Missal",     "574 daily Propers woven into the Ordinary in correct order",   TILT_DEG),
    (3,  "android-03-prayers.png",   "67 Traditional Prayers",       "Personal prayer rule with morning, midday, and evening",      -TILT_DEG),
    (4,  "android-04-learn.png",     "Learn Latin",                  "10 lessons, 97 flashcards, and daily vocabulary",              TILT_DEG),
    (5,  "android-05-reference.png", "Reference Library",            "Articles, propers search, history, and glossary",             -TILT_DEG),
    (6,  "android-06-office.png",    "The Divine Office",            "All 8 canonical hours of the 1962 Roman Breviary",             TILT_DEG),
    (7,  "android-07-rosary.png",    "The Holy Rosary",              "Bead-by-bead with Joyful, Sorrowful, and Glorious mysteries", -TILT_DEG),
    (8,  "android-08-stations.png",  "Stations of the Cross",        "14 stations with meditations and Stabat Mater",                TILT_DEG),
    (9,  "android-09-regina.png",    "Regina Caeli",                 "Every prayer in Latin and English side-by-side",              -TILT_DEG),
    (10, "android-10-settings.png",  "Customize Your Experience",    "Missal rite, penance discipline, language, and appearance",    TILT_DEG),
]


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    written = skipped = 0
    for num, raw, title, desc, tilt in SHOTS:
        if not os.path.exists(raw):
            print(f"skip  {num:02d}  ({raw} not found in repo root)")
            skipped += 1
            continue
        for size_key in SIZES:
            if size_key == "phone":
                out = f"{OUT_DIR}/phone-{num:02d}.png"
            else:
                out = f"{OUT_DIR}/{size_key}-{num:02d}.png"
            _generate(raw, title, desc, tilt, size_key, out)
            written += 1
        print(f"ok    {num:02d}  -> phone + tablet-7in + tablet-10in")
    print(f"\nwrote {written} images; skipped {skipped} slot(s).")


if __name__ == "__main__":
    main()
