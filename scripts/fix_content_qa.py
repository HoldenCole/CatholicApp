#!/usr/bin/env python3
"""
Text corrections from the final content QA (prayers/devotions, reference,
saints, courses reviews — every item DO/textus-receptus-verified):

prayers.json     Veni Creator stanza order (Accende before Hostem); Act of
                 Faith English re-aligned to its Latin; Morning Offering
                 dolores + in-union clause; propitiatio/miserationum/
                 Bartholomaee/offendi/errorum typos; Domine-non-sum-dignus
                 rubric Latinized; ADDS the Litany of the Sacred Heart
                 (the traditional litany triad was two-thirds present).
stations.json    Station IV dative (Matri suae); Station VIII stabat verse
                 mistranslation fixed (was the previous stanza's English).
marian_antiphons Alma/Ave season boundary made exact (Feb 1 / Feb 2);
                 Per eundem + Genetrix normalized.
reference.json   1962-discipline corrections: Palm Sunday red-then-violet,
                 Good Friday black, Sacred Heart date, Time-after-Epiphany
                 boundaries, Christmastide ends Jan 13, three-hour fast,
                 "1962 Code" -> 1917 Code, Lenten Saturday abstinence,
                 feast-class explanation, Rosary feast history, Lent-fast
                 attestation, garbled phrases; ADDS cal-septuagesima
                 (pre-Lent was entirely absent).
saints.json      Aquinas apocryphal quote replaced with his own Lauda Sion;
                 anachronistic Rosary note reworded; Padre Pio prayer note.
courses.json     Credo pronunciation CREH-doh (the course's own vowel rule).
hymns_seasonal   Advent Lauds English filler line fixed.
confession_guides Latin formula fields that held English filled with the
                 actual Latin texts.

Idempotent; writes byte-identically to both platforms' assets.
"""

import json
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
RESOURCES = REPO / "Introibo" / "Resources"
ANDROID = REPO / "android" / "app" / "src" / "main" / "assets"


def load(name):
    return json.loads((RESOURCES / name).read_text())


def write_both(name, data):
    text = json.dumps(data, ensure_ascii=False, indent=2) + "\n"
    for root in (RESOURCES, ANDROID):
        (root / name).write_text(text, encoding="utf-8")


def replace_in_tree(node, old, new, count):
    """Replace substring across every string in a JSON tree; returns hits."""
    if isinstance(node, dict):
        for k, v in node.items():
            if isinstance(v, str):
                if old in v:
                    node[k] = v.replace(old, new)
                    count[0] += 1
            else:
                replace_in_tree(v, old, new, count)
    elif isinstance(node, list):
        for i, v in enumerate(node):
            if isinstance(v, str):
                if old in v:
                    node[i] = v.replace(old, new)
                    count[0] += 1
            else:
                replace_in_tree(v, old, new, count)


def apply_replacements(data, pairs, fname):
    for old, new in pairs:
        count = [0]
        replace_in_tree(data, old, new, count)
        assert count[0] >= 1, f"{fname}: not found: {old[:60]!r}"


# ── prayers.json ─────────────────────────────────────────────────────────────

