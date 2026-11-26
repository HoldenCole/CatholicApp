# French overlay (work in progress — not offered in store builds)

French is the app's third vernacular. It reuses the Spanish overlay
mechanism unchanged: a file `X_fr.json` overlays the asset `X.json` exactly
as `X_es.json` does, with its fields named `*_fr` instead of `*_es`
(both apps read every language through the one schema). A file French
does not have yet is simply absent and the app shows English for it.

`VernacularLanguage.FRENCH` is marked **not released**: the language
pickers offer it only in debug builds. Flip `released` (Android
`Settings.kt`, iOS `VernacularLanguage`) when French is ready to ship.

## What is here, and where it comes from

Everything in this first tranche is a **port of Divinum Officium's French**
(`web/www/{horas,missa}/Francais` of the divinum-officium repository),
matched to the app's data by its Latin. Nothing was machine-translated.

| File | Content | Coverage |
|---|---|---|
| `office_texts_fr.json` | Latin → French for the Office texts both apps assemble (antiphons, chapters, hymns, versicles, responsories, collects, blessings, preces) | 99.6 % of the vernacular fields of a year's Office in the three rites (what is left is the Martyrology at Prime and 25 texts) |
| `office_lessons_fr.json` (written straight into the asset folders) | Matins lessons and responsories, aligned with `office_lessons.json` | 4,709 of 4,717 texts |
| `psalter_fr.json` | The psalms and canticles, verse for verse | 166 of 202 (the rest: 26 newer canticles DO has no French for, 10 with a different verse division) |
| `missal_propers_fr.json` | Mass antiphons, orations, sequences | with the readings (`missal_readings_fr.json`), 5,055 of the Missal's 5,181 fields (97.6 %) |
| `missal_readings_fr.json` | Epistles and Gospels (title lines in the hand missals' form, by rule) | ≈ 93 % of fields |
| `missal_fr.json` | The Ordinary of the Mass: 173 of its 179 lines are DO's French (Ordo, Prefationes, Prayers); 4 complete a DO text, 2 are placeholders; the section headings and the app's own rubrics are translated by hand | complete |
| `canon_variants_fr.json` | The proper Communicantes and Hanc igitur | complete, all from DO |
| `marian_antiphons_fr.json` | The four final antiphons with versicle and collect | complete |
| `ordo_names_fr.json` | Calendar titles (feast and feria names) | 1,025 of 1,184 |
| `office_names_fr.json` | Saints' names for the "N." of the common collects | every name DO carries |
| `office_doxologies.json` (`fr` field, in the asset folders) | The seasonal hymn doxologies | 6 of 7 |

`martyrology_fr.json` — the Martyrology read at Prime — is DO's French
Martyrology, which keys every entry by the same name as the Latin: 3,201
of the 3,209 entries and all 23 movable announcements matched; the other
eight (leap-year rubrics, three entries DO files under another day) are
in `martyrology_fixes_fr.json`, composed from DO's own wording. DO's
French adds some 300 modern notes the Martyrology does not have
("(aujourd’hui Kayseri en Turquie)"); they are removed, and the calendar
day a Roman date falls on ("(14 décembre)") is kept. DO's credits do not
say where this translation comes from, and those notes show a recent
hand: its provenance is unknown and belongs with the questions below.

A second tranche comes from the received French prayers rather than from
DO alone:

| File | Content | Source |
|---|---|---|
| `prayers_fr.json` | The prayer library: 90 prayers, 1,281 lines | 774 lines in DO's or the Ordinary's wording; 214 in the received form checked against public-domain prints on archive.org (the 1919 *Manuel des congrégations de la Très Sainte Vierge* for the approved litanies, a 1913 *Nouveau paroissien romain*, the 1865 *Lettres* of St Francis de Sales, *Histoire d'une âme* for St Thérèse's own words); 80 in the received form from memory, not yet checked against a print (Souvenez-vous, Âme du Christ, the Fatima prayer, the litany of the Precious Blood…); 213 translated by hand from the Latin where no received French exists (the litanies of Humility, the Holy Ghost, the Blessed Sacrament and the Faithful Departed, the app's own morning and night prayers, the saints' prayers from other languages) |
| `rosary_prayers_fr.json` | The prayers of the Rosary | The received traditional forms ("vous"); Credo, Pater and Ave as DO prints them |
| `mysteries_fr.json` | The fifteen mysteries | Customary names and fruits; the app's own short meditations translated by hand, Gospel quotations in Crampon's wording |
| `stations_fr.json` | The Stations of the Cross | Customary titles; meditations translated by hand; the Stabat Mater stanzas are DO's |
| `confession_examen_fr.json`, `confession_guides_fr.json` | Examination of conscience and guides | Commandments in the old catechism formulas, the received Act of Contrition; the questions and steps translated by hand |
| `daily_psalm_fr.json` | The daily psalm verse | Fillion's psalter (`psalter_fr.json`), verbatim |
| `hours_fr.json` | Hour names, times and introductions | Customary names; introductions translated by hand |

`ui_strings_fr.json` is the interface: the same 747 keys as the Spanish
file, translated by hand from the English wording at the call sites
("vous" to the user, the liturgical vocabulary of the French content
files). Text the code still hard-codes in English, and plural or
word-order assumptions French cannot satisfy from a data file, are listed
in the commit that added it.

`reference_fr.json`, `saints_fr.json` and `courses_fr.json` are the
learning pages, translated by hand from the English: the 42 reference
articles (Scripture quoted in the Crampon and Fillion wording the app
already carries), the 7 saints' pages (prayers reused from
`prayers_fr.json`), and the 10 Latin lessons, rewritten for a French
reader as the Spanish ones were for a Spanish one — comparisons with
French sounds and words, and every pronunciation respelled for French
spelling ("DO-mi-nous", "PA-tèr").

