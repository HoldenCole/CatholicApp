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

The lessons of Matins and their responsories are not re-derived by rule:
the apps read what Divinum Officium itself prints for the day.
`do_lessons_extract.py` renders DO's Matins for every date of 2024-2030 in
the three books, Latin beside English and beside Spanish, and keeps each
"Lectio N" section (the 1960 books' Latin is taken with the j of DO's own
files, as the apps spell every book; the script patches the checkout's
`spell_var` once to allow it). `build_office_lessons.py` splits each
section into the lesson and its responsory and writes, byte-identically to
both apps:

    office_lessons.json     {"texts": [{lat, eng, ref?}], "days": {rite: {date: [[lesson, responsory], ...]}}}
    office_lessons_es.json  the Spanish of every text, index for index

    python3 scripts/office_qa/do_lessons_extract.py --do $DO_ROOT --out /tmp/dolessons --start 2024-01-01 --end 2030-12-31
    python3 scripts/office_qa/build_office_lessons.py --src /tmp/dolessons

`ContentStore.hourForDate` (both platforms, `applyDoLessons`) sets every
lesson and responsory slot from the day's row after the older layering,
drops a responsory DO does not print (the Te Deum follows), and adds one DO
prints where the hour has no slot (Tenebrae). So the Scripture occurrens
(the month-week books of August-November, the Nativity and Epiphany weeks),
the Commons' homilies, the 1960 contractions, transferred Sunday lessons
and the ninth lesson of a commemorated office are all DO's own choice. A
lesson DO prints as a bare rubric or not at all (a gap in its own files, a
handful of days in the 1955 books) keeps the app's layered text; dates
outside the table fall back to the layering (`lessons1960`, `monthdayKey`,
the Common variants), which is why that code remains.

The four lessons DO's Spanish column lacks are translated by hand in
`spanish-translation/office_lessons_fixes_es.json` (Latin -> Spanish); the
builder lists any others in `office_lessons_missing_es.json` beside it.

`MatinsDoLessonsTest` checks every day of the table in every book: the hour
has exactly DO's lessons, each with DO's text, and a responsory exactly
where DO prints one. `compare_lessons.py` compares the first words of every
lesson and responsory with a DO year dump (`do_extract.py`):

    python3 scripts/office_qa/compare_lessons.py --app /tmp/appqa --do /tmp/doqa --rites 1962,1955,pre1955

Before the table it counted a wrong lesson or responsory on 77 days of the
year in the 1960 books, 216 in the 1955 books and 261 in the pre-1955
books (the template's filler homily on saints' days "vide Commune", the
Common's responsories where the Scripture's are said, Genesis 1 from
mid-August to Advent); it now reports only its own first-word artifacts.

## Hymn doxologies

In the older books (not under the 1960 rubrics) the hymns DO marks with
"*" before their last stanza take the doxology of the feast or season:
Christmastide and feasts of Our Lady ("Jesu, tibi sit glória, Qui natus es
de Vírgine"), the Epiphany, Paschaltide, the Ascension, Pentecost, Corpus
Christi, the Sacred Heart. `build_office_doxologies.py --do $DO_ROOT`
writes `office_doxologies.json` (the marked hymns by their first two
lines, and Psalterium/Doxologies.txt in Latin, English and Spanish);
`OfficeRubrics.doxology` ports DO's choice (hymni.pl) and
`ContentStore.applyDoxology` swaps the stanza after the Spanish overlay,
on both platforms. Over the year the last stanza of every hymn now agrees
with DO but for five hymns where DO's own output is at fault or carries a
commemoration the apps do not see.

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

## French

French is ported from Divinum Officium's French column by the same
builder: `build_office_spanish.py --lang fr --do-es DIR --do-en DIR2
--targets LIST` writes `french-translation/office_texts_fr.json`. French
has no overlays of its own to gather from, so DO's column is its only
source; `--do-en` (the same dumps with the English column) keeps DO's
English fallback out, and `--targets` is the list of every Latin text the
apps render over a year (`collect_latin.py` on `OfficeJsonDump`'s output),
so a text is found even where the app words or lines it differently from
DO's files. `dodump.pl ... missa` dumps the Mass propers with the second
language for `scripts/import_french.py`, which also builds the psalter, the
Marian antiphons and the calendar and saints' names;
`build_office_lessons.py` and `build_office_doxologies.py` carry a French
column beside the Spanish. The whole procedure, the coverage and the
provenance of DO's French are in `french-translation/README.md`.

`OfficeJsonDump` takes `OFFICE_JSON_LANG=fr`; comparing its vernacular
fields with an English and a Spanish dump of the same days shows what French
still leaves in English (a field Spanish translates and French does not).
For French the builder also writes `hours_parts_fr.json`, the overlay of
the hour templates (`--do-root DO_ROOT` adds DO's Invitatory as a verse
source). `ContentAuditDump` (Android unit test, `CONTENT_AUDIT_DIR`,
`CONTENT_AUDIT_LANG`) does the same for everything outside the Office.

`SpanishAuditDump` (Android unit test, runs only with `SPANISH_AUDIT_DIR`
set; `SPANISH_AUDIT_RITES`, `SPANISH_AUDIT_START`/`_END` optional) applies
the Spanish overlay and dumps every hour, the Mass proper and the ordo
name for every day and rite as JSON, so a scan for English left in the
Spanish office can run over the assembled result rather than the files.
