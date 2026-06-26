# Google Play Screenshots — Capture & Generate

This is the Android counterpart to `docs/marketing-screenshots.md`.

> The Play screenshots must show the **Android** app — not the iPhone set —
> because the Material 3 UI looks meaningfully different from SwiftUI. The
> Apple captures cannot be reused.

## Current state (1.2.1)

The committed `google-play-screenshots/{phone,tablet-7in,tablet-10in}-NN.png`
**are genuine Android emulator captures** (verify: the bottom nav shows the
Material 3 pill indicator and `Icons.Filled.*` icons that the iOS build does
not render). They were wrapped by an older generator that used a drop-shadow
title style.

Their caption text was stale and has been corrected **in place** by
`scripts/fix_play_captions.py` (501→574 Propers, 40→67 Prayers, 91→97
flashcards, Customise→Customize) — only the text was repainted; the device
shots are untouched. So the current set is ready to upload as-is for 1.2.1.

## Regenerating from scratch (future releases)

When the Android UI changes enough that the device shots are stale, capture
fresh screens and re-wrap them with `scripts/make_play_marketing.py`, which
reproduces the **canonical flat-title** App Store house style (no drop
shadow) at the Play canvas sizes. (A full regen therefore drops the old
drop-shadow look in favour of the canonical one — an intentional improvement,
matching the Apple set.)

---

## Canvas sizes

| Slot          | Pixels        | Where it shows on Play                       |
|---------------|---------------|----------------------------------------------|
| `phone-NN`    | 1080 × 1920   | All phones                                   |
| `tablet-7in`  | 1200 × 2134   | 7-inch tablets (only used if you opt in)     |
| `tablet-10in` | 1620 × 2880   | 10-inch tablets (only used if you opt in)    |

Play requires at least 2 phone screenshots; tablet sets are optional but
recommended for visibility on tablet listings.

---

## Capture procedure (Android Studio emulator)

1. Open the project in Android Studio (`File → Open` the `android/` folder).
2. Create or pick a phone emulator that is **1080×1920** (Pixel 5/6 with
   density set to 420dpi works), and a tablet emulator if doing tablet sets.
3. Run the **debug** build on the emulator.
4. Walk through the 10 slots below, navigating to the screen and state
   described, then capture the screen.

   - In Android Studio: **View → Tool Windows → Logcat → Screenshot** (the
     camera icon), or the camera button on the emulator's side toolbar.
   - The capture must be a clean full-screen 1080×1920 PNG (no extra
     emulator chrome — use the camera icon, not OS screenshot).
   - Save each capture into the **repo root** with the exact filenames
     in the table.

5. From the repo root, run:
   ```sh
   PYTHONPATH=scripts python3 scripts/make_play_marketing.py
   ```
6. Inspect the output in `google-play-screenshots/`. Re-capture and re-run
   any slots that need adjustment — the script overwrites in place.
7. Commit the new Play assets.

---

## The 10 slots — what to capture

The slot numbers, titles, and descriptions mirror the App Store SHOTS table.
Each capture is wrapped with the same caption on the Play side; only the
device shot changes.

| Slot | Filename                       | App tab / screen                             | State to capture                                                                                                  |
|-----:|--------------------------------|----------------------------------------------|-------------------------------------------------------------------------------------------------------------------|
| 01   | `android-01-today.png`         | **Hodie** (Today tab)                        | The default Today screen scrolled to the top, showing the feast header, Today's Propers card, and Daily Psalm.    |
| 02   | `android-02-missal.png`        | **Missa** (Missal tab)                       | Today's interleaved Mass, scrolled so a Proper section (red left border) is visible — e.g. Introit or Collect.    |
| 03   | `android-03-prayers.png`       | **Oratio** (Prayers tab)                     | The Prayers landing screen, scrolled to show the prayer-rule progress card and several occasion categories.       |
| 04   | `android-04-learn.png`         | **Schola** (Learn tab)                       | The Learn landing screen with the mastery progress ring and lesson list visible.                                  |
| 05   | `android-05-reference.png`     | **Liber** (Reference tab)                    | Reference landing, scrolled to show the four sections (References / Propers / History / Glossary) and some links. |
| 06   | `android-06-office.png`        | **Hodie → Office** (clock dial)              | The Divine Office clock dial showing the 8 hours, with the current hour glowing.                                  |
| 07   | `android-07-rosary.png`        | **Hodie → Rosary card → Begin**              | The Rosary flow with a decade in progress — mystery title visible at top, beads at the bottom.                    |
| 08   | `android-08-stations.png`      | **Hodie → Stations**                         | The winding pilgrimage path landing screen with all 14 stations visible.                                          |
| 09   | `android-09-regina.png`        | **Oratio → Regina Caeli detail**             | Regina Caeli prayer sheet open in side-by-side Latin/English mode.                                                |
| 10   | `android-10-settings.png`      | **Hodie → ⚙ Settings**                       | Settings screen showing rite picker, penance discipline, language mode, and theme picker.                         |

> Capture each screen **once**; the same PNG is fed into all three canvas
> sizes (phone, tablet-7in, tablet-10in) — the generator resizes it to fit.

### Setup gotchas

- For slot 09 (Regina Caeli) — language mode must be **Side-by-side** in
  Settings, otherwise the caption "Every prayer in Latin and English
  side-by-side" won't match what's shown.
- For slot 02 (Missal) — capture during a day where Propers actually appear
  (most days); ferial green days work fine. Easter, Christmas, and big feasts
  also work well.
- For slot 07 (Rosary) — get a frame mid-decade so the bead progress dots
  show, not the opening / closing prayers.

---

## Caption rules (same as Apple set)

The captions are baked into `scripts/make_play_marketing.py`'s `SHOTS`
table and are already verified for 1.2.1 against the shipped data:

- **574 daily Propers** (slot 02) — complete Mass formularies, all 8 parts
- **67 Traditional Prayers** (slot 03)
- **97 flashcards** (slot 04) — verify with
  `python3 -c "import json; print(sum(len(s['items']) for c in json.load(open('Introibo/Resources/courses.json')) for s in c['sections'] if s['type']=='cards'))"`
- **14 stations** (slot 08)
- **8 canonical hours** (slot 06)

Re-verify every number on each release. If any caption changes, update both
this file and `make_play_marketing.py`'s `SHOTS` table, and re-render.

American spelling everywhere: **Customize**, not "Customise".

---

## The feature graphic

The 1024 × 500 feature graphic is rendered separately by
`scripts/make_play_feature_graphic.py` (icon + title + subtitle + count
lines, no device shot). It does not need raw captures. Re-run after each
release if any of the numbers change.

---

## Past mistakes (Play)

- **Stale numbers**: the original committed Play assets quoted *501
  Propers*, *40 Prayers*, *91 flashcards* — none of which match the
  shipped data (574 / 67 / 97). The Apple SHOTS table was kept current
  but the Play side never was. Verify every release.
- **British spelling**: the original Play title #10 said *Customise* —
  must be *Customize*.
- **Drop shadow on titles**: an older Play generator (now removed) added
  a dark drop shadow to titles. The house style is **flat ivory** —
  matches the Apple set exactly.
- **Reusing iOS captures**: tempting but wrong. The Material 3 components
  look noticeably different from SwiftUI; Play screenshots must show the
  actual Android UI.
