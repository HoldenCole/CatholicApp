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
│   ├── today.html              # Today dashboard
│   ├── missal.html             # Mass Ordinary (dark header + progress path)
│   ├── prayers.html            # Prayer library (Liber Orationum)
│   ├── saints.html             # Practices of the Saints (bead progress)
│   ├── rosary.html             # Guided Rosary (candlelit pray screen)
│   ├── reference.html          # Reference Library (expandable chapters)
│   ├── learn.html              # Schola Latina (interactive cards)
│   ├── confession.html         # Two-tier: Basic + St. Catherine
│   └── stations.html           # Via Crucis (14-station guided)
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
**Ten interactive HTML files + one shared library** — all on `claude/catholic-app-build-VJGnO`:

1. `today.html` — Today dashboard (dynamic feria, penance, mystery hint, saint follow, schola progress, rosary badge)
2. `missal.html` — Mass Ordinary with sticky Mass progress path, illuminated moments, dynamic feria header
3. `prayers.html` — Liber Orationum with featured Oratio Hodierna + expandable chapters + 4 detail overlays (Ave, Pater, Anima Christi, Crucifix)
4. `saints.html` — Praxes Sanctorum with all 7 saints' full practices, Follow/Sequor button, Roman-numeral streak, rosary-bead progress
5. `rosary.html` — Sacratissimum Rosarium with **full 80-step flow** for all 3 mystery sets, dark walnut candlelit pray screen, animated bead chaplet, auto-selects today's mystery
6. `reference.html` — Liber Referentiarum with 7 expandable chapters / 37 entries, sample Advent detail
7. `learn.html` — Schola Latina with 10 lessons in 4 chapters, journey dots, interactive practice cards
8. `confession.html` — De Confessione two-tier design: Liber I (Guided, 10 steps + Examination by Commandment) + Liber II (St. Catherine of Siena 5 steps + her 1377 prayer); Lenten Friday plenary indulgence flag
9. `stations.html` — Via Crucis with winding pilgrimage path start + dark walnut guided pray screen with 90px illuminated Roman numerals; Lenten Friday prominence badge
10. `office.html` — **Traditional Roman Breviary (1962)** with 24-hour 8-point octagonal dial (hours at exact 3-hour / 45° intervals starting midnight), time-of-day glow, full seasonal awareness
11. `lit-context.js` — **shared library** (Computus + season detection + Marian antiphons + mystery picker + penance rules); loaded via `<script src>` by today / missal / rosary / stations / confession / office

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

## 9. Current State

The prototype side is **effectively complete**. The web prototypes are the current source of truth for design and interaction. Swift code has not yet been migrated to match.

### The 10 prototypes all share a unified design language
Every screen uses:
- Dark walnut header (`#1A130C → #2C2015` gradient) with double-rule gold inner frame and gold-letterpress title
- Warm parchment body (`#F2E8D0`) with subtle radial-dot paper grain
- Fixed double-rule gold page frame (10px inset)
- Sanctuary red as primary accent; gold demoted to ornaments only
- Real glyph tab bar with Latin labels: Hodie / Missa / Oratio / Schola / Liber
- Drop caps (italic red Playfair) on prayer first letters
- Red `℟.` `℣.` rubric marks
- Ornamental chapter-break dividers between major sections

### What each prototype does now

**today.html** — Dynamic feria header (driven by `lit-context.js`), illuminated `P` drop cap on Rosary section, no badges/cards. Live personalization:
- Saints section transforms into the followed saint's card (initial drop cap + name + quote + streak in Roman numerals) when one is followed, falls back to the "Follow a Saint" CTA otherwise
- Schola progress section with 10 dots mirroring `learn.html`'s journey, showing `III of X · lessons mastered` state
- Rosary "Oratum Hodie" badge appears below the launcher after completing a rosary today
- Rosary sub-line auto-shows today's mystery set + feria name
- Penance section fully dynamic by day + season (Lenten Friday / Lenten weekday / Friday / Advent Wed-Fri-Sat / Sunday / other)
- Plenary indulgence row appears beneath the penance on Lenten Fridays pointing to the Crucifix prayer

**missal.html** — Sticky horizontal **Mass progress path** (interactive scrollable nodes for the 11 main parts), marginal Roman numerals (i–xiii), italic posture labels in margin, three **illuminated moments** with radial gold glow for *Et Incarnátus*, *Hoc est enim Corpus meum*, *Et Verbum caro factum est*, "Ite, Missa est" end mark. Header feria is now dynamic (e.g. *"Feria Sexta · Quadragesima"* in season colour).

