# Divine Office QA register

Source: full-DO QA (structural sweep of every day, Advent 2025 – Dec 2026 ×
3 rites × 8 hours through the real pipeline, plus four rubrical reviews of 27
assembled-office dumps against Divinum Officium sources). Dumps regenerate via
`OfficeDumpHarness` (`build/office-qa-dumps`). Status: **fixed** = shipped;
**open** = confirmed defect awaiting its own pass; severity in brackets.

## Fixed in the initial office repair
- Feast/commune propers never rendering (variationKey rewrites, missing alias
  expansion on sanctoral layers, canticle-antiphon key collisions).
- Monastic responsorium breve at Vespers; Sunday hymn on every feria; ferial
  Benedictus/Magnificat antiphons and Mon–Sat hymns absent; Prime's collect
  leaking into the day hours (Sunday/Mass-collect inheritance added);
  commemorations absent; III-class Matins losing the saint's legend; preces
  position/scoping; Compline order; junk 09-15 doxology; early-January and
  resumed-Sunday collect gaps (also fixed the empty Missal tab there).

## Fixed in the QA-findings pass (this commit)
- [blocker] Privileged ferias (Ash Wednesday, Ember days — temporal winners
  named Feria/Sabbato/Die) treated as festal because rank ≥ 5: got Sunday
  psalms, 3-nocturn Matins, unstripped Alleluia antiphons. Now ferial
  regardless of rank (Triduum excepted — its Matins is 3-nocturn).
- [wrong-content] Preces feriales fired off the calendar day, so they appeared
  on feasts falling on penitential Wednesdays/Fridays (e.g. St Francis
  Xavier). Now gated on the office being ferial.
- [blocker] Great O antiphons missing at Vespers Magnificat Dec 17–23 (only
  the little hours had date overrides). Imported O Sapientia … O Emmanuel.
- [wrong-content] Septuagesima carried Christmastide hymns (season flag runs
  to Feb 2); pre-Lent now uses the per-annum set. Te Deum wrongly said from
  Septuagesima to Lent I on Sundays; now omitted.
- [wrong-content] Alleluia not stripped from psalm-attached antiphons in the
  Septuagesima–Lent window (only standalone antiphon parts were stripped).
- [wrong-content] Christmas II Vespers capitulum used the I-Vespers text;
  capitulum_vespera_3 now preferred at (2nd) Vespers.
- [wrong-content] Good Friday collect was raw DO markup; Maundy Thursday's
  lacked the Réspice; Holy Saturday's was absent. All three Triduum collects
  now carry Christus factus est (with the day's ending) + Pater + collect.
- [wrong-content] Commemorated temporal ferias (e.g. the Advent feria on
  III-class feasts) never rendered because the feria entry has no collect of
  its own; the commemoration now inherits the Sunday collect.
- [wrong-content] 09-19 collect had a duplicated saint-name substitution.
- [wrong-content] Prime's Lectio Brevis was empty per annum; it now borrows
  the day's None capitulum (the rubric's own rule).
- [cosmetic] Empty "Responsorium IX" label on Te Deum days removed.
- [cosmetic] Dump harness printed responsories as empty (v1Lat fields not
  shown) — caused false findings; fixed.

## Fixed in the final QA pass (psalm data · responsories · content · Mass ordinary)
Divine Office data (`scripts/fix_office_psalm_data.py`; closes items 1–3):
- Ferial Matins psalter rebuilt from DO `Psalterium/Psalmi matutinum.txt
  [DayN]`: 9 psalms per weekday with the 1960 antiphons over the RIGHT
  psalms, divisi slices (44i/44ii …) cut exactly on DO verse labels, and the
  three per-nocturn versicles imported.
- Proper/commune psalm assignments now honored: 847 pre-normalized slot
  parts across 77 temporal/sanctoral/commune entries (`matutinum.psalmN`,
  `vesperae.psalmN`, `laudes.psalmN`/canticle) parsed from the `;;N` refs of
  `[Ant Matutinum]`/`[Ant Vespera]`/`[Ant Laudes]`, with nocturn antiphons
  carried on prefixed `matutinum.ant_N` keys so canticle antiphons survive;
  Easter/Pentecost one-nocturn offices suppress the unused slots. Both
  assemblers gained the pre-normalized remap guard.
