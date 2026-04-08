# Ad Altare Dei — Project Context & Handoff

> **Purpose of this file:** A single source of truth for the Ad Altare Dei project so a new chat session can pick up without re-explaining everything. Keep this updated as decisions are made.

---

## 1. Vision

**Ad Altare Dei** ("To the Altar of God") is a native iOS app for **traditional Catholics** to pray the Rosary and other prayers in **Ecclesiastical Latin**, attend the Traditional Latin Mass (TLM), pray the Divine Office, and follow practices of the saints.

### Target user
Traditional Catholics (1962 Missal, pre-Vatican II spirituality) who want a solemn, scholarly, no-gimmick prayer companion. Think ICKSP / FSSP / SSPX faithful and trad-curious Novus Ordo Catholics.

### Tone
**Solemn, traditional, modern, fluid, seamless, professional.** Not cartoony (Hallow). Not Protestant-devotional. Not gamified. More like a hand-bound missal than an app.

### Guiding principles
- **Free forever.** No accounts, no analytics, no ads, no tracking, no paywalls.
- **All data local.** UserDefaults + bundled JSON. No server.
- **1962 Missal is the default.** Also support 1955 and pre-1955 rubrics.
- **Latin first, English second.** Side-by-side, always. Latin is primary.
- **NO Luminous Mysteries.** Intentionally excluded — they're a 2002 addition, not in the traditional 15-decade Rosary.
- **No fake engagement.** No streaks that shame, no notifications that nag, no dark patterns.

---

## 2. Tech Stack

| Layer | Choice |
|---|---|
| Language | Swift 5.9+ |
| UI | SwiftUI |
| Persistence | SwiftData (`@Model`) + UserDefaults for settings |
| Architecture | MVVM |
| Min deployment | iOS 17.0 |
| Project gen | XcodeGen (`project.yml`) — user has no Mac, so we rely on CI |
| CI | GitHub Actions, macOS runner, iPhone 15 simulator |
| Content | Bundled JSON decoded via Decodable DTOs |
| Settings | `@AppStorage` wrapped in `AppSettings: ObservableObject` |

### Why these choices
- **No Mac on user's side** → all builds run through GitHub Actions. User cannot run the app locally. We validated compile via CI and validate UX via **web prototypes** in `/prototype/`.
- **SwiftData over CoreData** → cleaner `@Model` syntax, sufficient for local-only.
- **Bundled JSON over network** → offline-first, no server costs, matches "free forever" promise.

---

## 3. Content Scope

### Prayers (`Resources/Data/prayers.json`)
37 prayers, Latin + English + phonetic guides, grouped:
- **Rosarium** — Signum Crucis, Pater Noster, Ave Maria, Gloria Patri, Salve Regina, Credo, Fatima Prayer, etc.
- **Missa** — Confiteor, Gloria in Excelsis, Sanctus, Agnus Dei, Kyrie, Credo, Domine non sum dignus, etc.
- **Devotiones** — Memorare, Actus Contritionis, Anima Christi, Tantum Ergo, Prayer to St. Michael, etc.

### Rosary (`mysteries.json`)
**15 mysteries only:** Joyful, Sorrowful, Glorious. **NO Luminous.** This is a hard rule.

### Mass Ordinary (`mass_ordinary.json`)
13 sections of the TLM Ordinary with posture tags (Stand/Kneel/Sit). Covers Asperges, Prayers at Foot of Altar, Kyrie, Gloria, Collect, Epistle, Gospel, Credo, Offertory, Canon, Pater Noster, Agnus Dei, Communion, Last Gospel.

### Divine Office (`divine_office_*.json`)
8 hours: Matins, Lauds, Prime, Terce, Sext, None, Vespers, Compline. Sample psalms + hymns in Latin.

### Saints — "Practices of the Saints" feature (`saint_*.json`)
7 saint profiles, each with: biography, charism, feast day, era, daily practices (Morning/Day/Evening), penances, quotes, related prayers.

1. **Padre Pio** — Patient suffering, offering up
2. **Thérèse of Lisieux** — The Little Way
3. **Thomas Aquinas** — Scholarly prayer, Adoration
4. **Benedict of Nursia** — Ora et Labora, monastic rule
5. **Teresa of Ávila** — Interior Castle, mental prayer
6. **Josemaría Escrivá** — Sanctifying ordinary work
7. **Francis de Sales** — Devout life in the world

### Reference (`reference_*.json`)
7 categories, 37 entries total: Calendar, Devotions, Latin, Mass, Penance, Prayers, Sacramentals.

