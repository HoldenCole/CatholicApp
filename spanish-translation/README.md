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
  ship). Tranches 1–7: **COMPLETE — 612 formularies / 3,987 fields.
  Every proper field of every day in both cycles carries Spanish**: the
  entire temporal cycle (every Sunday, feria, vigil, Ember day, and the
  whole Triduum: the Chrism Mass, Maundy Thursday, Good Friday with the
  Improperia and its rubric-note fields, and the Easter Vigil, plus the
  1955 "t"/"r" variants), the entire sanctoral cycle (all 488 keys —
  every feast, octave day, vigil, and variant with propers of its own;
  the rest inherit at render time), and the C* commune template
  formularies. No day and no antiphon/oration field falls back to
  English any more. Four mechanisms compose: (1) DO's Espanol day files
  (antiphons and orations), (2) our tier-2 supplements
  (`propers_supplements_es.json`, 57 formularies / 334 fields translated
  from the Latin — all of Eastertide, the Triduum, and single missing
  orations), (3) a commune line table (`propers_commune_es.json`, 754
  Latin-line → Spanish-line pairs) the importer composes per-field, so
  every shared antiphon, gradual verse, and oration (Os justi, Státuit,
  Salve sancta parens, the Requiem texts, the Gaudeamus introits…) is
  translated once and fans out, and (4) name-parameterized templates
  (`propers_templates_es.json`, 53 templates + a declined-Latin →
  Spanish name map) for the commune orations each feast instantiates
  with its saint's name — an unmapped name refuses to compose, no
  guessing. Identical Latin always gets identical Spanish (a same-Latin
  propagation pass, run to a fixpoint plus a final backfill of
  gate-exempt fields, fills the 1955 variants and resumed Sundays from
  their base formularies; matching is NFC-normalized because the source
  data mixes accent encodings, and the alleluia-marker and conclusion
  handling absorbs the source's spelling variants).
  The tranche-5 sweep also fixed a doubled "Amén. Amén." on every
  DO-derived conclusion (the Espanol formulas already end in Amén).
  Scripture ([Lectio]/[Evangelium]) is deliberately excluded from THIS
  importer — it ships separately (next bullet) from a different source.
- Mass Scripture readings — **COMPLETE: 590 days / 1,176 fields in
  `missal_readings_es.json`** (`scripts/import_spanish_readings.py`).
  DO's Spanish readings were REJECTED on provenance grounds (a modern
  copyrighted lectionary register); the text used instead is the
  **public-domain Petisco/Torres Amat Bible (1798/1825), translated from
  the Vulgate** — the classic Spanish hand-missal lineage. The importer
  reads a theWord `.ont` module of the Torres Amat text (kept OUTSIDE
  the repo; getbible's KJV JSON supplies only the versification index to
  address the verse lines) and composes each reading the way a hand
  missal prints it: translated heading ("Lección de la Epístola del
  Apóstol San Pablo a los Romanos"), liturgical incipit ("Hermanos:",
  "En aquel tiempo:"…), then the verse text of the entry's ref, with
  seam smoothing (leading connectives and redundant time-phrases
  dropped after the incipit) and the module's spacing artifacts
  normalized. Refs are recovered for ref-less entries by matching their
  Latin to a ref-bearing twin, plus a hand-checked fix table; Vulgate/KJV
  versification shifts are mapped where the missal touches them. The
  deuterocanonical pericopes (Wisdom, Sirach, Tobit, Judith, Maccabees,
  Daniel 13–14…, absent from the 66-book module) are our own tier-2
  translations from the Vulgate in `readings_deutero_es.json` — 28
  pericopes keyed by ref, covering every deutero reading in the missal.
  Every lectio/evangelium field carries Spanish except 4 by design: the
  Easter Vigil's Exsultet-plus-prophecies blocks (quad6-6/quad6-6r),
  the pre-1955 Palm Sunday entry embedding the Munda cor (quad6-0r),
  and the Vigil of the Assumption's cross-reference stub (08-14) — all
  structured texts, not plain pericopes.
  The DO Espanol PSALTER has the same provenance question as its
  readings; audit before importing the Office texts.
