# Ad Altare Dei — Prototype Data Schema

> Documents every data object, localStorage key, and shared library
> used across the 10 HTML prototypes. Consult before adding new data.

---

## Shared Libraries

| File | Provides | Used by |
|---|---|---|
| `styles.css` | Fonts, `*` reset, `body::before` paper grain | All 10 HTML files |
| `ui-helpers.js` | `escapeHtml`, `toRoman`, `Overlay.open/close`, `Storage.get/set/getJSON/remove`, ESC key handler | All 10 HTML files |
| `lit-context.js` | `LitContext.get(date)` — liturgical season, feria, marian antiphon, mystery, penance, indulgences | today, missal, rosary, stations, confession, office |
| `office-data.js` | `HOURS`, `HOUR_KEYS`, `MARIAN_ANTIPHONS`, `DAY_OPENING`, `DAY_RESPONSE`, `COLLECT_GENERIC` | office only |

---

## Data Objects (per file)

### saints.html — `SAINTS`

```js
SAINTS = {
  pio: {
    name: "St. Padre Pio",            // Display name
    title: "Mystic, Stigmatist...",    // Subtitle
    quote: "Pray, hope...",            // Daily quote
    sections: [
      {
        lat: "Mane",                   // Latin section heading
        eng: "Morning",               // English section heading
        practices: [
          { t: "Morning Offering",    // Practice title
            d: "Upon waking..."       // Description
          }
        ]
      }
    ]
  }
}
```
**Keys:** `pio`, `therese`, `aquinas`, `benedict`, `teresa`, `escriva`, `desales`

---

### learn.html — `COURSES`

```js
COURSES = {
  vowels: {
    num: 1,                            // Lesson number
    title: "Ecclesiastical Vowels",
    latin: "De Vocalibus...",
    intro: "The pronunciation...",     // Drop-cap opening paragraph
    sections: [
      { type: "lesson", label: "...", html: "..." },
      { type: "tip",    label: "...", html: "..." },
      { type: "cards",  label: "...", note: "...",
        items: [
          { lat: "Dóminus", phon: "DOH-mee-noos", eng: "Lord" }
        ]
      },
      { type: "summary", label: "...", html: "..." }
    ]
  }
}
```
**Keys:** `vowels`, `consonants`, `stress`, `declensions`, `verbs`, `vocab50`, `ave`, `pater`, `psalms`, `vulgate`

---

### prayers.html — `PRAYERS`

```js
PRAYERS = {
  ave: {
    title: "Ave María",               // Latin prayer name
    eng: "The Hail Mary",             // English prayer name
    category: "Rosárium",             // Display category
    note: "...",                       // Optional liturgical note
    lines: [
      { lat: "Ave María...",          // Latin line (may contain <em>, <span>)
        eng: "Hail Mary..."           // English line
      }
    ]
  }
}
```
**Keys:** `signum`, `pater`, `ave`, `gloriaPatri`, `salve`, `credoApost`, `fatima`, `confiteor`, `kyrie`, `gloriaExcelsis`, `sanctus`, `agnus`, `domineNSD`, `morning`, `memorare`, `actusContr`, `anima`, `crucifix`, `tantumErgo`, `michael`, `adoroTe`

---

### reference.html — `REFERENCE`

```js
REFERENCE = {
  "cal-advent": {
    title: "Advent",
    latin: "Adventus Domini",
    cat: "Calendarium",                // Category label
    summary: "...",                    // Required, gets drop cap
    history: "...",                    // Optional
    practice: "...",                   // Optional
    notes: "...",                      // Optional liturgical notes
    scripture: {                       // Optional
      ref: "Isaias 7:14",
      lat: "Ecce virgo...",
      eng: "Behold a virgin..."
    }
  }
}
```
**Keys:** `cal-*` (7), `mass-*` (4), `pray-*` (5), `dev-*` (5), `pen-*` (4), `sac-*` (8), `lat-*` (4) — 37 total

---

### office-data.js — `HOURS`

```js
HOURS = {
  matutinum: {
    name: "Matutínum",
    eng: "Matins",
    time: "at midnight",
    hour: 0, minute: 0,               // 24-hour clock position
    glyph: "M",                        // Dial node label
    order: 1,                          // Roman numeral for Hora I/II/...
    intro: "The night Office...",
    parts: [
      { type: "vr",        label, lat, eng, latR, engR },
      { type: "hymn",      label, title, lat, eng },
      { type: "antiphon",  label, lat, eng },
      { type: "psalm",     label, ref, verses: [{lat, eng}] },
      { type: "capitulum", label, ref, lat, eng },
      { type: "canticle",  label, ref, verses: [{lat, eng}] },
      { type: "pater" },
      { type: "collect",   label, lat, eng },
      { type: "closing",   label, lat, eng },
      { type: "confiteor", label },
      { type: "responsory",label, ref, v1Lat, v1Eng, r1Lat, r1Eng, v2Lat?, v2Eng?, r2Lat?, r2Eng? },
      { type: "marian",    title, eng, season, lat, engBody }
    ]
  }
}
```
**Keys:** `matutinum`, `laudes`, `prima`, `tertia`, `sexta`, `nona`, `vesperae`, `completorium`

