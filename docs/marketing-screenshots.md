# Store Screenshots — Design & Process

The App Store and Google Play screenshots are generated, never hand-made,
by `scripts/make_store_screenshots.py` from one table of copy and one folder
of raw in-app captures. This document is the spec; read it before changing
the generator. The reference register is the listings of Hallow and
Sanctifica: a painting softened into a wash, a bold serif headline, one
sentence of support, a real-looking phone, and one zoomed callout.

(The earlier sets — `1.2.1 screenshots/`, `scripts/make_marketing.py`,
`scripts/make_play_marketing.py` — are history only. Do not regenerate
from them.)

## The rules

1. **No counts in the copy.** Never "67 prayers", "574 propers", "10
   lessons", "8 hours". Say what a thing *is*; the set must stay true as
   content is added.
2. **One design for both stores**, rendered from one table.
3. **Headline:** Playfair Display, weight 760, deep maroon, two short lines
   (an explicit line break in the table), an imperative that ends with a
   full stop. **Subhead:** Inter Medium, warm ink, up to three lines.
   **Trust line** (first and last screens, and the feature graphic):
   AD-FREE · OFFLINE · NO ACCOUNT · NO SUBSCRIPTION in gold tracked caps.
4. **The phone stands upright** in a dark frame with a drawn status bar
   (9:41, signal, Wi-Fi, battery) and Dynamic Island, centred, running off
   the bottom edge. No tilt.
5. **One callout per screen:** a piece of the screen enlarged on a white
   card with a gold hairline, laid over the phone's edge near its source.
6. **Background:** a public-domain painting (`store-screenshots/art/`, see
   CREDITS.md), cover-fit, blurred, slightly desaturated, at 78 % over the
   cream page, with a cream wash over the text area that fades out by
   mid-height. Three paintings rotate through the set.
7. American spelling.

## Canvases

| Store | Key | Pixels |
|---|---|---|
| Apple | `6.9` | 1320 × 2868 |
| Apple | `6.5` | 1284 × 2778 |
| Apple | `ipad13` | 2048 × 2732 |
| Play | `phone` | 1080 × 1920 |
| Play | `tablet-7in` | 1200 × 2134 |
| Play | `tablet-10in` | 1620 × 2880 |
| Play | feature graphic | 1024 × 500 |

## Layout (fractions of the canvas width W / height H)

- Badge (maroon disc, gold cross) at 0.04 H; headline 0.108 W; subhead
  0.037 W in a 0.70 W column; tablets scale the type by 0.70 and the
  column to 0.62 W.
- Frame 0.84 W wide (0.60 W on tablets), 0.035 H below the text; bezel
  2.6 %, outer radius 13.5 %, screen radius 11.2 %.
- Callout: the crop (fractions of the capture) enlarged 1.42× (1.30× on
  tablets) up to 0.74 W wide, white card, gold hairline, soft shadow, set
  0.035 W from the canvas edge on its side, centred on the given fraction
  of the visible phone height.
- Colours: page (247, 241, 229), maroon (104, 18, 26), ink (64, 50, 46),
  gold (196, 158, 92), card (253, 250, 244).

## Raw captures

`store-screenshots/raw/NN-<name>.png`, one per screenshot, portrait, taken
in the app with the status bar cropped away (the generator draws one).
Width 1200 px or more is best. The 1.3.0 set uses captures recovered from
the 1.2.1 renders (822 px wide) because the originals were not kept —
**replace them with fresh captures of the current build** (and add the
widgets, the year calendar and the Spanish screens) by dropping files into
`raw/` and editing `SHOTS` (capture, painting, headline, subhead, callout
crop + side + height, trust line). Map each capture to its copy by looking
at it, never by file name alone.

## Regenerating

    pip install Pillow
    python3 scripts/make_store_screenshots.py                # both stores
    python3 scripts/make_store_screenshots.py --only apple --sizes 6.9

Output: `store-screenshots/<version>/apple/NN-<size>.png`,
`store-screenshots/<version>/play/<key>-NN.png` and the feature graphic.
Bump `VERSION` in the script for a new release folder. Fonts live in
`store-screenshots/fonts/` (Playfair Display variable, Inter; OFL).