- 95 commune Matins responsories imported (C1, C8, C9 …) with full
  `@file:Section:s/x/y/` sed-reference resolution.

Prayers/devotions/reference content (`scripts/fix_content_qa.py`), all
verified against editio-typica sources: Veni Creator stanza order; Act of
Faith English realigned; Morning Offering completed (dolóres, union with
all Masses clause); Litany of the Sacred Heart ADDED; Stations IV/VIII Latin
titles; Marian-antiphon season boundaries (Candlemas cutover) and Per
eúndem/Génetrix orthography; ~12 reference corrections + a new Septuagesima
calendar entry; saints quotes re-attributed (Lauda Sion); course/confession
guide Latin fixes; assorted accent typos (propitiátio, Bartholomǽe …).

Order of Mass (code both platforms + `scripts/fix_missal_ordinary.py`):
- Dismissal now precedes the Placeat (Ite → Placeat → Blessing → Last
  Gospel); Placeat said at every Mass with only the blessing omitted at
  Requiems (placeat/benedictio split into separate sections).
- Communion of the faithful completed: priest's communion sequence ordered
  (Panem cæléstem → Dómine non sum dignus → communion → Confiteor of the
  people), Ecce Agnus Dei + the people's threefold Dómine non sum dignus
  added.
- The five proper Communicantes ended mid-sentence at "…Jesu Christi:" while
  the renderer swaps the whole canon line — the saint list and conclusion
  were silently deleted on Christmas/Epiphany/Easter/Ascension/Pentecost.
  Continuation appended; Christmas/Epiphany gain "Genetrícis ejúsdem Dei"
  ("Mother of the same God"); Genitrícis → Genetrícis throughout.
- 1962 Canon now inserts the St Joseph clause (decree 13 Nov 1962) at render
  time — plain and variant paths, view and share walks.
- Canon-variant gating unified across rites (the 1960 Codex retained the
  Easter/Pentecost octaves): variants run the whole octave, vigils included;
  Christmas variant through Jan 1, not the Jan 2–5 ferias.
- Doubled-Alleluia dismissal restricted to the Easter Octave (was also
  firing through Pentecost week); 1962 says Ite missa est even without
  Gloria; Requiem checks now precede season checks in showGloria.
- Sacred Heart / Christ the King prefaces recognized as proper prefaces;
  Sacred Heart "páteret salútis refúgium" and Easter "in hac potíssimum
  die" restored; Easter preface English aligned to the Latin (true Lamb,
  Thee/Thy).

## Open — data-layer (largest impact first)
1. **FIXED** in the final QA pass — ferial Matins psalter re-imported with
   divisi support (see above).
2. **FIXED** in the final QA pass — proper/commune psalm slots imported for
   Matins/Vespers/Lauds, incl. 3-psalm proper nocturns (see above). All
   Souls' fully proper psalter remains with item 4.
3. **FIXED** in the final QA pass — commune responsories imported with
   sed-reference resolution (see above).
4. [blocker] **All Souls (11-02)** needs the Office of the Dead structure:
   no hymn, no Te Deum, proper psalms at every hour, "A porta inferi"
   versicles, C9 responsories and the Fidelium collect (currently the
   pent23 Sunday collect).
5. [wrong-content] **Second Vespers uses First-Vespers material** where the
   commune distinguishes them (C1/C8 `[Ant Vespera 3]`, `[Versum 3]`,
   `[Hymnus Vespera 3]` e.g. Ave maris stella at Assumption II Vespers).
6. [wrong-content] **Seasonal ferial ordinarium never imported**: Advent/Lent
   capitula, versicles, invitatories for ferias (Venite et ascendamus, Vox
   clamantis, Rorate caeli, Regem venturum, per-weekday invitatory table),
   Dec 17–23 proper Lauds psalm antiphons.