---

### office-data.js — `MARIAN_ANTIPHONS`

```js
MARIAN_ANTIPHONS = {
  alma: { title, eng, season, lat, engBody },
  ave:  { ... },
  regina: { ... },
  salve: { ... }
}
```

---

### rosary.html — `MYSTERY_SETS` + `PRAYERS`

```js
MYSTERY_SETS = {
  sorrowful: {
    name: "Mystéria Dolorósa",
    english: "Sorrowful Mysteries",
    mysteries: [
      {
        num: "Mystérium Primum",
        title: "Agonía in Horto",
        eng: "The Agony in the Garden",
        ref: "Lk 22:39–46",
        body: "Jesus falls prostrate...",
        fruit: "Sorrow for sin"
      }
    ]
  }
}
```
**Set keys:** `sorrowful`, `joyful`, `glorious`

Rosary `PRAYERS` holds full Latin+English text for: `signum`, `credo`, `pater`, `ave`, `gloria`, `fatima`, `salve`

---

### stations.html — inline `stations` array

```js
stations = [
  {
    num: "Statio Prima",
    title: "Jesus Is Condemned to Death",
    latin: "Iesus ad mortem condemnatur",
    med: "Consider how...",            // Meditation text
    mood: ""                           // CSS class: mood-death, mood-mother, mood-tomb, or ""
  }
]
```
14 entries, index 0–13.

---

### today.html — `SAINT_INFO` (subset of saints.html's SAINTS)

```js
SAINT_INFO = {
  pio: { name, role, initial, quote }
}
```
7 entries — just the display fields Today needs to render the followed-saint card.

---

## localStorage Keys

All keys use the `aad.*` namespace prefix.

| Key | Type | Written by | Read by | Purpose |
|---|---|---|---|---|
| `aad.saints.followed` | string (slug) | saints.html | today.html, saints.html | Currently followed saint |
| `aad.saints.streak.<slug>` | string (int) | saints.html | today.html, saints.html | Consecutive-day count |
| `aad.saints.streakLast.<slug>` | string (ISO date) | saints.html | saints.html | Last day streak was bumped |
| `aad.rosary.lastDate` | string (ISO date) | rosary.html | today.html | Date of last completed rosary |
| `aad.rosary.lastSet` | string (set key) | rosary.html | today.html | Mystery set last prayed |
| `aad.learn.mastered` | JSON array of slugs | learn.html | today.html, learn.html | Completed lesson slugs |
| `aad.settings.rite` | string (1962/1955/pre1955) | today.html | today.html | Selected missal rite |
| `aad.settings.penance` | string (1962/1917/strict) | today.html | today.html | Selected penance discipline |

---

## Design Tokens (canonical values)

| Token | Value | Notes |
|---|---|---|
| `.h-title` font-size | 30px | All page-level dark-walnut headers |
| Drop cap (major) | 54px | List-level anchors: `.init`, `.featured-cap`, `.dropcap` |
| Drop cap (interior) | 48px | Inside overlay body: `.lead-cap`, `.dropcap` in prose |
| Drop cap underline | 32px | `.init::after`, `.dropcap::after` width |
| Dark header padding | `62px 28px 28px` | `.header`, `.dh`, `.dh-saint`, `.s-head` |
| `.h-rule` margin | `14px 8px 10px` | Below ornamental crossbar in dark headers |
| `main` padding | `0 28px 40px` | Standard (except today which is `56px 28px 110px`) |
| Chapter-break width | 70% | `::before`/`::after` gradient hairline |
| Parchment background | `#F2E8D0` | Warm vellum |
| Ink (primary text) | `#1C1410` | Warm black |
| Sepia (secondary) | `#7A6A58` | Body italic, descriptions |
| Muted secondary | `#9A8670` | Meta text, Latin subtitles |
| Sanctuary Red | `#8B1A1A` | Primary accent |
| Gold Leaf | `#B8960C` | Ornaments ONLY |
| Dark walnut BG | `#1A130C → #2C2015` | Header gradient |

---

*Last updated with round-2 review fixes.*
