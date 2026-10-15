# Introibo App Store style

The store screenshots for the App Store and Google Play, generated from
one table of copy and the raw captures in `raw/`. Nothing in `output/` is
hand-made: change a capture or a line of copy, run the script, upload.

## Remaking the set with new screenshots

1. Take the captures on a phone (portrait). Crop the status bar off the
   top — the script draws its own (9:41, signal, Wi-Fi, battery) and the
   Dynamic Island. Any size works; wider than 1200 px is best. A capture
   with rounded corners is fine.
2. Save them into `raw/` under the names in `SHOTS` (top of
   `make_screenshots.py`):

       01-today.png  02-missal.png  03-prayers.png  04-latin.png  05-library.png
       06-office.png 07-rosary.png  08-stations.png 09-bilingual.png 10-settings.png

   To add a screen, add a row to `SHOTS`: capture file, painting
   (`raphael`, `angelico`, `gentile`), the Latin word for the running
   head, the headline (with its line break), the subhead, the callout
   (x0, y0, x1, y1 as fractions of the capture, `left`/`right`, height on
   the visible phone as 0–1), and whether the trust line shows. A new
   screen can also be a vellum chapter page: add its number to `MIXED`.
3. Run, from the repository root:

       pip install Pillow            # once
       python3 "introibo App Store style/make_screenshots.py"

   `--only apple|play`, `--sizes 6.9,ipad13`, `--shots 1,2,3` render a
   subset. `output/contact-sheet-iphone-6.9.png` shows the whole set at
   once.
4. Upload:

   | Store | Files | Pixels |
   |---|---|---|
   | App Store, iPhone 6.9" | `output/apple/NN-6.9.png` | 1320 × 2868 |
   | App Store, iPhone 6.5" | `output/apple/NN-6.5.png` | 1284 × 2778 |
   | App Store, iPad 13" | `output/apple/NN-ipad13.png` | 2048 × 2732 |
   | Google Play, phone | `output/play/phone-NN.png` | 1080 × 1920 |
   | Google Play, 7" tablet | `output/play/tablet-7in-NN.png` | 1200 × 2134 |
   | Google Play, 10" tablet | `output/play/tablet-10in-NN.png` | 1620 × 2880 |
   | Google Play, feature graphic | `output/play/feature-graphic-1024x500.png` | 1024 × 500 |

   The App Store order is the `SHOTS` order. The listing text lives in
   `store-listing.md`.

The captures committed in `raw/` were recovered from the 1.2.1 renders
(822 px wide) because the originals were not kept; replace them with
captures of the current build when you can, and add screens for the
widgets, the year calendar and Spanish mode.

## The style

Ten pages, two kinds, one system. Both keep a real phone, a big headline,
a painting blurred into the background, and **no counts in the copy**
(never "67 prayers" or "574 propers"), so the set stays true as content
is added.

- **Asymmetric pages** (2, 3, 5, 6, 8, 9): the headline set left, the
  first line in ink and the second in maroon italic (Playfair Display), a
  roman numeral index on a gold hairline, the Latin word of the section in
  tracked capitals, a short subhead in Inter, the phone pushed to one side
  and off two edges, and one callout — a piece of the screen enlarged on a
  white card with a gold hairline — on the open side. Pairs open outward
  (2 left, 3 right; 5 left, 6 right; 8 left, 9 right) so two phones never
  face each other across a gap.
- **Vellum chapter pages** (1, 4, 7, 10): a missal page with a double rule
  in maroon and gold, the running head INTROIBO · n · LATIN WORD, a maroon
  italic drop cap, a gold diamond rule, a Garamond italic subhead, the
  phone centred, the painting showing past the page's edges. The first and
  last carry AD-FREE · OFFLINE · NO ACCOUNT · NO SUBSCRIPTION.
- **Backgrounds:** Raphael's Disputation of the Holy Sacrament, Fra
  Angelico's Annunciation, Gentile da Fabriano's Coronation of the Virgin
  (public domain; `art/CREDITS.md`), cover-fit, blurred, slightly
  desaturated, veiled with cream so the type reads.
- **Colours:** page (247, 241, 229), maroon (104, 18, 26), ink
  (64, 50, 46), gold (196, 158, 92). **Fonts:** Playfair Display
  (variable), Inter, EB Garamond (`fonts/`, OFL).
- American spelling in the copy.

`--style vellum` or `--style asymmetric` renders the whole set in one page
style, for comparison only.
