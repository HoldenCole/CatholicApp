# Spanish Translation — Staging

Spanish content for the app. **The tier-1 tranche (prayers, Marian
antiphons, hour metadata) is now WIRED INTO BOTH APPS**: Settings → Sermo
Vulgáris offers English/Español, and `ContentStore.applyVernacular` overlays
the `*_es.json` files at load (English fallback wherever a field is absent).
`scripts/sync_spanish_assets.py` copies this folder's content files into
both asset directories — edit HERE, then sync; the Android suite
(`SpanishOverlayQA`) fails if the copies drift or misalign.
`ui_strings_es.json` remains staged: the UI chrome is hardcoded English on
both platforms and localizing it is its own pass.

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

## Phase 2 (not started — large corpora)

- `missal.json` Ordinary sections (90 KB) — tier 2/3 mix.
- `ordo_names_en.json` (1,184 feast names) — mostly pattern-translatable by
  script ("Dominica II Post Pentecosten" → "II Domingo después de
  Pentecostés") plus a saint-name table.
- Office propers / Mass propers / readings (multi-MB) — needs an approved
  Spanish source; do not machine-translate.
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