7. [wrong-content] **Hymn text versions**: several seasonal hymns are the
   pre-Urban-VIII (HymnusM) texts — Advent Conditor/Vox clara (should be
   Creator alme / En clara vox), Lent Iam Christe (O sol salutis),
   Passiontide Lustris sex (Lustra sex), Christmastide Christe Redemptor
   (Jesu Redemptor). One Advent Matins hymn line matches no DO variant
   (contaminated text). Re-import seasonal hymns from base `[Hymnus …]`
   sections; also ferial Matins hymns per weekday (Nox atra etc. — Sunday's
   Nocte surgentes currently used all week).
8. [wrong-content] **Lauds II scheme** (penitential): pre-Lent/Lent Sundays
   and penitential ferias must use Lauds II (Ps 50 first, different
   canticle); the app always uses Lauds I.
9. [wrong-content] 11-18-class temporal lesson lookup: November scripture
   fell back to Genesis; contracted lesson picked Lectio5 over Lectio94 when
   layering through the inherit path; Prime festal psalm filtering leaves a
   stray Ps 118 fragment on I-class feasts (12-08).

## Open — rubric/engine layer
10. [blocker] **First Vespers.** I-class feasts (and Sundays) begin at I
    Vespers the prior evening: Jan 5 evening must be Epiphany I Vespers,
    Saturday evening the Sunday's. Needs "tomorrow outranks today at
    Vespers" logic in hourForDate.
