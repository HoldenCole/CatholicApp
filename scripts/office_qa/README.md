# Office QA — the Divine Office against Divinum Officium

The app assembles every hour from Divinum Officium's own data and rules
(`OfficeRubrics.kt` / `OfficeRubrics.swift`, mirroring DO's Perl routine
by routine), and this directory holds the tooling that keeps it exactly
in step with DO for a whole liturgical year, in all three rites.

## Data pipeline (DO checkout → app assets)

`dodump.pl` runs inside a divinum-officium checkout (`DO_ROOT`) and dumps
DO's resolved data as JSON, one mode at a time:

    perl scripts/office_qa/dodump.pl "Rubrics 1960 - 1960" rules   > dorules_1962.json
    perl scripts/office_qa/dodump.pl "Rubrics 1960 - 1960" psalt   > dopsalt_1962.json   # DO_DOW=6 for the Saturday forms
    perl scripts/office_qa/dodump.pl "Rubrics 1960 - 1960" ants    > doants_1962.json
    perl scripts/office_qa/dodump.pl "Rubrics 1960 - 1960" commune > docommune_1962.json
    perl scripts/office_qa/dodump.pl "Rubrics 1960 - 1960" propers > dopropers_1962.json
    perl scripts/office_qa/dodump.pl "Rubrics 1960 - 1960" ordo 2024-01-01 2030-12-31 > doordo_1962.json

(the versions: `Rubrics 1960 - 1960`, `Reduced - 1955`, `Divino Afflatu - 1954`).
`build_office_psalterium.py` turns the dumps into the bundled assets,
written byte-identically to `Introibo/Resources/` and
`android/app/src/main/assets/`:

    office_rules.json          rank line, commune and Rule of every office file, per rite
    office_psalterium.json     the Psalterium (psalm lists, antiphons, capitula, hymns,
                               versicles, responsories, prayers, preces, suffrages, the Litany)
    office_ants.json           DO antiphon lists of the legacy propers
    office_commune.json        the Commons
    office_propers_<rite>.json every Sancti/Tempora file as DO resolves it for the rite
                               (with @MM-DD / @dowN / @pasch variants where DO's conditionals differ)
    office_ordo_<rite>.json    DO's precedence per date: the winner, its rank, the Vespers
                               concurrence, the commemoration lists, hymn shifts, ...

## Differential QA

`do_extract.py` renders DO's HTML for every hour of a date range and
reduces it to sections (`doqa/<rite>/<date>/<hour>.json`); the Kotlin
`OfficeJsonDump` test dumps the app's assembled hours the same way; and
`compare.py` checks them feature by feature (psalms, antiphons, hymn,
capitulum, versicles, short responsory, collects, lessons, the Marian
antiphon, the preces):

    cd android && OFFICE_JSON_DIR=/tmp/appqa OFFICE_JSON_START=2025-11-30 OFFICE_JSON_END=2026-11-28 \
      gradle :app:testDebugUnitTest --tests '*OfficeJsonDump*' --rerun
    python3 scripts/office_qa/compare.py --app /tmp/appqa --do /tmp/doqa --rites 1962,1955,pre1955 --report report.txt

Zero flags in every rite is the bar.

`compare_text.py` compares the WHOLE text instead — every line a user reads,
the app's parts flattened the way the hour views render them (the antiphon
before and after its psalms, ℣./℟. pairs, hymn stanzas) against DO's lines,
aligned with difflib and classified, so systematic omissions (a Glória Patri,
an Orémus, the invitatory inside the Venite) stand out over the year:

    python3 scripts/office_qa/compare_text.py --app /tmp/esdump --do /tmp/doqa --rites 1962 --step 4
    python3 scripts/office_qa/compare_text.py --app /tmp/esdump --do /tmp/doqa --show 1962:2025-11-30:prima

The fixed frame of the hours (`OfficeFrame.kt` / `OfficeFrame.swift`: the
Pater/Ave/Credo of the older books, the opening's Sicut erat and Allelúja,
Glória Patri after the psalms, the invitatory woven into the Venite, Deo
grátias after the capitulum, the short responsory said whole, Orémus and the
conclusion around the collects, DO's absolution and blessings, the ends of
the hours) was written from its report. `build_office_conclusions.py` reads
the collect → conclusion pairs DO printed over the year into
`office_conclusions.json` (both asset copies), which the frame looks up
(the propers carry the collects without DO's `$Per Dominum` markers). `compare.py --golden DIR` also
writes the DO side as `<rite>.json.gz`, which
`android/app/src/test/resources/office_golden/` carries: the
`OfficeDivinumOfficiumGoldenTest` unit test re-derives the app's side for
every hour of the year and fails on any difference, so the comparison
runs with the ordinary test suite.

## Matins lessons

`compare_lessons.py` compares the first words of every Matins lesson and
responsory with DO's over the year (a wrong choice, not a wrong text):

    python3 scripts/office_qa/compare_lessons.py --app /tmp/esdump --do /tmp/doqa --rites 1962

Its report drove the lesson rules in `ContentStore.hourForDate` (both
platforms): the 1960 one-nocturn Matins reads, on a Sunday, lessons 1, 2+3
and the Gospel homily with responsories 1, 3 and (Advent, Lent,
Septuagesima) 9, and on a III-class feast the Scripture of the day (2+3 as
one) with the Scripture's responsories 1 and 3 and the saint's contracted
legend (`lessons1960`); the Te Deum stands in place of the last responsory,
which then carries the Glória Patri; and the lessons follow the office DO's
precedence chose rather than the app's own calendar on the days the two
differ (the older books' transferred or kept feasts).

Known gaps the report still shows: the 1960 books' Scripture of
Dec 29 - Jan 13 (DO reads Romans from the Nativity/Epiphany files), the
Paschaltide responsories of the Apostles' Common, several feasts' homilies
(lessons 7-9) and the pre-1955 simplex feasts' single legend lesson
(DO reads Lectio94 or Lectio4 alone, the app joins 4-6) — the legacy
`temporal_propers.json` / `sanctoral_propers.json` carry one text per
file where DO's differ by rite.

## Spanish

`scripts/build_office_spanish.py` gathers the Spanish the app already
carries for the same Latin texts into `spanish-translation/office_texts_es.json`
(normalised Latin → Spanish); both apps apply it to every text of an
assembled hour. Texts without an entry keep their English.

Its second source is Divinum Officium's own Spanish column: `dodump.pl`
takes `DO_LANG2=Espanol` and dumps the Psalterium, the Commons and the
propers with Spanish beside the Latin (`--do-es DIR`); the builder pairs
them section by section and line by line, matching the same Latin across
editions with a fuzzy key (no marks, accents, punctuation or asterisks).
Entries are also stored under the key the apps compute at render time
(DO's `v.`/`r.` markers dropped, `V.`/`R.` as ℣./℟., a ℣./℟. pair split
in two), and the Latin the rubrics engine carries in code (the preces,
the Pater noster) is looked up too. `spanish-translation/office_texts_fixes_es.json`
holds hand corrections to texts only DO's column supplies (exact key →
Spanish), applied last.

`SpanishAuditDump` (Android unit test, runs only with `SPANISH_AUDIT_DIR`
set; `SPANISH_AUDIT_RITES`, `SPANISH_AUDIT_START`/`_END` optional) applies
the Spanish overlay and dumps every hour, the Mass proper and the ordo
name for every day and rite as JSON, so a scan for English left in the
Spanish office can run over the assembled result rather than the files.