**prayers.html** — **Featured Oratio Hodierna** at top with large illuminated drop cap. Three illuminated chapters (Rosárium / Missa / Devotiónes), index-style entries with leader-dot separators, `.preview` style for entries without detail overlays. **Four full detail overlays wired:** Ave Maria, Pater Noster (uses Ave overlay for demo), **Anima Christi** (13-line full bilingual breakdown), and **En Ego, O Bone Iesu — Prayer Before a Crucifix** (with indulgence rubric and Psalm 21:17–18 closing).

**saints.html** — All 7 saints now have **full daily practices** (previously only Padre Pio). Each saint has 7–10 practices organized into Mane / Per Diem / Vésperæ / Pænitentiæ sections, plus a hand-picked signature quote. **Follow/Sequor system**: tap `Sequere ✠ Follow` in any saint's overlay → saint slug persists to localStorage, the selector shows a "Sequor" pill on the followed saint, completing all daily practices bumps a consecutive-day streak. Streak displays in Roman numerals. Rosary-bead progress auto-adjusts to each saint's total count.

**rosary.html** — **Full 80-step flow** for all 3 mystery sets (Joyful, Sorrowful, Glorious), built from a generator (`buildSteps(setKey)`):
- Opening (7 steps): Signum Crucis → Credo Apostolorum → Pater (Holy Father intentions) → 3× Ave (Faith/Hope/Charity) → Gloria Patri
- Each mystery (14 steps): announce → Pater → 10× Ave → Gloria → Fatima Prayer
- Closing (2 steps): Salve Regina → Signum Crucis
- Full Latin + English prayer texts for Signum, Credo, Pater, Ave, Gloria, Fatima, Salve
- Dark walnut candlelit Pray screen with animated rosary chaplet (current bead pulses gold), illuminated mystery-moment panels at each new decade
- Start screen **auto-highlights today's mystery set** based on day-of-week with Sunday seasonal overrides (Advent Sun → Joyful, Lent Sun → Sorrowful), gold "Hodie · Today" badge
- Completion writes `rosaryLastDate` + `rosaryLastSet` to localStorage so today.html picks up the "prayed today" state

**reference.html** — 7 expandable chapters / 37 entries with Advent detail sample. Auto-marks unlinked entries as `.preview` via tiny IIFE.

**learn.html** — Schola Latina with 10 lessons across 4 chapters, journey dots, interactive flip cards in the Vowels detail overlay.

**confession.html** — Two-tier design: **Liber I** (Guided, 10 steps + full Examination of Conscience by the Ten Commandments expandable) and **Liber II** (St. Catherine of Siena's 5-step preparation + her prayer from Rocca d'Orcia, 1377). Lenten Friday plenary indulgence notice appears between the intro and the two paths.

**stations.html** — Winding vertical pilgrimage path on the start screen (14 stations zigzag left/right of a central hairline, ending at a Golgotha cross). Dark walnut pray screen with a **massive 90px illuminated Roman numeral** behind each station, mood-tinted per station (red glow for Crucifixion/Death, warmer gold for Mother/Deposition, deep shadow for Tomb). Lenten Friday prominence badge.

**office.html** — **Traditional 1962 Roman Breviary** (explicitly labelled — see §13). Unique **24-hour octagonal clock dial**: all 8 canonical hours at exact 3-hour / 45° intervals starting at midnight (Matins 00:00, Lauds 03:00, Prime 06:00, Terce 09:00, Sext 12:00, None 15:00, Vespers 18:00, Compline 21:00). Time-of-day glow animation on the current hour. Each hour overlay flows through the full traditional Office structure (V/R → Hymn → Antiphon → Psalm → Capitulum → Canticle where applicable → Pater → Collect → Closing). Full seasonal awareness via `lit-context.js`: the four seasonal Marian antiphons swap into Compline, a season banner shows in the header, the dial tints by liturgical colour, Lent/Passiontide/Advent appends the "Alleluia omitted" note. **Matins has the Te Deum** restored (omitted in Lent/Passiontide) and **Compline has the full traditional structure** — Confiteor, Jer 14:9 capitulum *"Tu autem in nobis es Domine"*, and the *"In manus tuas Domine"* short responsory before Nunc Dimittis (14 parts, canonical order).

### Pending
- **Swift migration** — all 9+ iOS views still use the old design language. Nothing in `/AdAltareDei/` has been touched in this round of prototype work.
- User per-screen feedback round on the finalized prototypes
- Saint of the Day feature (content-heavy — needs a sanctorale / ~250 saint entries)
- Audio (pronunciation + chant)

### Known gaps / not yet built
- AI practice / voice pronunciation feedback (Practice tab scaffolding exists)
- Real audio recordings for prayers (spec pending — user open to TTS or volunteer recordings)
- Latin/English baseline grid alignment in missal view
- Daily Mass Propers (Introit/Collect/Epistle/Gospel/Secret/Communion/Postcommunion) — needs per-feast content
- Swift views still use old design language — migration pending user go-ahead

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
3. **Open all 10 prototypes** in `/prototype/` — they are the current design and content truth:
   today → missal → prayers → saints → rosary → reference → learn → confession → stations → office