11. [wrong-content] **Triduum structure** beyond the collects: Tenebrae must
    drop absolutions/blessings/Tu autem (Limit Benedictiones), openings and
    conclusions (Omit Incipit/Conclusio), Lauds capitulum/hymn/Deus-in-
    adjutorium; proper Lauds psalms (see #2); no commemorations in the
    Triduum (1955/pre-1955 currently append St Francis of Paola).
12. [wrong-content] **Easter/Pentecost octave scheme**: "Haec dies" replaces
    capitulum+hymn+versicle at all hours through the octave (currently only
    partially at Easter Lauds); psalms sine antiphona at the little hours;
    octave Lauds/Compline antiphon rules; double alleluia on Benedicamus;
    Epiphany Matins omits invitatory+hymn (Omit rule); Pentecost Lauds
    antiphons; Ember-Wednesday-in-octave Lauds furniture.
13. [wrong-content] **Versicle selection details**: ferial one-nocturn
    versicle should be the third nocturn's; commune Nocturn-I versicle from
    `[Versum 1]`; Lauds versicle off-by-one on commune feasts.
14. [wrong-content] **Commemoration form**: add the versicle when the
    commemorated office supplies none of its own but the commune does; III-
    class feasts should commemorate with ferial psalter antiphons per
    Rubr. 197b (currently commune psalm-antiphons over ferial psalms).
15. [wrong-content] **Suffrage of the Saints** (pre-1955 per-annum) not
    modeled at Lauds/Vespers.

## Extended QA (Missal + calendars + rite switching) — fixed
A dedicated Missal sweep (every day × 3 rites through properForDate, now in
CI) plus DO-verified reviews of the Mass propers and all three ordo tables.
**The 1962 ordo winners verified CLEAN**: a full-2026 comparison against
DO's own runtime found zero winner/rank errors — including transfers and
the 1960 Ember-week relocation. (The earlier register claim that 1962
September Ember Saturday precedence was inverted was itself wrong: the 1960
code moved the Embers to the week after the third Sunday; the app is
right.) Fixed in this pass:
- 52 Mass orations with doubled saint names; the 06-30 raw @-references
  (second orations of St. Peter); 35 Latin-only fields given English.
- Holy Name Sunday served the Circumcision Mass and office (its ordo key
  pointed at the pre-1960 octave stub): rekeyed to the floating "01-00",
  Mass bound to the complete formulary, office newly imported from DO
  (43 parts). Jan 2-5 ferias pinned to Puer natus (DO's own vide rule).
- Trinity Sunday had the OLD Dominica-I introit; now Benedicta sit.
- Christmas composite entry lacked the Viderunt omnes gradual.
- Missing sequences imported: Victimae paschali (Easter + octave), Stabat
  Mater (Seven Sorrows, Passion Friday), Dies irae (All Souls ×3).
- Four orations sourced from @Commune/C2a were expanded from the wrong
  commune (C2a-1) — re-resolved.
- 231 fields carried literal DO macros ($Per Dominum-family, &Gloria,
  v.-markers) — expanded; Easter gradual's spurious leading alleluia cut.
- 1962 commemoration keys: BVM-Saturdays now commemorate the day's saint
  (246 entries); Jan 5 commemorates S. Telesphorus (01-05cc), not the
  abolished vigil; transferred feasts commemorate the displaced saint
  (137); spurious per-annum-feria commemorations nulled (3,245 — ferias
  per annum are never commemorated under the 1960 rubrics).
- Vigil of Pentecost color white → red, all rites.
- Rite switching audited: every call site passes the user's rite; no
  surface relies on the defaulted parameter.

## Open — calendar/ordo layer
16. [blocker] **ordo_1955 misses Cum nostra** (~10 dates/yr, DO-verified):
    abolished octaves of Stephen/John/Innocents still celebrated Jan 2-4;
    Holy Name missing entirely (Jan 4); Vigil of Epiphany still present
    Jan 5 (rank read from the wrong DO rank row); abolished vigils of
    St James / Simon & Jude / All Saints and the Immaculate-Conception
    octave day still celebrated; several duplex feasts dropped outright
    (Feb 23, Apr 29, Jun 19); Ember commemoration keys point at common
    ferias instead of the Ember propers (093-N); simples not reduced to
    commemorations (07-30); opening Pater/Ave should already be gone.
17. [blocker] **ordo_pre1955 precedence + octaves** (~15 dates/yr):
    doubles/semidoubles must beat non-privileged greater ferias (Sep 16,
    Sep 19, Dec 16, Feb 23 inverted); five sanctoral octaves absent
    wholesale (John Baptist, Peter & Paul, Assumption, All Saints,
    Immaculate Conception); two winner/commemoration inversions (Jun 18,
    Dec 11); impeded-feast transfer not modeled (BVM Regina → Jun 1);
    Ember Saturday Vespers should be I Vespers of the Sunday.
18. [wrong-content] **The pre-1955 "<key>o" overlay is a blanket
    heuristic** (ContentStore, both platforms): it layers DO's Tridentine
    "o" files over Divino-Afflatu offices that never use them — 12-08
    gets the pre-1863 Conception office. Needs a data-driven whitelist of
    which o-files the DA rubrics actually use. Also: 1955 11-18 Matins
    pulls Septuagesima lessons (temporal lesson lookup for pent25).

## Open — Missal layer
19. [gap] **Commemorated collects at Mass not modeled**: MassProper has no
    second-collect field; ordo.commemoration is never read on the Mass
    path (the office renders commemorations; the Mass cannot).
20. [wrong-content] Tract/alleluia merged into the gradual field with no
    label (Septuagesima's De profundis, Lenten tracts); schema supports
    tractus but data never populates it. ~90 commune "N." saint-name
    placeholders unsubstituted. Nine oration refs carry commemoration
    headings. Christmas m1/m2/m3 Masses all modeled but no UI picker
    (composite 12-25 = third Mass always). Pre-1955 Good Friday
    (Presanctified) and its "r" stubs incomplete — 1962/55 content served
    to pre-1955 users; Triduum pseudo-formulary slot labels misleading
    ("Introit" over a tract).
21. [minor] Final-QA deferrals (reviewed, consciously not shipped):
    Munda cor meum + the Gospel dialogue absent from the printed Ordinary;
    Kyrie lacks priest/server alternation marks; preface season defaults
    are coarse (the Christmastide flag runs to Candlemas, so late-January
    ferias keep the Nativity preface; an "Advent preface" is offered though
    the 1962 Missale assigns the common preface in Advent — authenticity
    to be decided); green Sundays' formularies inherit to their ferias
    with gloria=true and the Trinity preface, where a repeated feria takes
    neither; preces omitted slightly too broadly on the Missal side;
    j/i orthography mixed across texts (Iesus/Jesus); the St Catherine
    confession-guide step count differs from its phase list.

## Deliberately out of scope (design decisions, unchanged)
- Antiphon doubling display (pre-1960 incipit-only before canticles).
- Winter/summer Sunday Lauds hymn alternation.
- Office of the Dead beyond All Souls; votive offices.