### Guides
- `examination_of_conscience.json` — By commandment
- `confession_guide.json` — Step-by-step
- `tlm_guide.json` — How to attend the Latin Mass
- `stations_of_the_cross.json` — 14 stations

### Learn / Courses (`lessons.json` + `course_*.json`)
10 lessons, split into pronunciation / grammar / prayers / reading:
1. Ecclesiastical Vowels
2. Consonant Rules
3. Stress & Accent
4. First & Second Declensions
5. Verb Basics
6. 50 Common Prayer Words
7. Master the Ave Maria (course)
8. Master the Pater Noster (course)
9. Reading Latin Psalms
10. Reading the Vulgate

> **Note:** `mass_server_responses` and `congregation_responses` lessons were **removed** — navigation was broken, no course content existed. Don't re-add without backing content.

---

## 4. Repo Structure

```
CatholicApp/
├── AdAltareDei/                    # The Swift iOS app
│   ├── AdAltareDeiApp.swift        # Entry point, wires dark mode
│   ├── ContentView.swift           # Tab root
│   ├── Models/                     # @Model SwiftData + DTOs
│   ├── ViewModels/                 # MVVM view models
│   ├── Views/
│   │   ├── Today/                  # Today tab
│   │   ├── Missal/                 # Mass Ordinary
│   │   ├── Prayers/                # Prayer library + detail
│   │   ├── Rosary/                 # Guided Rosary
│   │   ├── Saints/                 # Practices of the Saints
│   │   ├── Office/                 # Divine Office
│   │   ├── Learn/                  # Courses
│   │   ├── Reference/              # Reference categories
│   │   ├── Guides/                 # Examination, Confession, TLM, Stations
│   │   ├── Practice/               # AI practice (future)
│   │   ├── Progress/               # Prayer mastery (renamed from ProgressView)
│   │   └── Shared/                 # SettingsSheet, dividers, etc.
│   ├── Services/                   # Content loaders
│   ├── Supporting/                 # AppSettings, enums, Color+Palette
│   ├── Resources/
│   │   └── Data/                   # 43 JSON files (see §3)
│   └── Assets.xcassets
├── prototype/                      # Web prototypes (HTML mockups)
│   ├── index.html
│   ├── today.html
│   ├── missal.html
│   ├── prayers.html
│   ├── saints.html
│   └── rosary.html
├── UI/
│   ├── DESIGN_REFERENCE.md
│   └── Final/                      # 14 finalized HTML mockups
├── .github/workflows/              # iOS CI
├── project.yml                     # XcodeGen config
├── AdAltareDei_Plan.md              # Original planning doc
└── PROJECT_CONTEXT.md              # ← you are here
```

---

## 5. Design Language

### Palette
| Token | Hex | Use |
|---|---|---|
| Parchment | `#F2EBE0` (moving to `#F2E8D0`) | Page background, warm vellum |
| Ink | `#1C1410` | Primary text, warm black |
| Sepia | `#7A6A58` | Secondary text |
| Sanctuary Red | `#8B1A1A` | **Primary accent** — section labels, rubrics, active state, cross marks |
| Gold Leaf | `#B8960C` | **Ornaments ONLY** — dividers, glyphs, hairlines. NOT for borders/fills/chrome |
| Muted Green | `#2E7D32` | Devotional accent bar |
| Mastered | `#2E7D32` variant | Course completion |

### Typography
| Face | Role |
|---|---|
| **Playfair Display** (web) / **Palatino** (iOS) | Display, prayer names, headings |
| **Cormorant Garamond** italic | Latin subtitles, section labels, swash accents |
| **EB Garamond** | English translation body |
| **Georgia** | Fallback body, UI labels |
| SF Pro | iOS system chrome only |

### Rules (the non-negotiables)
1. **Latin is primary.** English is always secondary, smaller, lighter.
2. **Two-column layout** for bilingual prayer text — Latin left, English right, aligned to shared baseline.
3. **NO cards-on-cards.** Flowing parchment sections separated by ornamental dividers, not bordered boxes.
4. **Red rubrics** — `℟.` and `℣.` marks in sanctuary red for Response/Versicle lines.
5. **Ornamental dividers**, not plain rules. Gold crosses (✠), fleurs, pilcrows (¶), Maltese crosses.
6. **Drop caps** on prayer first letters (Ave → ornamental **A**).
7. **Italic small caps** for section labels ("RO​SA​RI​UM"), tracked wide.
8. **Gold as ornament, never chrome.** If you use gold on a border or a pill, you're doing it wrong.
9. **No emoji in the UI.** Use real glyphs: ✠ ☉ ℟ ✦ 𝕭 — not 📖 🎓 ⚙.
10. **Hairline frame** — thin double-rule gold border at ~10px inset, like a printed missal page.

