# Spanish Translation — Staging

Pre-prepared Spanish content for a future release. **Nothing in this folder is
wired into either app build**; it stages cleanly until integration.

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

## Integration plan (when ready)

1. Add `SPANISH` to `LanguageMode` on both platforms (the enum and settings
   UI were built with this in mind; the search index is language-agnostic per
   the v1.2 design).
2. Merge `*_es.json` into the bundled sources (script: join by slug/index) or
   teach the renderers to overlay the `_es` files directly.
3. Fall back to English wherever a `spa` field is absent, so partial coverage
   ships safely.
4. Run `scripts/validate_spanish.py` in CI once integrated.
