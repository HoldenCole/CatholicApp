# Ad Altare Dei — iOS App Planning Document
*Latin Prayer Coach · Full Versioned Roadmap*

---

## Vision

A beautiful, native iOS app that teaches traditional Catholics to pray the Rosary in Ecclesiastical Latin — and eventually the full corpus of traditional Roman prayers. Users read prayers in English, Latin, or phonetic breakdown; hear a reference recording; record their own voice; and compare side-by-side. Progress is tracked prayer by prayer.

**Rite:** Traditional Latin Mass (1962 Missal). All content reflects pre-conciliar practice.
**Luminous Mysteries:** Intentionally excluded. Traditional practice uses only Joyful, Sorrowful, and Glorious.

---

## Tech Stack

| Layer | Choice | Reason |
|---|---|---|
| Language | Swift 5.9+ | Native iOS |
| UI Framework | SwiftUI | Modern, idiomatic iOS |
| Architecture | MVVM | Clean, testable, scalable |
| Persistence | SwiftData | iOS 17+, no boilerplate |
| Audio | AVFoundation | Built-in, full-featured |
| Waveform display | DSWaveformImage (SPM) | Best-in-class for iOS waveforms |
| Minimum iOS | iOS 17.0 | Required for SwiftData |

**Swift Package Dependencies:**
- `https://github.com/dmrschmidt/DSWaveformImage` — waveform rendering

---

## Design Language

**Aesthetic:** Refined liturgical. Illuminated manuscript meets modern iOS. Not kitschy or clipart-Catholic. Every screen should feel like it belongs in a well-designed missal.

**Color Palette:**
| Name | Hex | Usage |
|---|---|---|
| Parchment | `#F5F0E8` | Primary background |
| Ink | `#1C1410` | Primary text |
| Sanctuary Red | `#8B1A1A` | Accent, stressed syllables, CTAs |
| Gold Leaf | `#B8960C` | Secondary accent, icons, dividers |
| Warm White | `#FDFAF4` | Card surfaces |
| Vellum Dark | `#2A2118` | Dark mode background |
| Cream | `#EDE8DC` | Dark mode text |

**Typography:**
| Role | Font | Notes |
|---|---|---|
| Display / Latin text | Palatino | Elegant, classical, ships with iOS |
| Body / English | Georgia | Readable, traditional |
| Phonetic text | Palatino Italic | Syllable dots in Gold Leaf color |
| UI labels | SF Rounded | Friendly, native iOS feel |

**Stressed syllables:** Displayed in Sanctuary Red, slightly heavier weight.
**Syllable separator:** Centered dot · in Gold Leaf.

**Icons:** SF Symbols throughout. Custom rosary bead motif for app icon.

**Dark Mode:** Fully supported. Vellum Dark background, Cream text, accents unchanged.

---

## Tab Bar Structure (all versions)

Three tabs, English labels:

| Tab | Icon (SF Symbol) | Label |
|---|---|---|
| 1 | `sun.horizon` | Today |
| 2 | `book.pages` | Prayers |
| 3 | `chart.bar` | Progress |

---

## Data Models

### `Prayer.swift`
```swift
@Model
class Prayer {
    var id: UUID
    var slug: String               // "ave_maria" — used for audio filename lookup
    var latinName: String          // "Ave Maria"
    var englishName: String        // "Hail Mary"
    var latinText: String          // Full Latin text
    var phoneticText: String       // "A·ve Ma·RÍ·a, GRÁ·ti·a PLÉ·na"
    var englishText: String        // English translation
    var audioFileName: String      // "ave_maria_ref.m4a"
    var sortOrder: Int
    var category: PrayerCategory   // .rosary | .litany | .mass | .devotional
}

enum PrayerCategory: String, Codable {
    case rosary, litany, mass, devotional
}
```

### `PhoneticSegment.swift` (value type — not persisted, parsed at runtime)
```swift
struct PhoneticWord: Identifiable {
    var id = UUID()
    var syllables: [PhoneticSyllable]
}

struct PhoneticSyllable {
    var text: String
    var isStressed: Bool
}
```
*Phonetic strings are stored as plain text with · separators and uppercase for stress.
Parsed into PhoneticWord arrays by a helper at render time — no extra storage needed.*

