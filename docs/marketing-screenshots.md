# Marketing Screenshots — Design & Process

This document is the single source of truth for how the App Store marketing
screenshots are made. It exists so the long font/style back-and-forth that
happened for 1.2.1 never repeats. **Read this before touching the design.**

The generator is `scripts/make_marketing.py`. The committed reference set is the
current release folder, `1.2.1 screenshots/` — these match the established house
style and are the design target. When in doubt, open one and compare
side-by-side.

---

## TL;DR — the rules that get forgotten

1. **The title font is Playfair Display *Italic*.** Not upright. Not bold. Not
   Cormorant. It looks cursive-ish and that is correct.
2. **The description font is EB Garamond *Italic*.**
3. There is a **gold divider ornament** (a thin rule broken by a center
   diamond) between the title and the description. It is easy to leave out;
   don't.
4. The device screenshot is **~66.5% of the canvas width** on phones,
   tilted **±3°** (half the set tilt left, half right), with rounded corners
   and a soft drop shadow, and is allowed to clip off the bottom edge.
5. **Every quoted number must be verified against the data** (prayer count,
   propers count, lesson/flashcard counts) — see "Verifying numbers" below.
6. Use **American spelling** in captions ("Customize", not "Customise").
7. The raw capture → caption mapping is **not sequential**. You must open each
   raw image and see what screen it is before assigning a caption.

If feedback ever says the titles look "too cursive" or "should be thicker / not
cursive" — **do not switch to an upright font.** That feedback led us astray
once. The reference (IMG_8471) is unambiguously italic. The fixes that actually
matter are usually the *divider ornament* and the *device width*, not the
typeface.

---

## Canvas & sizes

Apple requires these exact pixel dimensions (portrait):

| Key       | Device class            | Pixels        |
|-----------|-------------------------|---------------|
| `6.5`     | 6.5" iPhone             | 1284 × 2778   |
| `6.9`     | 6.9" iPhone             | 1320 × 2868   |
| `ipad13`  | 13" iPad Pro            | 2048 × 2732   |

Raw in-app captures are 1284 × 2668 (iPhone). They are scaled to fit, not
cropped.

All sizes are produced for every screenshot. Output files are named
`NN-marketing-{6.5,6.9,ipad13}.png` and committed **by size** (one commit per
size group) into the release folder, e.g. `1.2.1 screenshots/`.

---

## The house style (exact spec)

These constants live at the top of `scripts/make_marketing.py`. Keep this table
and the code in sync.

### Color

| Element            | RGB              | Notes                          |
|--------------------|------------------|--------------------------------|
| Background top     | `(181, 51, 49)`  | brighter red                   |
| Background bottom  | `(109, 18, 25)`  | deep maroon                    |
| Gold               | `(214, 178, 110)`| cross, brackets, divider       |
| Title text         | `(247, 242, 232)`| warm white                     |
| Description text   | `(231, 214, 180)`| cream                          |

The background is a smooth **vertical linear gradient** from top color to bottom
color.

### Type

| Role        | Font file                                              | Style  |
|-------------|-------------------------------------------------------|--------|
| Title       | `android/app/src/main/res/font/playfair_display_italic.ttf` | Italic |
| Description | `android/app/src/main/res/font/eb_garamond_italic.ttf`      | Italic |

Sizes are fractions of canvas width:

| Fraction      | phone   | iPad   |
|---------------|---------|--------|
| Title cap     | 0.100   | 0.078  |
| Description   | 0.0335  | 0.026  |

The title carries a tiny stroke (`~1.2%` of title size) so it reads crisply at
thumbnail scale — this is *not* a bold weight, just anti-aliasing insurance.

Titles wrap to ≤ 84% of width; descriptions wrap to ≤ 70% of width, both
centered.

### Ornaments (all gold)

- **Cross** — centered near the very top (`y ≈ 3% of H`): a vertical bar with a
  shorter crossbar at ~32% down. Small.
- **Corner L-brackets** — one in each corner, inset `~3.5%` of width, arm length
  `~5%` of width.
- **Divider** — between title and description: a horizontal rule split in the
  middle by a small filled **diamond**. Half-width ≈ 10% of canvas width.