### Dark mode
NOT pure OLED black. **Deep walnut** `#1A130C` background with **antique ivory** `#E8DFC9` text. Should feel candlelit, not techy.

### Component vocabulary
- **Section label:** `ROSARIUM` in red italic small caps, tracked 3px, with Latin subtitle *Rosary* in sepia italic below.
- **Prayer row:** colored accent bar (3px wide × 36px tall) — red=Rosary, gold=Mass, green=Devotional — + name in Palatino + English subtitle in Georgia.
- **Ornamental divider:** gradient hairline with centered ✠ or · or ✟ glyph.
- **Page end mark:** `✿ · ✿` centered, gold, tracked wide, ~30% opacity.
- **Tab bar:** minimal, text glyphs not emoji, active tab in sanctuary red.

---

## 6. What's Been Built (Swift side)

### Core infrastructure
- `AdAltareDeiApp.swift` — entry, `.preferredColorScheme` wired to `appSettings.darkModeEnabled`
- `Supporting/AppSettings.swift` — `ObservableObject` with `@AppStorage` for:
  - `defaultTextMode: TextMode` (latin / english / sideBySide / missal)
  - `missalRite: MissalRite` (1962 / 1955 / pre1955)
  - `penanceDiscipline: PenanceDiscipline` (modern1962 / traditional1917 / strict)
  - `darkModeEnabled: Bool`
  - `completedCourses: Set<String>` — JSON-serialized set
  - `recordPractice()` for streak tracking (non-shaming)
  - `penancesForToday()` dynamic by day-of-week
- `Supporting/Color+Palette.swift` — parchment / ink / sanctuaryRed / goldLeaf / comfortMastered

### Views implemented
- **Today tab** — feria header, missal badge, dynamic penance, devotions list, Rosary launcher, Practices of the Saints, More section (Stations, Confession, Examination, TLM, Readings)
- **Missal** — Mass Ordinary sections with posture, Latin/English side-by-side, dark header
- **Prayers** — library with color-coded rows, detail view with side-by-side text, "Practice This Prayer" CTA
- **Rosary** — guided flow with mystery selector, bead animation, Latin/English per step, completion screen
- **Saints** — SaintProfileView + daily practice view with checkboxes, live progress bar, daily quote (persisted via UserDefaults keyed by date+saint)
- **Office** — Divine Office hour views
- **Learn** — courses + lesson views
- **Reference** — category + entry views
- **Guides** — Examination, Confession, TLM, Stations
- **ProgressTabView** — prayer mastery (renamed from `ProgressView` to avoid SwiftUI collision)
- **SettingsSheet** — missal rite picker, text mode, dark mode toggle, about

### Build/CI
- GitHub Actions workflow targeting iPhone 15 simulator on `macos-14` runner
- Dynamic Xcode detection (was hardcoded to 15.4, fixed)
- XcodeGen `project.yml` at repo root

### Web prototypes (`/prototype/`)
Five interactive HTML files reviewed by user:
1. `today.html` — Today dashboard
2. `missal.html` — Mass Ordinary
3. `prayers.html` — Prayer library (with Ave Maria detail overlay)
4. `saints.html` — Padre Pio daily practices demo
5. `rosary.html` — Three-screen guided Rosary (start → pray → complete)

Plus `UI/Final/` has 14 finalized HTML mockups from the earlier design exploration phase.

---

## 7. Decision History (what the user has said)

### Liked / decided
- **Liked** the overall aesthetic direction — parchment, Playfair, Cormorant Garamond, gold + sanctuary red
- **Liked** the color-coded prayer bars (red/gold/green)
- **Liked** side-by-side Latin/English
- **Liked** the Practices of the Saints feature concept
- **Liked** the daily penance widget
- **Liked** selectable missal rite (1962 / 1955 / pre-1955) and penance discipline
- **Loved** the interactive web prototypes — called the last batch "the best yet"
- **Decided:** Penance goes at the **top** of Today, right after the date
- **Decided:** **No Angelus** as a separate tracked devotion
- **Decided:** Missal selector must be **tappable** at the top of the page
- **Decided:** Mysteries should **NOT** appear on the Today home screen — only the Rosary launcher