- **The Divine Office (in progress — tranche O1: the Psalter).** The
  provenance audit CONFIRMED the suspicion: DO's Espanol psalter is a
  mix — some psalms are the public-domain Torres Amat hand-lined into
  liturgical verses, but many others (Ps 22, Ps 50, Ps 109, the modern
  Benedictus…) were pasted VERBATIM from the modern copyrighted Spanish
  liturgical psalter, translated from the Hebrew. Those can never ship.
  `scripts/import_spanish_psalter.py` therefore accepts a DO psalm only
  when its lines demonstrably ARE Torres Amat (mean per-line word
  overlap ≥ 0.85 against the TA verse), and composes everything else
  directly from the Torres Amat module: an anchored monotone alignment
  maps each Latin line's Vulgate ref to its KJV-versified module verse
  (title sentences trimmed by cognate evidence, Vulgate verse splits
  absorbed), verse text is split across lines at punctuation nearest
  the Latin's proportions, and the flex (†) and mediant (*) marks are
  mirrored from the Latin. Output: `psalter_es.json` — **COMPLETE,
  202/202 entries, 3,269 lines** — plus `psalter_weekly_es.json`
  (2,258/2,258 verses fanned out by identical-Latin-line matching).
  `psalter_supplements_es.json` carries the hand-translated remainder:
  the deuterocanonical canticles (both Daniel 3 canticles, Tobit,
  Judith, Sirach, Wisdom — tier 2 from the Vulgate), the Athanasian
  Creed, and the three Gospel canticles (Benedictus, Magnificat, Nunc
  dimittis) in their received Spanish wordings rather than
  back-composed prose.
  **Tranche O2 — the ordinary of the hours: COMPLETE
  (`hours_parts_es.json`, 271 parts / 1,246 fields — every English
  field of every hour template).** `scripts/import_spanish_hours.py`
  builds a Latin↔Spanish pair table from DO's whole horas tree (1,308
  paired files; 21k line pairs incl. the *-split responsory segments;
  163 traditional verse hymn translations) and fans the psalter bank
  into the psalm/canticle verses (piece-window keys absorb the hours'
  different verse groupings). `hours_supplements_es.json` covers what
  DO hides behind macros or lacks: the received Te Deum, the Matins
  blessings and sample lessons (Genesis from Torres Amat, the patristic
  and homily snippets tier-2), the Deus-in-adjutorium responses, the
  Prime/Compline formulas, and the Office-of-the-Dead invitatory and
  collect. CAUTION for the readings tranche: DO Espanol Tempora
  scripture is ALSO mixed — Adv1-0's Isaiah is verbatim Torres Amat but
  Quadp1-0's Genesis is a modern copyrighted register, so lessons must
  be audited per-pericope or composed from the TA module.
  **Tranche O3 — the commons of the saints: COMPLETE
  (`commune_office_es.json`, 1,340 parts / 2,425 fields — every English
  field of every C* commune template plus the BVM Saturday Office).**
  The same importer emits it from the pair table: antiphons,
  capitula, orations, versicles, and hymns match DO Espanol's
  traditional-register lines; Matins psalms fan in from the Torres
  Amat psalter bank; brief responsories are composed segment-by-segment
  on the R.br./R./V./R./Gloria/R. pattern with the received Gloria
  Patri. Six hand supplements (`commune:*` keys in
  `hours_supplements_es.json`) cover the Euge-serve-bone responsories,
  the C12 Felix namque responsory, the BVM Saturday oration, and the
  Regina caeli (received text).
  **Tranche O4 — the temporal propers, non-lesson fields: COMPLETE
  (`temporal_propers_es.json`, 2,919 parts / 5,048 fields — every
  antiphon, responsory, collect, versicle, and hymn of the temporal
  cycle; the Matins lessons are tranche O5).** App keys map 1:1 to DO
  Tempora filenames and field keys to section names, so the importer
  pairs each day's file section-for-section, following `@File:Section`
  references through both trees in lock-step, verifying the resolved
  Latin against the app's own text (first-line prefix identity — DO has
  re-split some lines since the app's import) and line counts against
  the app's Latin. Fallbacks: the global pair tables, line-by-line
  responsory composition from surviving lines, the psalter bank, and
  `TEMPORAL_FIX_PAIRS` — 61 hand translations for old-recension
  responsories/antiphons the current DO Espanol no longer carries
  (the August Wisdom-book responsories, Tenebrae orations with the
  received Padre nuestro, the Trinity Duo Séraphim, etc.), Torres Amat
  wording where the Latin follows the Vulgate.
  **Tranche O5a — the temporal Matins lessons, canonical scripture +
  patristic: 1,765 of 1,984 lesson fields.** The per-pericope audit
  confirmed the DO Espanol Tempora scripture lessons are largely a
  modern non-TA translation (TA-shingle score < 0.2 for 1,049 of 1,204
  scripture lessons), so canonical pericopes are COMPOSED from the
  Torres Amat module: the day's `!Ref` resolved through @-references,
  verse-numbered Latin lines zipped against the parsed ref, and — the
  audit's big find — the module's own versification drift corrected by
  a per-chapter line-shift chosen by cognate+length consensus across
  the whole corpus (the module's Isaiah sits one line early through
  chapter 44; most epistles similarly), with a local DP re-alignment
  for chapters that merge verses mid-stream and a lowercase-
  continuation rule where the Vulgate merges what the module splits.
  Patristic/homily lessons keep DO Espanol's traditional-register
  translation (tier 2, like the orations). The consensus table is
  exported (`ta_chapter_shifts.json`) and the MISSAL readings importer
  now consumes it — fixing 106 shipped readings that were silently one
  verse off in the drifted books (early Isaiah, Titus, 2 Tim, Hebrews,
  James, 1 Peter, 1 John, Revelation …).
  **Tranche O5b — the deuterocanonical lessons: COMPLETE
  (`lessons_deutero_office_es.json`, 202 unique pericopes / 211 lesson
  fields — 1 Mac, 2 Mac, Sirach, Wisdom, Judith, Tobit, Dan 3).** The
  66-book module lacks the deuterocanon, so these are our own tier-2
  translations from the Vulgate Latin the app carries, verse-for-verse
  with the same numbering, in the Torres Amat register (like
  `readings_deutero_es.json`). Five patristic lessons the DO Espanol
  tree lacks (the Trinity Augustine homily, Gregory's Expositio in
  libros Regum ×3, an Augustine passage on the high priest) are hand
  supplements. temporal_propers_es.json now covers all 7,032 fields —
  the temporal Office is 100% Spanish.
  **Tranche O6 — the seasonal hymns: COMPLETE
  (`hymns_seasonal_es.json`, 75 fields — every hymn of all 8 seasons
  plus the Compline canticle antiphons).** Traditional verse
  translations from DO Espanol's hymn table, the app's
  `<br>`-within-stanza structure mirrored. The app carries the
  pre-Urban-VIII texts for a few hymns ("Vox clara" where DO defaults
  to "En clara vox") — those are reached by their season-named sections
  in Major Special; four antiphons are hand supplements.
  **Tranche O7 — the sanctoral Office propers: COMPLETE
  (`sanctoral_propers_es.json`, 475 feasts / 4,392 parts / 8,987
  fields).** The full-app audit after O6 surfaced this corpus; it
  shares the temporal machinery — keys map to the Sancti files, the
  same section pairing, TA lesson composition with the chapter-shift
  consensus, and a new ORATION BANK: the Office collect of a feast is
  the Mass collect, so the missal's Spanish covers the common saints'
  orations (keyed by folded body with conclusions stripped and ae/oe
  normalized). Deuterocanonical additions (Sir 24/39/44/51, Tob 12)
  extend `lessons_deutero_office_es.json`; ~50 antiphon sets, octave
  commemorations, brief responsories, four late hymns (the 1950
  Assumption Vespers hymn, the three Cabrini hymns), and a dozen
  hagiographies the DO Espanol tree lacks are hand supplements in the
  traditional register.
  Remaining: the small rosary files (`mysteries.json`,
  `rosary_prayers.json` — tranche O8).