def fix_prayers(pr):
    def P(slug):
        return next(x for x in pr if x["slug"] == slug)

    # Veni Creator: Accende (currently 5th stanza) belongs 4th, before Hostem.
    vc = P("veniCreator")["lines"]
    assert vc[3]["lat"].startswith("Hostem") and vc[5]["lat"].startswith("Accénde")
    vc[3], vc[4], vc[5] = vc[5], vc[3], vc[4]

    # Act of Faith: English re-aligned to the Latin it translates.
    af = P("actFaith")["lines"]
    assert af[2]["lat"].startswith("qui retríbuet")
    af[2]["eng"] = ("Who will render to each according to his merits, "
                    "eternal life or eternal punishment.")
    assert af[3]["lat"].startswith("Hæc ómnia credo")
    af[3]["eng"] = ("All this I believe because Thou, O God, hast revealed it, "
                    "Who canst neither deceive nor be deceived. Amen.")

    # Morning Offering: dolores (the traditional pair), and the in-union clause.
    mo = P("morning")["lines"]
    mo[1]["lat"] = mo[1]["lat"].replace("gáudia et labóres", "gáudia et dolóres")
    assert "dolóres" in mo[1]["lat"]
    assert mo[3]["lat"].startswith("in ómnibus Missis")
    mo[3]["lat"] = ("in unióne cum ómnibus Missæ Sacrifíciis, "
                    "quæ hódie per orbem celebrántur,")

    # Rubric Latinized on the Latin side.
    dn = P("domineNSD")["lines"]
    assert dn[2]["lat"] == "(Said three times.)"
    dn[2]["lat"] = "(Ter dícitur.)"

    # Typos.
    apply_replacements(pr, [
        ("Quia apud te propitátio est", "Quia apud te propitiátio est"),
        ("miseratiónium", "miseratiónum"),
        ("Bartolomǽe", "Bartholomǽe"),
        ("offéndí", "offéndi"),
        ("érrórum", "errórum"),
    ], "prayers.json")

    # Litany of the Sacred Heart (Leo XIII, 1899) — completes the litany triad.
    if not any(x["slug"] == "litaniaeSacriCordis" for x in pr):
        inv = [
            ("Cor Jesu, Fílii Patris ætérni", "Heart of Jesus, Son of the Eternal Father"),
            ("Cor Jesu, in sinu Vírginis Matris a Spíritu Sancto formátum", "Heart of Jesus, formed by the Holy Ghost in the womb of the Virgin Mother"),
            ("Cor Jesu, Verbo Dei substantiáliter unítum", "Heart of Jesus, substantially united to the Word of God"),
            ("Cor Jesu, majestátis infinítæ", "Heart of Jesus, of infinite majesty"),
            ("Cor Jesu, templum Dei sanctum", "Heart of Jesus, holy temple of God"),
            ("Cor Jesu, tabernáculum Altíssimi", "Heart of Jesus, tabernacle of the Most High"),
            ("Cor Jesu, domus Dei et porta cæli", "Heart of Jesus, house of God and gate of heaven"),
            ("Cor Jesu, fornax ardens caritátis", "Heart of Jesus, burning furnace of charity"),
            ("Cor Jesu, justítiæ et amóris receptáculum", "Heart of Jesus, abode of justice and love"),
            ("Cor Jesu, bonitáte et amóre plenum", "Heart of Jesus, full of goodness and love"),
            ("Cor Jesu, virtútum ómnium abýssus", "Heart of Jesus, abyss of all virtues"),
            ("Cor Jesu, omni laude digníssimum", "Heart of Jesus, most worthy of all praise"),
            ("Cor Jesu, rex et centrum ómnium córdium", "Heart of Jesus, king and center of all hearts"),
            ("Cor Jesu, in quo sunt omnes thesáuri sapiéntiæ et sciéntiæ", "Heart of Jesus, in whom are all the treasures of wisdom and knowledge"),
            ("Cor Jesu, in quo hábitat omnis plenitúdo divinitátis", "Heart of Jesus, in whom dwelleth the fullness of divinity"),
            ("Cor Jesu, in quo Pater sibi bene complácuit", "Heart of Jesus, in whom the Father was well pleased"),
            ("Cor Jesu, de cujus plenitúdine omnes nos accépimus", "Heart of Jesus, of whose fullness we have all received"),
            ("Cor Jesu, desidérium cóllium æternórum", "Heart of Jesus, desire of the everlasting hills"),
            ("Cor Jesu, pátiens et multæ misericórdiæ", "Heart of Jesus, patient and most merciful"),
            ("Cor Jesu, dives in omnes qui ínvocant te", "Heart of Jesus, enriching all who invoke Thee"),
            ("Cor Jesu, fons vitæ et sanctitátis", "Heart of Jesus, fountain of life and holiness"),
            ("Cor Jesu, propitiátio pro peccátis nostris", "Heart of Jesus, propitiation for our sins"),
            ("Cor Jesu, satúrium oppróbriis", "Heart of Jesus, loaded down with opprobrium"),
            ("Cor Jesu, attrítum propter scélera nostra", "Heart of Jesus, bruised for our offenses"),
            ("Cor Jesu, usque ad mortem obédiens factum", "Heart of Jesus, obedient unto death"),
            ("Cor Jesu, láncea perforátum", "Heart of Jesus, pierced with a lance"),
            ("Cor Jesu, fons totíus consolatiónis", "Heart of Jesus, source of all consolation"),
            ("Cor Jesu, vita et resurréctio nostra", "Heart of Jesus, our life and resurrection"),
            ("Cor Jesu, pax et reconciliátio nostra", "Heart of Jesus, our peace and reconciliation"),
            ("Cor Jesu, víctima peccatórum", "Heart of Jesus, victim for our sins"),
            ("Cor Jesu, salus in te sperántium", "Heart of Jesus, salvation of those who trust in Thee"),
            ("Cor Jesu, spes in te moriéntium", "Heart of Jesus, hope of those who die in Thee"),
            ("Cor Jesu, delíciæ Sanctórum ómnium", "Heart of Jesus, delight of all the Saints"),
        ]
        lines = [
            {"lat": "Kýrie, eléison. ℟. Kýrie, eléison.", "eng": "Lord, have mercy. ℟. Lord, have mercy."},
            {"lat": "Christe, eléison. ℟. Christe, eléison.", "eng": "Christ, have mercy. ℟. Christ, have mercy."},
            {"lat": "Kýrie, eléison. ℟. Kýrie, eléison.", "eng": "Lord, have mercy. ℟. Lord, have mercy."},
            {"lat": "Christe, audi nos. ℟. Christe, exáudi nos.", "eng": "Christ, hear us. ℟. Christ, graciously hear us."},
            {"lat": "Pater de cælis, Deus, miserére nobis.", "eng": "God the Father of heaven, have mercy on us."},
            {"lat": "Fili, Redémptor mundi, Deus, miserére nobis.", "eng": "God the Son, Redeemer of the world, have mercy on us."},
            {"lat": "Spíritus Sancte, Deus, miserére nobis.", "eng": "God the Holy Ghost, have mercy on us."},
            {"lat": "Sancta Trínitas, unus Deus, miserére nobis.", "eng": "Holy Trinity, one God, have mercy on us."},
        ] + [
            {"lat": f"{l}, miserére nobis.", "eng": f"{e}, have mercy on us."}
            for l, e in inv
        ] + [
            {"lat": "Agnus Dei, qui tollis peccáta mundi, parce nobis, Dómine.", "eng": "Lamb of God, who takest away the sins of the world, spare us, O Lord."},
            {"lat": "Agnus Dei, qui tollis peccáta mundi, exáudi nos, Dómine.", "eng": "Lamb of God, who takest away the sins of the world, graciously hear us, O Lord."},
            {"lat": "Agnus Dei, qui tollis peccáta mundi, miserére nobis.", "eng": "Lamb of God, who takest away the sins of the world, have mercy on us."},
            {"lat": "℣. Jesu, mitis et húmilis corde.", "eng": "℣. Jesus, meek and humble of heart."},
            {"lat": "℟. Fac cor nostrum secúndum Cor tuum.", "eng": "℟. Make our hearts like unto Thine."},
            {"lat": "Orémus. Omnípotens sempitérne Deus, réspice in Cor dilectíssimi Fílii tui, et in laudes et satisfactiónes, quas in nómine peccatórum tibi persólvit, iísque misericórdiam tuam peténtibus tu véniam concéde placátus, in nómine ejúsdem Fílii tui Jesu Christi: Qui tecum vivit et regnat in sǽcula sæculórum. Amen.",
             "eng": "Let us pray. Almighty and eternal God, look upon the Heart of Thy most beloved Son and upon the praises and satisfaction which He offers Thee in the name of sinners; and to those who implore Thy mercy, in Thy great goodness grant forgiveness in the name of the same Jesus Christ, Thy Son: Who liveth and reigneth with Thee world without end. Amen."},
        ]
        idx = next(i for i, x in enumerate(pr) if x["slug"] == "litaniaeSanctorum")
        pr.insert(idx, {
            "slug": "litaniaeSacriCordis",
            "title": "Litaníæ Sacratíssimi Cordis Jesu",
            "eng": "Litany of the Sacred Heart",
            "category": "Devotiónes",
            "note": "Approved for public use by Leo XIII in 1899. Especially fitting on First Fridays and in June, the month of the Sacred Heart.",
            "lines": lines,
            "occasions": ["first-friday", "june"],
        })
    print("  prayers.json fixed (+ Litany of the Sacred Heart)")