### `Mystery.swift`
```swift
@Model
class Mystery {
    var id: UUID
    var sortOrder: Int
    var setType: MysterySetType        // .joyful | .sorrowful | .glorious
    var latinSetName: String           // "Mysteria Gaudiosa"
    var englishSetName: String         // "Joyful Mysteries"
    var latinTitle: String             // "Annuntiatio"
    var englishTitle: String           // "The Annunciation"
    var mysteryNumber: Int             // 1-5 within the set
    var scriptureRef: String           // "Lk 1:26-38"
    var meditationText: String         // Short English meditation
}

enum MysterySetType: String, Codable {
    case joyful, sorrowful, glorious
}
```

### `PracticeSession.swift`
```swift
@Model
class PracticeSession {
    var id: UUID
    var prayerId: UUID
    var date: Date
    var recordingFileName: String?     // nil until v1.4
    var comfortRating: ComfortLevel
    var durationSeconds: Double?
}

enum ComfortLevel: Int, Codable, CaseIterable {
    case notStarted = 0
    case learning = 1
    case familiar = 2
    case mastered = 3

    var label: String {
        switch self {
        case .notStarted: return "Not Started"
        case .learning:   return "Learning"
        case .familiar:   return "Familiar"
        case .mastered:   return "Mastered"
        }
    }
}
```

### `AppSettings.swift` (UserDefaults-backed, not SwiftData)
```swift
class AppSettings: ObservableObject {
    @AppStorage("defaultTextMode") var defaultTextMode: TextMode = .english
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding = false
    @AppStorage("currentStreak") var currentStreak = 0
    @AppStorage("lastPracticeDate") var lastPracticeDate = ""
}

enum TextMode: String, CaseIterable {
    case english, latin, phonetic
}
```

---

## Rosary Prayers (v1 content)

| # | Slug | Latin Name | English Name | Used In |
|---|---|---|---|---|
| 1 | `signum_crucis` | Signum Crucis | Sign of the Cross | Opening |
| 2 | `credo` | Symbolum Apostolorum | Apostles' Creed | Opening |
| 3 | `pater_noster` | Pater Noster | Our Father | Each decade |
| 4 | `ave_maria` | Ave Maria | Hail Mary | 10x per decade |
| 5 | `gloria_patri` | Gloria Patri | Glory Be | End of each decade |
| 6 | `fatima_prayer` | O mi Iesu | O My Jesus | End of each decade |
| 7 | `salve_regina` | Salve Regina | Hail Holy Queen | Closing |
| 8 | `sub_tuum` | Sub Tuum Praesidium | We Fly to Thy Patronage | Optional closing |

---

## Mystery Sets (all ship in v1.1)

### Joyful Mysteries — Mysteria Gaudiosa
*Traditional days: Monday, Thursday, Saturdays of Advent*
1. The Annunciation — Annuntiatio (Lk 1:26–38)
2. The Visitation — Visitatio (Lk 1:39–56)
3. The Nativity — Nativitas (Lk 2:1–20)
4. The Presentation — Praesentatio (Lk 2:22–38)
5. Finding in the Temple — Inventio in Templo (Lk 2:41–52)

### Sorrowful Mysteries — Mysteria Dolorosa
*Traditional days: Tuesday, Friday, daily in Lent*
1. Agony in the Garden — Agonia in Horto (Lk 22:39–46)
2. Scourging at the Pillar — Flagellatio (Mk 15:6–15)
3. Crowning with Thorns — Coronatio Spinis (Mk 15:16–20)
4. Carrying of the Cross — Bajulatio Crucis (Lk 23:26–32)
5. The Crucifixion — Crucifixio (Lk 23:33–46)

### Glorious Mysteries — Mysteria Gloriosa
*Traditional days: Wednesday, Sunday, Saturdays outside Advent/Lent*
1. The Resurrection — Resurrectio (Mk 16:1–8)
2. The Ascension — Ascensio (Lk 24:50–53)
3. Descent of the Holy Ghost — Descensus Spiritus Sancti (Acts 2:1–13)
4. Assumption of Our Lady — Assumptio (Rev 12:1)
5. Coronation of Our Lady — Coronatio (Rev 12:1)

---

## Traditional Mystery–Day Assignment

| Day | Mystery Set |
|---|---|
| Sunday | Glorious |
| Monday | Joyful |
| Tuesday | Sorrowful |
| Wednesday | Glorious |
| Thursday | Joyful |
| Friday | Sorrowful |
| Saturday | Joyful (note: some traditional sources assign Glorious — app shows both with brief note) |

---

## Ecclesiastical Latin Pronunciation Rules
*(Reference for content authoring — not displayed to user directly)*