4. **Also read** `/prototype/lit-context.js` — it's the shared library every page loads for day/season awareness.
5. **Check** §9 for where we left off and §13 for how the liturgical context system works.
6. **Ask the user** what they want to work on next, and confirm before touching Swift files — prototypes are the current truth, Swift catches up after.
7. Remember the user has **no Mac** — you cannot run the iOS app. Validate everything visually in the web prototypes.
8. Work in **small batches** to avoid timeouts on large file operations.
9. For any date/season/feria/penance/mystery/antiphon/indulgence question, call `LitContext.get(new Date())` — don't inline Computus anywhere.

---

## 13. Liturgical Context System

A shared JavaScript library drives all day- and season-aware behaviour across the prototypes.

### File
`prototype/lit-context.js` — loaded by every page that cares, via `<script src="lit-context.js"></script>` in `<head>`. Sets `window.LitContext`.

### Public API
```js
LitContext.get(date)          // returns rich context object (see below)
LitContext.easterFor(year)    // anonymous Gregorian algorithm
LitContext.formatLongDate(d)  // "the twenty-eighth of March"
LitContext.COLOUR_HEX         // { violet, rose, white, red, green }
```

### Context object shape
```js
{
  season:      'advent' | 'christmas' | 'lent' | 'passion' | 'easter' |
               'pentecost' | 'per_annum',
  colour:      'violet' | 'rose' | 'white' | 'red' | 'green',
  colourHex:   '#6A359A',
  latName:     'Tempus Advéntus',
  engName:     'Advent',
  feriaLat:    'Domínica' | 'Feria Secúnda' | ... | 'Sábbato',
  feriaEng:    'Sunday' | ... | 'Saturday',
  dow:         0-6,
  isSunday:    true/false,
  isFriday:    true/false,
  isLent:      true/false,  // includes Passiontide
  marian:      'alma' | 'ave' | 'regina' | 'salve',
  mystery:     'joyful' | 'sorrowful' | 'glorious',
  mysteryLat:  'Mystéria Dolorósa',
  mysteryEng:  'Sorrowful Mysteries',
  penance: {
    title:   'Lenten Friday' | 'Lenten Fast' | 'Friday Abstinence' |
             'Advent Penance' | 'Day of the Lord' | 'No obligatory penance',
    latin:   'Feria Sexta in Quadragésima',
    desc:    '...',
    rubric:  '℟. Feria Sexta',
    strict:  true/false
  },
  indulgences: {
    crucifix: true  // only on Lenten Fridays — Prayer Before a Crucifix plenary
  },
  easter, ashWed, pentecost, trinity, advent1  // computed Date objects
}
```

### Season boundaries (Computus-derived)
| Season | Start | End | Colour |
|---|---|---|---|
| Tempus Advéntus | Advent I (4th Sun before Christmas) | Dec 24 | violet |
| Tempus Nativitátis | Dec 25 | Feb 1 | white |
| Tempus post Epiphaníam | Feb 2 (Candlemas) | Ash Wed − 1 | green |
| Quadragésima | Ash Wed | Passion Sun − 1 | violet |
| Tempus Passiónis | Passion Sun (Easter − 14) | Holy Sat | violet |
| Tempus Paschále | Easter | Trinity Sat (Easter + 55) | white |
| Pentecóste | Pentecost Sun only (Easter + 49) | — | red |
| Tempus post Pentecósten | Trinity Sun (Easter + 56) | Advent I − 1 | green |

Eastertide intentionally extends through the **Pentecost Octave** (Trinity Saturday) per the 1962 usage — Salve Regina doesn't take over until Trinity Sunday.

### Mystery-by-day-of-week
- Sunday → Glorious (or Joyful in Advent, Sorrowful in Lent/Passion — seasonal override)
- Monday → Joyful
- Tuesday → Sorrowful
- Wednesday → Glorious
- Thursday → Joyful
- Friday → Sorrowful
- Saturday → Glorious

Traditional 1962 schedule, no Luminous.

### Marian antiphon windows (for Compline)
- **Alma Redemptóris Mater** — Advent I through Feb 1 (spans year boundary)
- **Ave Regína Cælórum** — Feb 2 (Candlemas) through Holy Wednesday
- **Regína Cæli** — Easter Vigil through Friday after Pentecost (Trinity Sat inclusive)
- **Salve Regína** — Trinity Sunday through Saturday before Advent I

