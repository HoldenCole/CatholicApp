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
- Mass propers — **tranche-based import from DO's own Espanol tree**
  (`scripts/import_spanish_propers.py` reading a local
  divinum-officium clone; MIT-licensed like the English data we already
  ship). Tranches 1–6: **530 formularies / 3,397 fields — the ENTIRE
  temporal cycle** (every Sunday, feria, vigil, Ember day, and the whole
  Triduum: the Chrism Mass, Maundy Thursday, Good Friday with the
  Improperia and its rubric-note fields, and the Easter Vigil, plus the
  1955 "t"/"r" variants) **and 348 of 488 sanctoral feasts** — every
  first-class day and everything within reach of the commune. Four
  mechanisms compose: (1) DO's Espanol day files (antiphons and
  orations), (2) our tier-2 supplements (`propers_supplements_es.json`,
  57 formularies / 334 fields translated from the Latin — all of
  Eastertide, the Triduum, and single missing orations), (3) a commune
  line table (`propers_commune_es.json`, 336 Latin-line → Spanish-line
  pairs) the importer composes per-field, so the antiphons and orations
  the sanctoral shares (Os justi, Státuit, Salve sancta parens, the
  Requiem texts…) are translated once and fan out, and (4)
  name-parameterized templates (`propers_templates_es.json`, 53
  templates + a declined-Latin → Spanish name map) for the commune
  orations each feast instantiates with its saint's name (Gregem tuum,
  the abbot/doctor/virgin-martyr collects…) — an unmapped name refuses
  to compose, no guessing. Identical Latin always gets identical
  Spanish (a same-Latin propagation pass, run to a fixpoint, also fills
  the 1955 variants and resumed Sundays from their base formularies;
  matching is NFC-normalized because the source data mixes accent
  encodings). The per-formulary completeness gate still applies: a day
  is fully Spanish or stays fully English (graduale exempt), so the 64
  sanctoral days whose propers are still untranslated (each needs 3+
  unique fields — its own introit/gradual/offertory set) fall back
  automatically; they are the next tranche.
  The tranche-5 sweep also fixed a doubled "Amén. Amén." on every
  DO-derived conclusion (the Espanol formulas already end in Amén).
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