| Rule | Classical | Ecclesiastical |
|---|---|---|
| `ae` | "eye" | "ay" (as in they) |
| `c` before e/i/ae/oe | "k" | "ch" (as in church) |
| `g` before e/i | hard "g" | soft "j" (as in gentle) |
| `v` | "w" | "v" |
| `ti` before vowel | "ti" | "tsee" |
| `gn` | "gn" | "ny" (as in canyon) |
| Double consonants | single | both pronounced |

---

## Full File & Folder Structure

```
AdAltareDei/
├── AdAltareDeiApp.swift
├── ContentView.swift                  ← Root TabView (Today | Prayers | Progress)
│
├── Models/
│   ├── Prayer.swift
│   ├── Mystery.swift
│   ├── PracticeSession.swift
│   ├── PhoneticSegment.swift          ← Value types, no persistence
│   └── SampleData.swift
│
├── ViewModels/
│   ├── TodayViewModel.swift
│   ├── PrayerLibraryViewModel.swift
│   ├── PrayerDetailViewModel.swift
│   ├── PracticeViewModel.swift
│   └── ProgressViewModel.swift
│
├── Views/
│   ├── Today/
│   │   ├── TodayView.swift
│   │   ├── MysteryCardView.swift
│   │   └── MysteryDetailView.swift
│   ├── Prayers/
│   │   ├── PrayerLibraryView.swift
│   │   ├── PrayerDetailView.swift
│   │   ├── PhoneticTextView.swift
│   │   └── TextModeToggle.swift
│   ├── Practice/
│   │   ├── PracticeView.swift
│   │   ├── WaveformCompareView.swift
│   │   └── ComfortRatingView.swift
│   ├── Progress/
│   │   ├── ProgressView.swift
│   │   ├── MasteryRingView.swift
│   │   ├── PrayerMasteryRowView.swift
│   │   └── StreakView.swift
│   └── Shared/
│       ├── AudioPlayerView.swift
│       ├── SectionHeaderView.swift
│       └── LoadingView.swift
│
├── Services/
│   ├── AudioRecorderService.swift     ← v1.4
│   ├── AudioPlayerService.swift       ← v1.3
│   ├── PhoneticParser.swift           ← v1.2
│   └── MysteryScheduleService.swift   ← v1.1
│
├── Resources/
│   ├── Audio/
│   │   ├── ave_maria_ref.m4a
│   │   ├── pater_noster_ref.m4a
│   │   ├── gloria_patri_ref.m4a
│   │   ├── credo_ref.m4a
│   │   ├── signum_crucis_ref.m4a
│   │   ├── salve_regina_ref.m4a
│   │   ├── fatima_prayer_ref.m4a
│   │   └── sub_tuum_ref.m4a
│   └── Data/
│       ├── prayers.json
│       └── mysteries.json
│
└── Supporting/
    ├── Extensions/
    │   ├── Color+Theme.swift
    │   ├── Font+Theme.swift
    │   └── Date+Liturgical.swift
    ├── AppSettings.swift
    └── Constants.swift
```

---

---

# VERSION ROADMAP

---

## v1.0 — Shell & Design System
**Goal:** A beautiful, navigable app with placeholder content. The design foundation every future version inherits. Nothing functional yet — this version is about getting the look and feel exactly right.

**Ships:**
- Xcode project, DSWaveformImage SPM package added
- Full folder structure scaffolded
- `Color+Theme.swift` — full palette as Color extensions
- `Font+Theme.swift` — Palatino, Georgia, SF Rounded scale
- `ContentView.swift` — TabView with Today / Prayers / Progress tabs
- Polished stub views for all 3 tabs (not blank — styled placeholders)
- Dark mode confirmed working throughout
- `SampleData.swift` with one prayer stub (Ave Maria, English only) for Xcode previews

**Does NOT ship:** Real content, navigation below tabs, data models, audio anything.

**Definition of done:** Open the app, see three gorgeous placeholder tabs, toggle dark mode — it looks like a real polished app.

