# Store Screenshots — Design & Process

The App Store and Google Play screenshots are generated, never hand-made,
by `scripts/make_store_screenshots.py` from one table of copy and one folder
of raw in-app captures. This document is the single source of truth for the
design; read it before changing the generator.

(The earlier design — tilted phone, gold corner brackets, counts in the
captions — lives on in `1.2.1 screenshots/` and `scripts/make_marketing.py` /
`scripts/make_play_marketing.py` for reference only. Do not regenerate from
those.)

---

## The rules

1. **No counts in the copy.** Never "67 prayers", "574 propers", "10 lessons",
   "8 hours". The set must stay true as content is added. Say what a thing
   *is*, not how many there are.
2. **One design for both stores.** Every canvas size is rendered from the
   same table; the Play set is not a separate design.
3. **Headline: Playfair Display Italic.** Subhead and eyebrow: EB Garamond
   Regular (upright). Eyebrow and pills are letterspaced capitals in gold.
4. **The phone stands upright** in a dark device frame, centred, and runs off
   the bottom edge on every canvas. No tilt.
5. **American spelling** in captions.
6. The first and last screenshots carry the three pills: AD-FREE · OFFLINE ·
   NO ACCOUNT.

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

- Gold cross at the top, then the eyebrow (EB Garamond, 0.0245 W,
  tracking 0.28 em), the headline (Playfair Italic, 0.094 W, up to two
  lines in a 0.84 W column), the subhead (0.0335 W, 0.77 W column), the
  pills where the table lists them.
- Device frame 0.76 W wide on phones (0.56 W on tablets, with the type scale
  at 0.68), starting 0.04 H below the text, bezel 2.8 % of the frame, outer
  corner radius 13.5 %, screen radius 11.2 %, a Dynamic Island pill, a soft
  shadow and a soft red glow behind the top of the device.
- Background: vertical gradient (176, 46, 46) → (96, 14, 22). Gold
  (214, 178, 110); headline (250, 245, 234); subhead (235, 220, 190).

## Raw captures

`store-screenshots/raw/NN-<name>.png`, one per screenshot, portrait, taken
in the app with the status bar cropped away (the generator adds a status
band in the app's own header colour and the Dynamic Island). Any size works;
width 1200 px or more is best. The 1.3.0 set uses captures recovered from
the 1.2.1 renders (822 px wide) because the originals were not kept —
**replace them with fresh captures of the current build** (and add the
widgets, the year calendar and the Spanish screens) by dropping files into
`raw/` and editing `SHOTS`.

The App Store export order is `SHOTS` order; map each capture to its copy by
looking at it, never by file name alone.

## Regenerating

    pip install Pillow
    python3 scripts/make_store_screenshots.py            # both stores
    python3 scripts/make_store_screenshots.py --only apple

Output: `store-screenshots/<version>/apple/NN-<size>.png` and
`store-screenshots/<version>/play/<key>-NN.png` plus the feature graphic.
Bump `VERSION` in the script for a new release folder.