# ── other corpora ────────────────────────────────────────────────────────────

def fix_stations(st):
    s4 = next(x for x in st if x["station"] == "IV")
    s4["latin"] = s4["latin"].replace("Iesus Matrem suam occurrit",
                                      "Iesus Matri suae occurrit")
    s8 = next(x for x in st if x["station"] == "VIII")
    s8["stabat_lat"] = "Vidit suum dulcem natum, moriéndo desolátum, dum emísit spíritum."
    s8["stabat_eng"] = ("She beheld her sweet Child dying, forsaken and desolate, "
                        "as He yielded up His spirit.")
    print("  stations.json fixed")


def fix_marian(ma):
    for m in ma:
        if m["slug"] == "alma":
            m["season"] = "Advent through February 1"
        if m["slug"] == "ave":
            m["season"] = "February 2 through Holy Wednesday"
    apply_replacements(ma, [("Per eúmdem", "Per eúndem")], "marian_antiphons.json")
    count = [0]
    replace_in_tree(ma, "Dei Génitrix", "Dei Génetrix", count)
    print("  marian_antiphons.json fixed")


def fix_reference(rf):
    apply_replacements(rf, [
        ("Violet then Red on Palm Sunday",
         "Red for the blessing of palms and procession on Palm Sunday, then violet for the Mass"),
        ("Red for Good Friday",
         "Black for Good Friday (violet for the Communion rite)"),
        ("falls on the Friday after Corpus Christi",
         "falls on the Friday of the week after Corpus Christi (the Friday after the Second Sunday after Pentecost)"),
        ("from Candlemas to Ash Wednesday",
         "from January 14 (after the Commemoration of the Baptism of Our Lord) to Septuagesima"),
        ("having fasted from midnight (1962 rules)",
         "having observed the Eucharistic fast (three hours under the 1957 discipline of Pius XII; from midnight under the older 1917 rule)"),
        ("on Wednesdays if following traditional discipline",
         "on Saturdays if following the traditional discipline of the 1917 Code"),
        ("established the feast of Our Lady of the Rosary",
         "established the feast of Our Lady of Victory in thanksgiving, which Gregory XIII renamed Our Lady of the Rosary"),
        ("attested from at least the second century",
         "attested from the fourth century"),
        ("the cast of a possessed person", "the case of a possessed person"),
    ], "reference.json")

    # "1962 Code" (3 phrasings) -> the law actually in force.
    for verb in ("binds", "mandates", "requires"):
        count = [0]
        replace_in_tree(rf, f"The 1962 Code {verb}",
                        f"The 1917 Code of Canon Law (in force in 1962) {verb}", count)

    # Christmastide endpoint.
    count = [0]
    replace_in_tree(rf, "through February 2 (Candlemas)",
                    "through January 13 (the Commemoration of the Baptism of Our Lord)", count)
    count = [0]
    replace_in_tree(rf, "Christmas vestments worn through Candlemas",
                    "White vestments through January 13; by popular custom the crib remains until Candlemas", count)

    # Feast classes.
    ranks = next(x for x in rf if x["slug"] == "cal-ranks")
    ranks["summary"] = ("Under the 1960 rubrics, feasts are of the First, Second, or "
                        "Third Class; lesser observances are kept as commemorations, "
                        "and liturgical days themselves are ranked I-IV class.")
    ranks["notes"] = ranks["notes"].replace(
        "are marked with a red cross in traditional missals",
        "are printed in capitals in traditional ordos")

    # New: the missing pre-Lent season.
    if not any(x["slug"] == "cal-septuagesima" for x in rf):
        ordinary = next(i for i, x in enumerate(rf) if x["slug"] == "cal-ordinary")
        rf.insert(ordinary + 1, {
            "slug": "cal-septuagesima",
            "title": "Septuagesima (Pre-Lent)",
            "latin": "Tempus Septuagesimæ",
            "cat": "calendar",
            "summary": "The two-and-a-half-week season of preparation for Lent: Septuagesima, Sexagesima, and Quinquagesima Sundays, from the third Sunday before Ash Wednesday until Shrove Tuesday.",
            "history": "Established at Rome by the sixth century, the season takes its names from the round numbers seventy, sixty, and fifty days before Easter. It was abolished in the 1969 calendar but remains in all the traditional books.",
            "practice": "Violet vestments; the Gloria is omitted on Sundays; the Alleluia is put away entirely from First Vespers of Septuagesima — a tract replaces it at Mass, and 'Laus tibi, Domine, Rex aeternae gloriae' replaces it in the Office. No fasting is yet required; the season invites a gradual entry into penance.",
            "notes": "The dismissal of the Alleluia (the 'depositio') was kept with real ceremony in medieval uses. The Sunday Masses — the laborers in the vineyard, the sower, the healing of the blind man — form a catechesis on grace before the Lenten fast begins.",
            "scripture": {
                "ref": "1 Cor 9:24-27",
                "lat": "Sic cúrrite, ut comprehendátis.",
                "eng": "So run, that you may obtain."
            }
        })
    print("  reference.json fixed (+ cal-septuagesima)")