### Disliked / rejected
- **Rejected** cartoony/Hallow-style illustrations
- **Rejected** "B" option in early A/B tests — "A and C looked too similar"
- **Rejected** mockups that looked "designed by Figma in one day"
- **Rejected** "too simplistic" tile layouts
- **Rejected** gamification / streaks that shame
- **Rejected** Luminous Mysteries (hard exclusion)
- **Rejected** paywalls, accounts, analytics
- **Rejected** `mass_server_responses` and `congregation_responses` lessons (broken navigation, no content)
- **Just rejected (most recent):** overlap with a competing Catholic app — see §8

### Outstanding philosophical position
User wants the app to feel like a **traditional altar missal, not a modern app**. Solemn. Scholarly. Something a priest or serious lay Catholic would respect. Think Baronius Press / Angelus Press printing quality, not Duolingo.

---

## 8. Competing App Analysis (the redesign trigger)

User uploaded 6 screenshots (`download*.png` on `main` branch) of a competing Catholic app with uncomfortably similar layout. User's exact words:

> "These are screenshots from another Catholic app. Very similar and even the layout is similar. Want to make sure the one we're working on doesn't look too similar. Want mine to look more traditional, solemn while modern, fluid, seamless, and professional."

### What the competitor does (visual signature)
1. **Pure OLED black** background
2. **Electric saturated yellow** accent for badges, pills, CTAs, borders
3. **Card-on-card layering** — rounded rectangles inside rounded rectangles
4. **Launcher-style icon grid** for Quick Access
5. **Bold sans-serif** typography throughout
6. **Yellow-bordered pills** for tags ("Traditional", "Sunday Cycle", "Best Known")
7. **Progress tiles** (Bible in a Year with year pill)

### Where we overlapped (fixes needed)
| Ours | Problem |
|---|---|
| `.badge` gold-bordered pills ("1962 Missal ▾") in `today.html` | Identical shape to competitor's yellow pills |
| `.rosary-box` bordered card with gold gradient in `today.html` | Card-on-card layering |
| Gold `#B8960C` used for chrome | Same role as their yellow |
| Rounded search field in `prayers.html` | Looks app-y, not missal-y |
| Emoji tab bar icons | Too modern/playful |

### Differentiation pass (to be applied to all 5 prototypes)
**Kill:**
- Gold-bordered pill badges → replace with inline italic small-caps text
- Card containers around rosary box → flowing section with ornament
- Search field → remove or quiet italic "Quærere…" hairline
- Dark-on-dark gradient headers → warm parchment with illuminated capital

**Add:**
- Red rubrics (`℟.` `℣.`) in sanctuary red
- Drop caps on prayer first letters
- Ornamental initials with Maltese crosses (✠) inline
- Marginal paragraph numbers (tiny right-margin numerals)
- Two-column Latin/English with shared baseline grid
- Hairline double-rule gold page frame at ~10px inset
- Subtle paper grain texture on parchment (not flat color)
- Real glyphs in tab bar, not emoji

**Palette discipline:**
- Warm parchment further: `#F2EBE0` → `#F2E8D0`
- **Gold demoted to ornaments ONLY**
- **Sanctuary red becomes primary accent**
- Dark mode = deep walnut + antique ivory, NOT OLED black

---

## 9. Current State (as of last session)

### Just completed
- **Differentiation pass applied to ALL 5 web prototypes** — distinguished from the competing Catholic app (see §8). Each one now uses the unified design language:
  - Dark walnut header (`#1A130C → #2C2015` gradient) with double-rule gold inner frame and gold-letterpress title
  - Warm parchment body (`#F2E8D0`) with subtle radial-dot paper grain
  - Fixed double-rule gold page frame (10px inset)
  - Sanctuary red as primary accent; gold demoted to ornaments only
  - Real glyph tab bar with Latin labels: Hodie / Missa / Oratio / Schola / Liber
  - Drop caps (italic red Playfair) on prayer first letters
  - Red `℟.` `℣.` rubric marks in prayer text
  - Ornamental chapter-break dividers between major sections

