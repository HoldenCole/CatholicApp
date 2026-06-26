#!/usr/bin/env python3
"""Render the Google Play feature graphic (1024 x 500) in house style.

Matches the existing google-play-screenshots/feature-graphic-1024x500.png
layout exactly (icon left, title block right, gold divider, two count lines
beneath) but uses the canonical, verified numbers — the committed graphic
shipped with stale counts (428 Propers / 40 Prayers, both pre-1.2.1).

Style constants mirror scripts/make_marketing.py (the Apple house style).
Icon is the 512x512 monstrance from google-play-screenshots/app-icon-512.png
(itself derived from the same SVG as the Android launcher icon).

Run from repo root:  python3 scripts/make_play_feature_graphic.py
"""
import os
from PIL import Image, ImageDraw, ImageFont
import make_marketing as mm

OUT = "google-play-screenshots/feature-graphic-1024x500.png"
ICON = "google-play-screenshots/app-icon-512.png"

W, H = 1024, 500

TITLE = "Introíbo"
SUBTITLE_LINES = ["A prayer companion for the", "traditional Catholic life"]
COUNT_LINES = [
    "1962 Missal  ·  Divine Office  ·  574 Propers",
    "67 Prayers  ·  Rosary  ·  Latin Lessons",
]

# Colours from make_marketing
GOLD      = mm.GOLD              # (214, 178, 110)
TITLE_COL = mm.TITLE_COL         # (247, 242, 232)
DESC_COL  = mm.DESC_COL          # (231, 214, 180)


def gradient(w, h):
    return mm._gradient(w, h)


def main():
    img = gradient(W, H).convert("RGBA")
    d = ImageDraw.Draw(img)

    # ─── Icon block (left) ───────────────────────────────────────────────
    icon_size = 240
    icon_x = 70
    icon_y = (H - icon_size) // 2
    icon = Image.open(ICON).convert("RGBA").resize((icon_size, icon_size), Image.LANCZOS)
    img.alpha_composite(icon, (icon_x, icon_y))

    # ─── Text block (right) ──────────────────────────────────────────────
    text_x = icon_x + icon_size + 60
    title_font = ImageFont.truetype(mm.TITLE_FONT, 76)
    sub_font   = ImageFont.truetype(mm.DESC_FONT, 30)
    count_font = ImageFont.truetype(mm.DESC_FONT, 22)

    # Title
    y = 132
    d.text((text_x, y), TITLE, font=title_font, fill=TITLE_COL,
           stroke_width=1, stroke_fill=TITLE_COL)
    bb = title_font.getbbox(TITLE)
    y += (bb[3] - bb[1]) + 36

    # Subtitle (two lines)
    for line in SUBTITLE_LINES:
        d.text((text_x, y), line, font=sub_font, fill=DESC_COL)
        bb = sub_font.getbbox(line)
        y += (bb[3] - bb[1]) + 8
    y += 12

    # Gold divider (horizontal rule under the subtitle)
    rule_w = 360
    d.line([(text_x, y), (text_x + rule_w, y)], fill=GOLD, width=2)
    y += 22

    # Two count lines
    for line in COUNT_LINES:
        d.text((text_x, y), line, font=count_font, fill=DESC_COL)
        bb = count_font.getbbox(line)
        y += (bb[3] - bb[1]) + 10

    img.convert("RGB").save(OUT, "PNG")
    print(f"wrote {OUT}")


if __name__ == "__main__":
    main()