def fix_saints(sa):
    aq = next(x for x in sa if x["slug"] == "aquinas")
    aq["quote"] = {
        "lat": "Quantum potes, tantum aude: quia major omni laude, nec laudáre súfficis.",
        "eng": "Dare to do all that you can: for He is greater than all praise, nor can you praise Him enough.",
        "source": "Lauda Sion (Sequence for Corpus Christi, composed by St. Thomas)",
    } if isinstance(aq.get("quote"), dict) else (
        "Quantum potes, tantum aude: quia major omni laude — "
        "Dare to do all that you can: for He is greater than all praise. "
        "(Lauda Sion, composed by St. Thomas)"
    )
    count = [0]
    replace_in_tree(sa, "Thomas loved the Rosary for its simplicity; ‘all the theology of the Incarnation in 50 beads.’",
                    "A daily Marian devotion in the spirit of Thomas's tender, lifelong devotion to Our Lady.", count)
    if count[0] == 0:
        count2 = [0]
        replace_in_tree(sa, "all the theology of the Incarnation in 50 beads",
                        "a daily meditation on the mysteries of the Incarnation", count2)
    count = [0]
    replace_in_tree(sa, "Composed by St. Padre Pio",
                    "Adapted from St. Pio of Pietrelcina's prayer after Holy Communion", count)
    print("  saints.json fixed")


