# Spanish Translation — Staging

Spanish content for the app. **The tier-1 tranche (prayers, Marian
antiphons, hour metadata) is now WIRED INTO BOTH APPS**: Settings → Sermo
Vulgáris offers English/Español, and `ContentStore.applyVernacular` overlays
the `*_es.json` files at load (English fallback wherever a field is absent).
`scripts/sync_spanish_assets.py` copies this folder's content files into
both asset directories — edit HERE, then sync; the Android suite
(`SpanishOverlayQA`) fails if the copies drift or misalign.
`ui_strings_es.json` is WIRED: `ContentStore.uiString(key, en)` resolves
UI chrome on both platforms (English literal fallback per call site), and
the iOS widget extension — which cannot see the in-app setting — reads a
chrome map the app writes to the App Group on every snapshot refresh.
The invariant throughout: only the ENGLISH half of a dual
"Latin · English" label passes through the lookup; every Latin label
(tab names, section headers' Latin halves, hour names, "Oratio",
"Psalmus Hodiernus"…) is a literal in code and identical in every
vernacular.

## Method (three tiers)

1. **Canonical received texts — never re-translated.** Fixed prayers use the
   traditional Spanish wordings every Spanish-speaking Catholic knows (Padre
   Nuestro, Ave María, Gloria, Salve, Credo, Ángelus, Acto de Contrición,
   Alma de Cristo, Acordaos, Bajo tu amparo…). Translating the English fresh
   would read wrong to native speakers.
2. **Translated from English, checked against the Latin** — explanatory prose,
   rubrics, notes, UI strings, hour introductions. The Latin is consulted
   wherever a doctrinal term could drift (e.g. "unigénitus" → "unigénito",
   never "único hijo").
3. **Approved liturgical sources (phase 2)** — Scripture readings and Mass/
   Office propers should come from a traditional Spanish hand-missal
   lineage, not machine translation. This corpus is ~15 MB of JSON and is
   NOT in this tranche; see "Phase 2" below.

## File schema

Each `*_es.json` mirrors its source file by **slug + index alignment** — no
copies of the Latin/English, only the Spanish additions:

```json
// prayers_es.json — keyed by prayers.json slug
{ "ave": { "title_es": "Ave María", "note_es": null,
           "lines_es": ["Dios te salve, María…", "…"] } }
```

`lines_es[i]` corresponds to `lines[i]` of the same slug in the source file.
`scripts/validate_spanish.py` (repo root `scripts/`) enforces: every slug
exists in the source, every source slug is covered, and line counts match —
so integration cannot silently misalign.

## Contents of this tranche

| File | Source | Status |
|---|---|---|
| `prayers_es.json` | `prayers.json` (67 prayers, 694 lines) | complete |
| `marian_antiphons_es.json` | `marian_antiphons.json` (4) | complete |
| `hours_es.json` | `hours.json` metadata (names, times, intros) | complete |
| `ui_strings_es.json` | curated app UI strings | complete |

## Phase 2 (in progress — large corpora)

- `missal.json` Ordinary — **COMPLETE: all 47 sections** in
  `missal_es.json` (Prayers at the Foot of the Altar through the Leonine
  Prayers, all 17 prefaces, the Canon, both Last Gospels), plus the
  proper Communicantes/Hanc igitur in `canon_variants_es.json`; the 1962
  St Joseph clause inserts into the Spanish text at render time, anchored
  on ": y también de tus bienaventurados Apóstoles" (the validator pins
  the anchor). The overlay remains partial-capable for any future
  sections.
- `ordo_names_en.json` (1,184 feast names) — **DONE, 100% coverage**:
  `scripts/translate_ordo_names_es.py` generates `ordo_names_es.json`
  from the normalized English table (pattern rules for the temporal
  cycle, octaves, Embers, Rogations, dates; a 250-entry saint-name table
  with San/Santa/Santo/Santiago prefix handling; whole-name overrides
  for the specials). At runtime the Spanish map merges over the English
  one, so any future uncovered key falls back to English, then Latin.
  Regenerate after ordo changes, then sync.
- Mass propers — **tranche-based import from DO's own Espanol tree has
  begun** (`scripts/import_spanish_propers.py` reading a local
  divinum-officium clone; MIT-licensed like the English data we already
  ship). Tranches 1–4: 132 formularies — Advent through Holy Wednesday (Advent, the Christmas cycle, Epiphany weeks 1–2, Septuagesima, all of Lent, Palm Sunday through Spy Wednesday), ALL of Eastertide — the Easter octave, the Sundays after Easter, the Rogation and Patronage-of-St-Joseph Masses, Ascension and its octave, the vigil and octave of Pentecost — as tier-2 supplements of our own (163 distinct texts translated from the Latin, deduplicated so identical Latin gets identical Spanish; DO's Espanol Eastertide is name-only stubs), Pentecost with its Ember Friday, and every Sunday after Pentecost including Trinity and Corpus Christi (green ferias inherit their Sunday's formulary at render time, so they follow automatically),
  antiphons and orations only (plus four tier-2 supplements of our own for single fields DO's Espanol omits, e.g. the Septuagesima secreta), with a per-formulary completeness gate (a
  day is fully Spanish or stays fully English; DO's Espanol gaps, e.g.
  Epiphany weeks 3–6 and Easter Sunday, fall back automatically).
  **Scripture ([Lectio]/[Evangelium]) is deliberately excluded**: DO's
  Spanish readings are in a modern register of uncertain provenance —
  they wait for a public-domain source decision (Torres Amat, 1825).
  The DO Espanol PSALTER has the same provenance question; audit before
  importing the Office texts.
- Office propers / readings (multi-MB) — DO Espanol coverage is ~94% for
  the horas tree; same register/provenance audit applies before import.
- `reference.json`, `saints.json`, `stations.json`, tutorial/course content.

## Integration (done for tier 1)

- `VernacularLanguage` (en/es) setting on both platforms, orthogonal to
  `LanguageMode` (Latin/Vernacular/Both); the language-mode labels name the
  chosen vernacular ("Latin & Español").
- `ContentStore.applyVernacular` reloads the pristine sources and overlays
  the `_es` files (English fallback per-field), rebuilds the office
  assembler (Compline's Marian antiphon), and drops the search-index and
  link-graph caches so they rebuild on the new text.
- Android applies the saved setting in `IntroiboApp.onCreate` (widgets
  included); a change in Settings re-keys the compose tree. iOS applies it
  in `ContentStore.init` and on the Settings toggle (`@Observable` handles
  the rest).
- CI: `SpanishOverlayQA` mirrors `scripts/validate_spanish.py` (slug +
  line-count alignment, staging↔assets byte identity) and pins the
  overlay/restore behavior.