`hours_parts_fr.json` overlays the hour templates themselves (the Office
of the Dead, which opens from its template; the Invitatory, the Benedictus,
the Magnificat, the Nunc dimittis, the Te Deum and the Athanasian Creed,
whose verses the assembled hours take from the templates; and the search
index). `build_office_spanish.py --lang fr` writes it from the same French,
by Latin text, with the psalm verses from `psalter_fr.json` and DO's
Invitatory (`--do-root`). `psalter_fixes_fr.json` supplies the three psalm
lines DO's French files merge or lack (Ps 21:25, 77:1, 84:9).

## Matins lessons: not all of DO's French renders the Vulgate

DO's credits name Fillion for the Old Testament and Crampon for the New,
but its French Matins lessons are a patchwork. Sampling two lessons in
every book shows Fillion/Crampon in most of the Pentateuch, Isaiah,
Jeremiah, Lamentations, Tobit, Judith, Esther, the Maccabees and most of
St Paul; Crampon's 1923 Old Testament, translated from the Hebrew and
printing "Yahweh" where the Latin beside it says *Dóminus*, in Proverbs,
Ezekiel and the minor prophets (80 lessons contain "Yahweh"); and a modern
liturgical translation (the wording of the AELF lectionary, © AELF) in the
Books of Kings, Job, Sirach, Ecclesiastes, Wisdom, the Catholic Epistles,
Hebrews, the Apocalypse and others. By book, some 750 of the 1,882
Scripture lessons (about 40 %) are in the latter two groups. The Office of
the Dead's nine lessons from Job are the modern text in DO and are left in
English in its template for that reason. Replacing these with Fillion's
Vulgate translation (public domain; the whole Bible is at
jesusmarie.free.fr, as PDFs) is the remaining fix.

Working files that are **not** bundled: `office_texts_fixes_fr.json` (hand
corrections and the few texts whose wording in the app differs from DO's,
applied last by the builder), `office_lessons_missing_fr.json` and
`ordo_names_missing_fr.json` (what DO's French lacks — the to-do list for
hand translation).

## Provenance — read before releasing French

Divinum Officium's own credits (`web/www/horas/Help/credits.html`) give the
sources of its French:

- **Psalter and Old Testament:** Fillion's Bible and his *Psautier du
  Bréviaire romain* (L.-Cl. Fillion, d. 1927) — public domain.
- **New Testament:** Crampon's translation (A. Crampon, d. 1894), with
  *tu* changed to *vous* — public domain.
- **Proper of the Mass:** « Les traductions du propre en français sont
  l’œuvre et la propriété de l’Abbaye Sainte-Madeleine du Barroux. » The
  abbey contributed its translations to Divinum Officium; they remain the
  abbey's property.
- **Ordinary of the Mass:** from Sancta Missa (sanctamissa.org), with
  rubrics from introibo.fr.
- **Hymns and other liturgical texts:** from introibo.fr.
- **The rest of the Office:** the *Bréviaire romain latin-français*,
  Labergerie, 1956.