**Claude Code kickoff prompt:**
```
Create a new SwiftUI iOS 17 Xcode project called AdAltareDei.

1. Scaffold the full folder structure from the plan (Views, ViewModels, Models, Services, Resources, Supporting).
2. Add DSWaveformImage via SPM: https://github.com/dmrschmidt/DSWaveformImage
3. Color+Theme.swift — Color extensions:
   .parchment = #F5F0E8, .ink = #1C1410, .sanctuaryRed = #8B1A1A,
   .goldLeaf = #B8960C, .warmWhite = #FDFAF4, .vellumDark = #2A2118, .cream = #EDE8DC
4. Font+Theme.swift — typography scale: Palatino (display/Latin), Georgia (body), SF Rounded (UI labels).
5. ContentView.swift — TabView with three tabs: Today (sun.horizon), Prayers (book.pages), Progress (chart.bar).
6. Stub views for TodayView, PrayerLibraryView, ProgressView — each showing a styled heading, placeholder subtext, correct background color. Polished, not blank.
7. Dark mode tested in all views.
8. SampleData.swift — plain struct Prayer (not SwiftData yet) for preview use.

Do not add SwiftData, navigation below tabs, or any audio. Focus entirely on visual polish of the shell.
```

---

## v1.1 — Rosary in English
**Goal:** A fully usable English Rosary guide. All prayers and mysteries in English, today's mystery logic, prayer detail screens, and a simple progress tracker. Fully usable on its own.

**Ships:**
- SwiftData models: `Prayer`, `Mystery`, `PracticeSession`, `AppSettings`
- `prayers.json` — all 8 prayers, English text (Latin/phonetic fields = empty string)
- `mysteries.json` — all 15 mysteries (3 sets × 5), English titles, scripture refs, meditation text
- `MysteryScheduleService` — returns today's mystery set by weekday
- `TodayView` — today's mystery set, 5 mysteries listed with scripture refs, "Begin Practice" CTA
- `MysteryDetailView` — English meditation text per mystery
- `PrayerLibraryView` — scrollable list of all 8 prayers by English name
- `PrayerDetailView` — full English text, clean readable layout
- `ProgressView` — all 8 prayers with ComfortLevel badge, manually settable
- `StreakView` — days-practiced counter
- Saturday note: shows Joyful and Glorious as traditional options with brief explanation

**Does NOT ship:** Latin/phonetic text, any audio, recording, text mode toggle.

**Definition of done:** A Catholic unfamiliar with the Rosary could learn all prayers in English and follow today's mysteries.

**Claude Code kickoff prompt:**
```
Building on the AdAltareDei v1.0 shell, implement v1.1: full English Rosary content and navigation.

1. Add SwiftData models: Prayer, Mystery, PracticeSession per the plan. AppSettings as @AppStorage.
2. prayers.json: all 8 Rosary prayers with English text. latinText and phoneticText = empty string.
3. mysteries.json: all 15 mysteries across Joyful, Sorrowful, Glorious sets — English titles, scripture refs, 2-3 sentence meditation text.
4. MysteryScheduleService: takes today's weekday, returns MysterySetType. Saturday returns both Joyful and Glorious with a note.
5. TodayView: today's date, today's mystery set name, 5 mysteries with scripture refs, "Begin Practice" button.
6. PrayerLibraryView: list of all 8 prayers, tapping navigates to PrayerDetailView.
7. PrayerDetailView: full English prayer text in Georgia font, parchment background, gold dividers.
8. ProgressView: all 8 prayers with ComfortLevel badge (color-coded). Tapping opens a sheet to update rating.
9. StreakView embedded in ProgressView.

All navigation uses NavigationStack. Maintain visual polish from v1.0 throughout.
```

---

## v1.2 — Latin & Phonetics Layer
**Goal:** Add Latin and phonetic text to every prayer. Introduce the three-mode segmented control. First version delivering the core value proposition.

**Ships:**
- `prayers.json` updated — all 8 prayers with `latinText` and `phoneticText` populated
- `PhoneticParser.swift` — parses `"A·ve MA·RI·a"` → `[PhoneticWord]` arrays
- `PhoneticTextView.swift` — renders syllables with · separators; stressed syllables in Sanctuary Red + semibold
- `TextModeToggle.swift` — segmented control: English | Latin | Phonetic (reusable component)
- `PrayerDetailView` updated — integrates toggle, swaps text view per mode
- `AppSettings` — `defaultTextMode` preference persisted
- Settings sheet (gear icon in Progress toolbar) — set default text mode
- Mystery names shown in Latin as primary throughout app
- Latin day names in TodayView header (e.g. "Feria Secunda · Monday")
- `Date+Liturgical.swift` — Latin feria name helper

**Phonetic string format:**
```
Uppercase syllable = stressed. · = syllable break. Space = word break.
Example: "SÍG·num CRÚ·cis" / "A·ve Ma·RÍ·a, GRÁ·ti·a PLÉ·na"
```

