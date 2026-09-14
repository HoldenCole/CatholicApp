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

Zero flags in every rite is the bar. `compare.py --golden DIR` also
writes the DO side as `<rite>.json.gz`, which
`android/app/src/test/resources/office_golden/` carries: the
`OfficeDivinumOfficiumGoldenTest` unit test re-derives the app's side for
every hour of the year and fails on any difference, so the comparison
runs with the ordinary test suite.

## Spanish

`scripts/build_office_spanish.py` gathers the Spanish the app already
carries for the same Latin texts into `spanish-translation/office_texts_es.json`
(normalised Latin → Spanish); both apps apply it to every text of an
assembled hour. Texts without an entry keep their English.