- Stations of the Cross — **COMPLETE: `stations_es.json`**, all 14
  stations: traditional Via Crucis titles, the meditations translated
  (tier 2), and the received Spanish Stabat Mater verses (tier 1,
  keeping each verse's line structure); the Latin titles and verses are
  untouched. The validator enforces full coverage and matching `<br>`
  counts.
- Saints' devotional programs — **COMPLETE: `saints_es.json`**, all 7
  saints: names, titles, quotes, all 61 practices, penances, and the
  saints' prayers (English side; the Latin texts are untouched).
  St Teresa's Letrilla ("Nada te turbe") and self-offering ("Vuestra
  soy, para Vos nací") and St Josemaría's Camino quote return to their
  ORIGINAL Spanish — received texts, not translations. Index-aligned by
  section/practice/prayer; the validator enforces exact count matches so
  a misalignment can never silently leave English behind.
- Reference encyclopedia — **COMPLETE: `reference_es.json`**, all 42
  entries (seasons, sacraments, prayer forms, devotions, penance,
  sacramentals, and the Latin-language articles): title, summary,
  history, practice, and notes translated, plus the scripture quote's
  English half (matching the Latin snippet's extent). The Latin names,
  category labels, refs, and Latin quotes stay. Optional fields are
  translated exactly when the source has them; embedded
  `<link target=…>` tags must survive with identical targets (validator
  enforced — the link scanner depends on them). The import also fixed
  cal-septuagesima's stray `"cat": "calendar"` (→ "Calendarium") in the
  English source, which had broken its grouping, deep-link type, and
  search category.
- Schola Latina courses — **COMPLETE: `courses_es.json`**, all 10
  courses, LOCALIZED rather than merely translated: the lessons address
  a Spanish ear (the vowels course teaches that Latin vowels ARE the
  Spanish five; the consonant and stress courses lean on the ñ, the
  «ch», and the written tilde Spanish speakers already know), every
  phonetic respelling is re-keyed to Spanish orthography ("DÓ-mi-nus",
  "re-YÍ-na", "A-ñus" — the English-keyed "DOH-mee-noos" style would
  mislead a Spanish reader), and the Ave/Pater phrase glosses use the
  received Spanish prayer wordings. The Latin card fronts are untouched.
  Aligned by section/item index with exact-count validation. (The
  `table` sections' rows are not decoded or displayed by either app
  today, so they have no Spanish side; if a table renderer is added,
  translate the rows then.)

With this, EVERY content surface of the app outside the Divine Office
corpus carries Spanish. What remains is the Office (multi-MB; see
below).

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