**Does NOT ship:** Any audio.

**Definition of done:** Every prayer readable in English, Latin, or phonetic. Stressed syllables visually distinct. Toggle is smooth and instant.

**Claude Code kickoff prompt:**
```
Building on AdAltareDei v1.1, implement v1.2: Latin text and phonetic breakdown.

1. Update prayers.json — add latinText and phoneticText for all 8 prayers. Ecclesiastical Latin phonetics. Format: uppercase syllable = stressed, · = syllable break.
2. PhoneticParser.swift: parse phonetic strings into [[PhoneticSyllable]]. PhoneticSyllable has text: String, isStressed: Bool. Uppercase = isStressed true, then lowercase display text.
3. PhoneticTextView.swift: wrapping layout of syllable Text views. Stressed: .sanctuaryRed, .semibold. Separator dots: .goldLeaf. Normal word spacing.
4. TextModeToggle.swift: Picker segmented style, options: "English", "Latin", "Phonetic". Binds to PrayerDetailViewModel.textMode.
5. Update PrayerDetailView: TextModeToggle at top. Swap text view based on mode: English (Georgia), Latin (Palatino), Phonetic (PhoneticTextView).
6. Date+Liturgical.swift: weekday integer → Latin feria name.
7. TodayView header: show Latin feria name alongside English day.
8. Mystery set names: Latin as primary, English as subtitle.
9. Settings sheet (gear in Progress toolbar): toggle for default text mode stored in @AppStorage.
```

---

## v1.3 — Audio: Reference Recordings
**Goal:** Bundled reference recordings for all 8 prayers. Users hear correct Ecclesiastical Latin. Waveform display introduced.

**Ships:**
- 8 `.m4a` reference recordings bundled in `Resources/Audio/`
- `AudioPlayerService.swift` — loads bundled audio, play/pause/seek, publishes playback state
- `AudioPlayerView.swift` — DSWaveformImage waveform (Gold Leaf tint), play/pause button, time scrubber
- `PrayerDetailView` updated — audio player shown below text when in Latin or Phonetic mode
- Graceful handling if audio file is missing ("Recording coming soon" placeholder)
- Audio stops on navigate away (`.onDisappear`)
- `MasteryRingView.swift` — overall completion ring added to ProgressView

**Audio sourcing options (choose before building):**
- Record a priest or schola singer (ideal)
- Commission via Fiverr Latin voice actor
- Librivox public domain recordings (verify license)
- ElevenLabs TTS as dev placeholder

**Does NOT ship:** User recording, waveform comparison.

**Definition of done:** Tap play on any prayer and hear clear Ecclesiastical Latin. Waveform animates during playback.

**Claude Code kickoff prompt:**
```
Building on AdAltareDei v1.2, implement v1.3: reference audio playback.

1. AudioPlayerService.swift: AVFoundation AVAudioPlayer. Loads audio from app bundle by filename. Publishes isPlaying: Bool, currentTime: Double, duration: Double. Methods: play(), pause(), seek(to:).
2. AudioPlayerView.swift: DSWaveformImageView renders waveform from audio file URL. Play/pause button (play.fill / pause.fill) in sanctuaryRed. Time label. Waveform tinted goldLeaf.
3. Update PrayerDetailView: show AudioPlayerView below text when textMode is .latin or .phonetic. Hide in English mode.
4. Missing audio: show "Recording coming soon" placeholder gracefully, no crash.
5. MasteryRingView.swift: circular progress ring — % of prayers at .familiar or .mastered. Add to top of ProgressView.
6. Stop audio playback on .onDisappear in PrayerDetailView.

Audio files added manually to Resources/Audio/ — wire playback to Prayer.audioFileName.
```

---

## v1.4 — Audio: Record & Compare
**Goal:** The full coaching loop. Record yourself, compare waveforms, rate comfort, save session. The version that makes the app genuinely transformative.

**Ships:**
- `NSMicrophoneUsageDescription` in Info.plist
- Microphone permission request flow with context
- `AudioRecorderService.swift` — AVFoundation recording to Documents directory
- `PracticeView.swift`:
  - Reference waveform (Gold Leaf, top half)
  - Large Record button center (red ring when recording)
  - User waveform below after first recording (steel blue tint)
  - "Play Both" — plays reference then user recording sequentially
  - `ComfortRatingView` — 4 pill buttons
  - Save → writes `PracticeSession` to SwiftData