### Penance rules (1962 norms)
| Condition | Title | Description |
|---|---|---|
| Lenten Friday | Lenten Friday | Abstinence + fast (one meal + two collations) |
| Lenten weekday | Lenten Fast | Fast for those of fasting age (21–59) |
| Friday outside Lent | Friday Abstinence | Abstain from flesh of warm-blooded animals |
| Advent Wed/Fri/Sat | Advent Penance | Voluntary fast reminder |
| Sunday | Day of the Lord | No obligation, rest + Mass |
| Other | No obligatory penance | Voluntary mortifications always meritorious |

### Wired pages
| Page | Uses context for |
|---|---|
| `today.html` | Feria + date + season-coloured header, dynamic penance entry, plenary indulgence row, today's mystery sub-line |
| `missal.html` | Header feria + season name in liturgical colour |
| `rosary.html` | Auto-selects today's mystery set with `Hodie · Today` badge, intro line |
| `stations.html` | Lenten Friday prominence badge |
| `confession.html` | Lenten Friday plenary indulgence notice |
| `office.html` | Season banner, dial tinting, Compline Marian antiphon swap, Lent/Passion/Advent Alleluia note |

### Known edge cases handled
- Year boundary (Advent → Christmastide): Alma uses OR not AND
- Pentecost Octave: Eastertide extends to Trinity Saturday (Pentecost Sunday has its own label)
- Pre-Lent: the Candlemas → Ash Wed gap is labelled "Tempus post Epiphaníam" (not "post Pentecósten")

### Known gaps
- No Septuagesima / Sexagesima / Quinquagesima distinction (merged into post Epiphaníam)
- No specific Ember Days logic (currently merged with "Advent Penance" heuristic)
- No sanctorale (Saint of the Day feature not yet built)
- No feast-of-the-day detection (would override the seasonal label)

---

## 14. Traditional Roman Breviary Audit Trail

The Divine Office prototype was audited against LOTH (Novus Ordo Liturgy of the Hours) to ensure it is the **traditional 1962 Roman Breviary**, not the reformed 1970 LOTH.

### Things explicitly checked
| Check | Result |
|---|---|
| 8 hours including **Prime** (LOTH suppressed Prime) | ✓ All 8 hours present |
| Hymns correctly assigned per hour | ✓ All 8 correct for 1962 |
| Psalms correctly assigned per hour | ✓ Ps 94 Matins invitatory, Ps 62 Lauds, Ps 53 Prime, Ps 118 Terce, Ps 122 Sext, Ps 125 None, Ps 109 Vespers, Ps 30 Compline |
| Canticles use **Vulgate** (not Neo-Vulgate) | ✓ Benedictus / Magnificat / Nunc Dimittis all Vulgate |
| Matins opens with "Dómine, lábia mea apéries" (traditional) | ✓ |
| Compline opens with "Iube, dómne, benedícere" (traditional) | ✓ |
| **Te Deum** at end of Matins (omitted in Lent/Passiontide) | ✓ Present |
| **Confiteor** in Compline | ✓ Present (three-part: Confiteor / Misereatur / Indulgentiam) |
| Jer 14:9 capitulum "Tu autem in nobis es Domine" in Compline | ✓ Present |
| "In manus tuas Domine" short responsory in Compline | ✓ Present (V1/R1/V2/R2) |
| Header does NOT say "Liturgy of the Hours" | ✓ Says "Breviárium Románum · 1962 Roman Breviary" |
| Seasonal Marian antiphons use traditional 1962 windows | ✓ |
| Hour times follow traditional 3-hour cadence | ✓ 00:00, 03:00, 06:00, 09:00, 12:00, 15:00, 18:00, 21:00 |

### Part sequence per hour
**Matins** (9 parts): V/R → Hymn → Antiphon → Psalm → Capitulum → Canticle (Te Deum) → Pater → Collect → Closing

**Lauds** (9 parts): V/R → Hymn → Antiphon → Psalm → Capitulum → Canticle (Benedictus) → Pater → Collect → Closing

**Prime / Terce / Sext / None** (8 parts each): V/R → Hymn → Antiphon → Psalm → Capitulum → Pater → Collect → Closing

**Vespers** (9 parts): V/R → Hymn → Antiphon → Psalm → Capitulum → Canticle (Magnificat) → Pater → Collect → Closing

**Compline** (14 parts, most traditional): Blessing → Short Reading (1 Pet 5:8–9) → Confiteor → Supplication (Converte nos Deus) → Deus in adjutorium → Antiphon → Psalm → Hymn → Capitulum (Jer 14:9) → Responsory (In manus tuas) → Canticle (Nunc Dimittis) → Pater → Collect (Visita quæsumus) → Marian Antiphon (seasonal)

---

*Last updated: end of prototype phase. Update §9 and §13 whenever the in-progress/pending state changes. Update §14 if any Office content is touched.*