- **today.html** — illuminated `P` drop cap on Rosary section, no badges/cards, ornamental dividers between sections
- **missal.html** — sticky horizontal **Mass progress path** (interactive scrollable nodes for the 11 main parts), marginal Roman numerals (i–xiii), italic posture labels in margin, three **illuminated moments** with radial gold glow + bordered rules for *Et Incarnátus*, *Hoc est enim Corpus meum*, *Et Verbum caro factum est*, "Ite, Missa est" end mark
- **prayers.html** — **Featured Oratio Hodierna** at top with large illuminated `A` drop cap, three illuminated chapters (Rosárium / Missa / Devotiónes), index-style entries with leader-dot gold separators, redesigned Ave Maria detail overlay with dark walnut header + drop cap + rubric marks
- **saints.html** — saint entries are illuminated initials (no cards), redesigned daily practice overlay with **rosary-bead progress** (8 small beads + center cross that light up red as practices complete), gold-cross checkmark (✠) inside red square instead of green check
- **rosary.html** — Start screen has illuminated J/S/G mystery initials; **Pray screen is fully dark walnut** (candlelit church ambience) with visible **animated rosary chaplet** (current bead pulses gold), large italic Latin step name, illuminated mystery-moment panels at each new decade, italic small-caps "Sequens / Finis" nav button; Complete screen has parchment Deo Grátias mark

### Pending
- Build remaining web prototypes: **Learn**, **Reference**, possibly standalone screens for **Stations**, **Examination of Conscience**, **Confession Guide**
- Propagate the new design language back into the Swift views once the user approves the updated prototypes
- User-specific per-screen feedback round on the 5 finalized prototypes
- (Possibly) build Office hours prototype

### Known gaps / not yet built
- AI practice / voice pronunciation feedback (Practice tab scaffolding exists)
- Real audio recordings for prayers (spec pending — user open to TTS or volunteer recordings)
- Latin/English baseline grid alignment in missal view (current two-column is close but not perfectly aligned)
- Swift views still use old design language — need a migration pass after prototype approval

---

## 10. Important Constraints / Gotchas

### Don't do this
- ❌ Don't add the **Luminous Mysteries**. Ever.
- ❌ Don't add **analytics / tracking / accounts / ads / paywalls**.
- ❌ Don't name a view `ProgressView` — collides with SwiftUI's built-in. Use `ProgressTabView` etc.
- ❌ Don't use SwiftData `#Predicate` with local-array captures — it crashes. Use fetch-all + in-memory filter.
- ❌ Don't hardcode Xcode version paths in CI (was `15.4`, use dynamic detection).
- ❌ Don't pre-compute waveform bar heights inline — causes SwiftUI re-render storms. Store as `@State`.
- ❌ Don't use emoji in the production UI. Real glyphs only.
- ❌ Don't use gold `#B8960C` for chrome (borders, fills, pills). Ornaments only.
- ❌ Don't use pure OLED black for dark mode. Warm walnut.
- ❌ Don't commit screenshots or image assets without explicit placement — keep the repo lean.

### Do this
- ✅ Always two-column Latin/English in prayer views, Latin primary.
- ✅ Persist user state (saint checkboxes, course completion) in UserDefaults keyed by date where relevant.
- ✅ Use the `PenanceDiscipline` enum's `penancesForToday()` — penance is dynamic.
- ✅ Red rubrics, drop caps, ornamental dividers — lean into missal vocabulary.
- ✅ When in doubt, copy the visual conventions of the **Baronius Press 1962 Roman Missal** or the **Liber Usualis**.

---

## 11. Git / Branch Workflow

- **Development branch:** `claude/catholic-app-build-VJGnO` (HoldenCole/CatholicApp)
- **Main branch:** holds the competing-app reference screenshots (`download*.png`)
- Commits should be small and descriptive. Recent style:
  - `Add interactive web prototype: Guided Rosary`
  - `Wire up dark mode toggle`
  - `Fix CI: use macos-14 runner, iPhone 15 simulator`
- Push with `git push -u origin claude/catholic-app-build-VJGnO`
- **Never** push to `main` directly. **Never** open a PR unless the user asks.

---

## 12. How to Resume in a New Chat

If you're a fresh Claude picking this up:

1. **Read this file first.** It's the ground truth.
2. **Skim** `AdAltareDei_Plan.md` (original spec) and `UI/DESIGN_REFERENCE.md` (design tokens).
3. **Open** the 5 prototypes in `/prototype/` in order: today → missal → prayers → saints → rosary.
4. **Check** §9 for where we left off.
5. **Ask the user** what they want to work on next, and confirm before touching Swift files — prototypes are the current truth, Swift catches up after.
6. Remember the user has **no Mac** — you cannot run the iOS app. Validate everything visually in the web prototypes.
7. Work in **small batches** to avoid timeouts on large file operations.

---

*Last updated: current session. Update §9 whenever the in-progress/pending state changes.*