- `WaveformCompareView.swift` — stacked waveforms with styled divider + "Your Recording" label
- "Practice This Prayer" button in `PrayerDetailView` navigates to `PracticeView`
- `ProgressView` updated — tapping session row replays user's recording
- Streak logic finalized in `AppSettings`

**Definition of done:** Record yourself, see your waveform vs reference, rate yourself, save it, view history in Progress.

**Claude Code kickoff prompt:**
```
Building on AdAltareDei v1.3, implement v1.4: voice recording and comparison.

1. Add NSMicrophoneUsageDescription to Info.plist: "Ad Altare Dei records your voice so you can compare your Latin pronunciation to the reference recording."
2. AudioRecorderService.swift: AVAudioRecorder. requestPermission() async -> Bool. startRecording(). stopRecording() -> URL. Save to Documents/recordings/{prayerId}/{date}.m4a.
3. PracticeView.swift:
   - Top: reference AudioPlayerView (goldLeaf waveform)
   - Center: large circular Record button, sanctuaryRed when recording (mic.fill / stop.fill)
   - Bottom: user waveform after first recording (steel blue tint)
   - "Play Both" button: plays reference then user recording sequentially
   - ComfortRatingView: 4 pill buttons (Not Started / Learning / Familiar / Mastered)
   - Save: writes PracticeSession to SwiftData
4. WaveformCompareView.swift: VStack — reference waveform (top, goldLeaf), divider with "Your Recording" label, user waveform (bottom, blue).
5. Add "Practice This Prayer" button to PrayerDetailView → navigates to PracticeView.
6. ProgressView: tapping a PracticeSession shows a sheet replaying the user's saved recording.
7. Streak logic: on save, check lastPracticeDate — if yesterday, increment streak; if today, no change; if older, reset to 1.
```

---

## v1.5 — Expanded Prayer Library
**Goal:** Move beyond the Rosary. Same coaching mechanic, much more content.

**New prayers:**
| Category | Prayers |
|---|---|
| Litanies | Litany of Loreto, Litany of the Sacred Heart, Litany of St. Joseph |
| Mass Prayers | Confiteor, Suscipiat, Domine non sum dignus |
| Devotional | Angelus, Regina Caeli, Memorare, Act of Contrition |
| Marian Antiphons | Alma Redemptoris Mater, Ave Regina Caelorum (Salve Regina already in Rosary set) |

**Ships:**
- PrayerCategory enum used for grouping in library
- PrayerLibraryView — grouped by category with collapsible sections
- Search bar in Prayers tab
- All new prayers with English, Latin, phonetic, and reference audio
- Optional: one-sentence historical/contextual note per prayer

**Definition of done:** A user can find, read, and practice any major traditional Latin prayer — not just the Rosary.

---

## Privacy & Permissions

| Permission | Added in | String |
|---|---|---|
| Microphone | v1.4 | "Ad Altare Dei records your voice so you can compare your Latin pronunciation to the reference recording." |

**Data policy:** No network calls. No analytics. No accounts. No ads. All recordings stored locally. All data stays on device.

---

## Pre-Build Content Checklist

**Before v1.1:**
- [ ] English text of all 8 prayers (public domain)
- [ ] English text of all 15 mysteries with scripture refs
- [ ] 2–3 sentence meditation text for each mystery

**Before v1.2:**
- [ ] Latin text of all 8 prayers (1962 Missale Romanum — public domain)
- [ ] Phonetic breakdown of all 8 prayers (Ecclesiastical Latin, manually authored)
- [ ] English translations (traditional — Douay-Rheims era equivalents)

**Before v1.3:**
- [ ] 8 reference audio recordings (.m4a, clear, Ecclesiastical Latin)

**Before App Store:**
- [ ] App icon (1024×1024, rosary/cross motif, illuminated manuscript aesthetic)
- [ ] 3–5 App Store screenshots
- [ ] Privacy policy URL (required by Apple for mic-access apps)
- [ ] App Store description

---

## Future Modules (Post v1.x)

| Version | Module | Description |
|---|---|---|
| v2.0 | TLM Rubrics Guide | Interactive animated breakdown of every gesture/posture at Mass |
| v2.1 | Schola Trainer | Gregorian chant square notation sight-reading for propers |
| v3.0 | Ordo Generator | Daily Mass ordo: rank, color, commemorations, feria/feast logic |
| v3.1 | Benedictional | Traditional blessings from the Rituale Romanum |

---

*Gloria Patri, et Filio, et Spiritui Sancto.*