### The device shot

- Width: **66.5%** of canvas width on phones, **40%** on iPad.
- **Rounded corners**, radius ≈ 5.8% of the shot width.
- **Drop shadow**: a dark copy, offset slightly, Gaussian-blurred (~30px).
- **Tilt**: ±3°. The shadow is rotated with the shot.
- Positioned centered horizontally, below the description, and **allowed to run
  off the bottom edge** (intentional clip — gives the "device peeking up" look).

### Vertical layout (top → bottom)

1. Cross (`~3%`)
2. Title block (starts `~8%`)
3. small gap, **divider**, small gap
4. Description block
5. gap, then the tilted device shot (clipped at the bottom)

---

## The tilt convention

Every shot uses the **same tilt magnitude (3°)**. The sign alternates so the set
reads as a rhythm: odd-numbered shots lean one way, even the other (`-3°` then
`+3°`, …). In the `SHOTS` table this is `-TILT_DEG` / `TILT_DEG`.

---

## Mapping raw captures to captions

**The export order from the phone is not the feature order.** For 1.2.1, for
example, `IMG_8470` was *Regina Caeli*, not Settings, and `8467`/`8468` were
swapped relative to Stations/Rosary. Always open each raw image first and
identify the screen before editing the `SHOTS` table.

The current `SHOTS` table (n → file → title → description → tilt) is the
authoritative caption list and lives at the bottom of
`scripts/make_marketing.py`.

---

## Verifying numbers (mandatory)

Captions quote counts. These **must** match the shipped data, because the data
changes between releases. Re-check every release:

- **Prayer count** — the number of entries in `prayers.json`:
  ```sh
  python3 -c "import json; print(len(json.load(open('Introibo/Resources/prayers.json'))))"
  ```
  For 1.2.1 this is **67** (the caption says "67 Traditional Prayers").

- **Propers count** — the number of *complete* Mass formularies, i.e. entries
  that have all eight parts (introitus, oratio, lectio, evangelium,
  offertorium, secreta, communio, postcommunio). For 1.2.1 this is **574**.
  Do not quote the raw row count; count complete formularies.

- **Latin lessons / flashcards** — verify against the Latin learning data
  before quoting (1.2.1: "10 lessons, 91 flashcards").

If a number can't be verified, don't put it in a caption.

---

## Spelling & copy

- American English: **Customize**, **Color**, **Center**, etc.
- Keep captions short — they wrap to a couple of lines max.
- Proper liturgical terms keep their casing (Propers, Ordinary, Office, Rosary,
  Stabat Mater, Regina Caeli).

---

## How to regenerate

```sh
pip install Pillow                       # one-time
python3 scripts/make_marketing.py        # writes all sizes into the OUT_DIR
```

`OUT_DIR` and the `SHOTS` table are set near the bottom of the script. For a new
release:

1. Drop the new raw captures in the repo root.
2. **Open each one** and update the `SHOTS` table (file, title, description,
   tilt) — remember the order is not sequential.
3. Update `OUT_DIR` to the new release folder (e.g. `1.3.0 screenshots`).
4. Re-verify every quoted number against the data.
5. Run the script.
6. Eyeball the output against the previous release's set (e.g.
   `1.2.1 screenshots/`).
7. Commit by size.

---

## Past mistakes / gotchas (so we don't repeat them)

- **Wrong font family.** An early pass used Cormorant Garamond italic — close,
  but not the originals' Playfair. The title face is **Playfair Display
  Italic**, full stop.
- **Going upright + heavy.** Acting on "thicker, not cursive" feedback, a pass
  made titles upright with a heavy stroke. That was wrong; some came out too
  thick and inconsistent. The originals are italic. The real defects were the
  missing divider and a too-wide device (70% instead of ~66.5%).
- **Missing divider ornament.** Easy to forget; it's a defining element.
- **Stale numbers.** "501 propers" was quoted before recount; the correct figure
  is 574 complete formularies. Always recount.
- **British spelling.** "Customise" slipped in; must be "Customize".
- **Assuming sequential order.** The raw files do not map to features in
  numeric order. View each.