So the Scripture is public domain, but the Mass orations (Le Barroux) and
the non-scriptural Office texts (Labergerie 1956, introibo.fr) are modern
translations whose rights belong to others. Divinum Officium publishes
them in an MIT-licensed repository with these credits; that is the basis
on which they are reproduced here, with the same attribution. The Spanish
overlay took a stricter line (it replaced DO texts of modern copyrighted
origin with public-domain ones), and the same question must be settled for
French **before `released` is switched on**: either obtain the abbey's
(and, if traceable, the 1956 breviary publisher's) agreement, or replace
those layers from a public-domain source (Dom Guéranger's *L'Année
liturgique*, d. 1875, translates the whole Proper of the Mass and much of
the Office). The app's credits screen must name these sources in any case.

Note also that *introibo.fr* is an established French traditional-liturgy
site with the same name as this app.

## Not yet in French (hand translation, later tranches)

The 159 calendar titles and 8 lessons listed in the
`*_missing_fr.json` files, and 126 Mass fields (run
`import_french.py --dumps … missal --report`, which lists every Latin line
without French). They are, roughly: Holy Week's own texts (the Good Friday
Improperia and Trisagion, Holy Thursday), the Dies iræ of All Souls, a few
feasts DO's French does not have (Our Lady of Guadalupe, St Peter Claver,
St Isidore the Farmer, St Sigismund…), lines the app splits differently
from DO (St Matthew's Gospel), and some fields whose Latin carries
import debris (rubric lines in the Gospel of 14 August, "[ ]" in the
Introit of 9 November) that should be cleaned on the Latin side first.

How the Mass French is matched (`import_french.py missal`): DO's French and
Latin Mass files are paired line by line; DO's Commons (horas/*/Commune,
which its Mass reads but the dumps do not carry) are paired section by
section; DO's own rendering of each saint's collect, secret and
postcommunion (`dodump.pl … missaprayers`, the Common's prayer with the
saint's name filled in) is paired too; the Commons' "N." lines become
patterns that take the saint's name from the Mass's Latin and give it in
French (`office_names_fr.json`, `NAMES_EXTRA`); and the Paschal
"(Allelúja, allelúja.)" of the Commons is matched with or without its
brackets.

The saints' Mass prayers themselves were put right on the Latin and English
side first (`scripts/fix_mass_prayers.py`, then `fix_mass_prayers_es.py` for
the Spanish): the import had filled the Commons' "N." in the wrong case or
not at all, taken secrets and postcommunions from the wrong Mass of the
Common, and appended stray second collects; each now reads as DO renders it
for the 1962 Missal, with the few names DO itself leaves in the wrong case
corrected by hand.

`missal_fr.json` and `canon_variants_fr.json` were aligned by hand against
DO's Ordo files (which are not line-aligned with the Latin) and are edited
in place; the other files are regenerated by the scripts below.

## Rebuilding

    DO=/path/to/divinum-officium          # a checkout, read as data only
    export DO_ROOT=$DO
    mkdir -p /tmp/dofr /tmp/doen
    for L in Francais English; do
      d=/tmp/dofr; [ $L = English ] && d=/tmp/doen
      DO_LANG2=$L            perl scripts/office_qa/dodump.pl "Rubrics 1960 - 1960"   psalt   > $d/psalt.json
      DO_LANG2=$L DO_DOW=6   perl scripts/office_qa/dodump.pl "Rubrics 1960 - 1960"   psalt   > $d/psalt_sat.json
      DO_LANG2=$L            perl scripts/office_qa/dodump.pl "Reduced - 1955"        psalt   > $d/psalt_1955.json
      DO_LANG2=$L            perl scripts/office_qa/dodump.pl "Divino Afflatu - 1954" psalt   > $d/psalt_pre1955.json
      DO_LANG2=$L            perl scripts/office_qa/dodump.pl "Rubrics 1960 - 1960"   commune > $d/commune.json
      for v in "Rubrics 1960 - 1960:1962" "Reduced - 1955:1955" "Divino Afflatu - 1954:pre1955"; do
        DO_LANG2=$L perl scripts/office_qa/dodump.pl "${v%%:*}" propers > $d/propers_${v##*:}.json
        DO_LANG2=$L perl scripts/office_qa/dodump.pl "${v%%:*}" missa   > $d/missa_${v##*:}.json
      done
    done

    # every Latin text the apps render in a year (English dump of the Office)
    #   OFFICE_JSON_DIR=/tmp/appqa OFFICE_JSON_FULL=1 gradle :app:testDebugUnitTest --tests '*OfficeJsonDump*' --rerun
    python3 scripts/office_qa/collect_latin.py /tmp/appqa /tmp/office_latin.json

    python3 scripts/build_office_spanish.py --lang fr --do-es /tmp/dofr --do-en /tmp/doen --targets /tmp/office_latin.json
    # the saints' Mass prayers as DO renders them (Latin + French)
    DO_LANG2=Francais perl scripts/office_qa/dodump.pl "Rubrics 1960 - 1960" missaprayers > /tmp/dofr/missaprayers_1962.json
    python3 scripts/import_french.py --do $DO --dumps /tmp/dofr            # psalter, missal, marian, names
    python3 scripts/office_qa/do_lessons_extract.py --do $DO --out /tmp/dolessons --langs Francais ...
    python3 scripts/office_qa/build_office_lessons.py --src /tmp/dolessons   # writes office_lessons_{es,fr}.json
    python3 scripts/office_qa/build_office_doxologies.py --do $DO
    python3 scripts/sync_french_assets.py                                  # validates, then copies into both apps

To see what is still English in French mode, dump the Office twice
(`OFFICE_JSON_LANG=fr` and without) and compare the vernacular fields.