def fix_courses(co):
    apply_replacements(co, [("CRAY-doh", "CREH-doh")], "courses.json")
    print("  courses.json fixed")


def fix_hymns(hs):
    count = [0]
    replace_in_tree(hs, "by sinful wounds laid low and few",
                    "that lies laid low by wounds of sin", count)
    print("  hymns_seasonal.json fixed" if count[0] else "  hymns_seasonal: line not found (skipped)")


def fix_confession(cg, actus_latin):
    for guide in cg:
        for step in guide.get("phases", []) + guide.get("steps", []):
            f = step.get("formula") if isinstance(step, dict) else None
            if not isinstance(f, dict):
                continue
            latin = f.get("latin") or ""
            if latin.startswith("Bless me, Father"):
                f["latin"] = "Benedic mihi, Pater, quia peccávi."
            elif latin.startswith("O my God, I am heartily sorry") or latin.startswith("O my God,"):
                f["latin"] = actus_latin
    print("  confession_guides.json fixed")


def main():
    pr = load("prayers.json")
    fix_prayers(pr)
    write_both("prayers.json", pr)

    st = load("stations.json")
    fix_stations(st)
    write_both("stations.json", st)

    ma = load("marian_antiphons.json")
    fix_marian(ma)
    write_both("marian_antiphons.json", ma)

    rf = load("reference.json")
    fix_reference(rf)
    write_both("reference.json", rf)

    sa = load("saints.json")
    fix_saints(sa)
    write_both("saints.json", sa)

    co = load("courses.json")
    fix_courses(co)
    write_both("courses.json", co)

    hs = load("hymns_seasonal.json")
    fix_hymns(hs)
    write_both("hymns_seasonal.json", hs)

    actus = next(x for x in pr if x["slug"] == "actusContr")
    actus_latin = " ".join(l["lat"] for l in actus["lines"])
    cg = load("confession_guides.json")
    fix_confession(cg, actus_latin)
    write_both("confession_guides.json", cg)

    # QA
    pr2 = load("prayers.json")
    vc = next(x for x in pr2 if x["slug"] == "veniCreator")["lines"]
    assert vc[3]["lat"].startswith("Accénde") and vc[4]["lat"].startswith("Hostem")
    assert any(x["slug"] == "litaniaeSacriCordis" for x in pr2)
    rf2 = load("reference.json")
    assert any(x["slug"] == "cal-septuagesima" for x in rf2)
    assert "propitiátio" in json.dumps(pr2, ensure_ascii=False)
    print("QA: content assertions passed.")


if __name__ == "__main__":
    main()
