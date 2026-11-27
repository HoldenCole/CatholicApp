#!/usr/bin/env python3
"""Import the French that Divinum Officium carries into the French overlay.

  python3 scripts/import_french.py --do DO_ROOT --dumps DIR [steps...]

DO_ROOT is a divinum-officium checkout; DIR holds dodump.pl's output with
the French column (DO_LANG2=Francais): missa_<rite>.json for the Mass (see
scripts/office_qa/README.md, "French"). Steps (default: all):

  psalter   french-translation/psalter_fr.json          the psalms, verse for verse
  missal    french-translation/missal_propers_fr.json   Mass antiphons and orations
            french-translation/missal_readings_fr.json  Epistles and Gospels
  marian    french-translation/marian_antiphons_fr.json the four final antiphons
  martyrology french-translation/martyrology_fr.json    the Martyrology read at Prime
  names     french-translation/ordo_names_fr.json       the calendar's feast names
            french-translation/office_names_fr.json     saints' names for the "N." of the collects

Everything is matched to the app's own data by its Latin: a French line is
taken only where DO prints it beside the very Latin line the app carries,
and a field is written only when every one of its lines resolves, so no
field ever mixes French with English. Sources and their provenance are in
french-translation/README.md.
"""
import json
import re
import sys
import unicodedata
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / "android" / "app" / "src" / "main" / "assets"
FR = ROOT / "french-translation"
RITES = ("1962", "1955", "pre1955")


def arg(name, default=None):
    return sys.argv[sys.argv.index(name) + 1] if name in sys.argv else default


def load(p):
    return json.load(open(p, encoding="utf-8"))


def dump(obj, name, indent=1):
    FR.mkdir(exist_ok=True)
    with open(FR / name, "w", encoding="utf-8") as f:
        json.dump(obj, f, ensure_ascii=False, indent=indent, sort_keys=True)
        f.write("\n")


MARK_RE = re.compile(r"^(℟\.br\.|℟\.|℣\.|R\.br\.|R\.|V\.|v\.|r\.|Ant\.)\s*")


def fold(t):
    """The same Latin across editions: no marks, accents, punctuation or case."""
    t = unicodedata.normalize("NFC", t or "")
    t = MARK_RE.sub("", t.strip())
    t = unicodedata.normalize("NFD", t)
    t = "".join(c for c in t if unicodedata.category(c) != "Mn")
    t = t.lower().replace("æ", "ae").replace("œ", "oe").replace("j", "i").replace("v", "u")
    # spellings the editions vary: cælis / cœlis, natalítia / natalícia
    t = t.replace("oe", "ae")
    t = re.sub(r"ci(?=[aeiou])", "ti", t)
    t = re.sub(r"[^a-z0-9 ]+", " ", t)
    return re.sub(r"\s+", " ", t).strip()


def tidy(t):
    """A French line as the apps show it (its no-break spaces before the
    high punctuation are kept)."""
    t = unicodedata.normalize("NFC", t)
    t = re.sub(r"\{:[^}]*:\}", "", t)
    # DO's French often leaves the alleluia in its Latin spelling
    t = re.sub(r"\b([Aa])llel[uú][ij]a\b", lambda m: m.group(1) + "lléluia", t)
    t = re.sub(r"(?<!\.)\.\.$", ".", t.rstrip())     # DO's doubled full stop
    return re.sub(r"[ \t]{2,}", " ", t).strip()


ALLELUIA_ONLY = re.compile(r"^(?:[Aa]ll[eé]l[uú][ij]a[.,;]?\s*)+$")
# also the Paschal "(Allelúja, allelúja.)" the commons carry in brackets
ALLELUIA_TAIL = re.compile(r"(?:\s*\((?=[Aa]ll))?(?:[,.;:]?\s*[Aa]ll[eé]l[uú][ij]a\.?)+\)?\s*$")


def strip_alleluia(t):
    """(the text without its closing alleluias, how many there were)."""
    m = ALLELUIA_TAIL.search(t)
    if not m or m.start() == 0:
        return t, 0
    return t[:m.start()].rstrip(), len(re.findall(r"[Aa]ll[eé]l", m.group(0)))


# ---------------------------------------------------------------- psalter

def psalter(do):
    """psalter_fr.json: {"psalmN": {"lines": [...]}} aligned verse for verse
    with psalter.json (DO's own psalm files in both languages)."""
    src = load(ASSETS / "psalter.json")
    base = Path(do) / "web/www/horas/Francais/Psalterium/Psalmorum"
    fp = FR / "psalter_fixes_fr.json"
    fixes = {k: v for k, v in (load(fp) if fp.exists() else {}).items() if not k.startswith("_")}
    out, stats = {}, Counter()
    for key, ps in src.items():
        f = base / ("Psalm" + key[len("psalm"):].upper() + ".txt")
        if not f.exists():
            f = base / ("Psalm" + key[len("psalm"):] + ".txt")
        if not f.exists():
            stats["no file"] += 1
            continue
        lines = [tidy(l) for l in f.read_text(encoding="utf-8").split("\n") if l.strip()]
        lat = ps["lat"]
        # DO's file merges two half-verses into one line, or lacks a verse:
        # psalter_fixes_fr.json gives those lines by Latin index
        fx = fixes.get(key)
        if fx and len(lines) == len(lat) - len(fx) + sum(1 for i in fx if int(i) > 0 and str(int(i) - 1) in fx):
            out_lines, it = [], iter(lines)
            for i in range(len(lat)):
                if str(i) in fx:
                    if not (i > 0 and str(i - 1) in fx):
                        if i > 0 or str(i + 1) in fx:
                            next(it, None)        # the merged DO line both fixes replace
                    out_lines.append(fx[str(i)])
                else:
                    out_lines.append(next(it))
            lines = out_lines
            stats["fixed"] += 1
        if len(lines) != len(lat):
            stats["line count differs"] += 1
            continue
        # The same number of lines is the same division into verses; the
        # French files letter the half-verses ("129:2b") and are a number
        # off here and there, so each line takes the Latin line's own label.
        label = re.compile(r"^\(?\d+\s?[a-z]?\s?[:;]\s?\d+[a-z]?\)?\s+")
        fixed = []
        for a, b in zip(lat, lines):
            ma, mb = label.match(a), label.match(b)
            if bool(ma) != bool(mb):
                fixed = None
                break
            # (and loses the half-verse marks set inside the line: "* (2a) Seigneur")
            fixed.append(re.sub(r"\s*\(\d+[a-z]\)(?=\s)", "", ma.group(0) + b[mb.end():] if ma else b))
        if fixed is None:
            stats["labels differ"] += 1
            continue
        lines = fixed
        out[key] = {"lines": lines}
        stats["ok"] += 1
    dump(out, "psalter_fr.json")
    print("psalter:", dict(stats), "of", len(src))


# ------------------------------------------------------------------ missal

BOOKS = {
    "matthaeum": "Matthieu", "marcum": "Marc", "lucam": "Luc", "ioannem": "Jean",
}
PAUL = {
    "romanos": "aux Romains", "corinthios": "aux Corinthiens", "galatas": "aux Galates",
    "ephesios": "aux Éphésiens", "philippenses": "aux Philippiens", "colossenses": "aux Colossiens",
    "thessalonicenses": "aux Thessaloniciens", "timotheum": "à Timothée", "titum": "à Tite",
    "hebraeos": "aux Hébreux",
}
APOSTLES = {"petri": "Pierre", "iacobi": "Jacques", "ioannis": "Jean", "ioanni": "Jean", "iudae": "Jude"}
LIBRI = {
    "sapientiae": "du livre de la Sagesse", "iudith": "du livre de Judith", "regum": "du livre des Rois",
    "exodi": "du livre de l’Exode", "genesis": "du livre de la Genèse", "numeri": "du livre des Nombres",
    "leuitici": "du livre du Lévitique", "esther": "du livre d’Esther", "esdrae": "du livre d’Esdras",
    "tobiae": "du livre de Tobie", "machabaeorum": "du livre des Machabées",
    "apocalypsis beati ioannis apostoli": "du livre de l’Apocalypse du bienheureux Apôtre Jean",
}
PROPHETS = {
    "isaiae": "Isaïe", "ieremiae": "Jérémie", "ezechielis": "Ézéchiel", "danielis": "Daniel",
    "ioelis": "Joël", "osee": "Osée", "ionae": "Jonas", "malachiae": "Malachie",
}


# The few lines no DO file pairs: rubrics of the app's own data, by hand.
# Saints' names the Commons' "N." takes that office_names_fr.json lacks
# (Latin case form -> French), for by_template in missal().
NAMES_EXTRA = {
    "Sotéris": "Soter", "Cleti": "Clet", "Caii": "Caïus", "Marcellíni": "Marcellin",
    "Telésphoro": "Télesphore", "Telésphori": "Télesphore", "Lúcio": "Luce", "Lúcii": "Luce",
    "Anicéto": "Anicet", "Anicéti": "Anicet", "Joánne": "Jean", "Joánnis": "Jean",
    "Maríæ": "Marie", "María": "Marie", "Stéphano": "Étienne", "Stéphani": "Étienne",
    "Lino": "Lin", "Lini": "Lin", "Hygíni": "Hygin", "Maurus": "Maur", "Márii": "Marius",
    "Andréæ Corsíni": "André Corsini", "Faustíni": "Faustin", "Jovítæ": "Jovite",
    "Perpétuæ": "Perpétue", "Felicitátis": "Félicité", "Benedíctus": "Benoît",
    "Isidórus": "Isidore", "Ansélmus": "Anselme", "Gregórius": "Grégoire",
    "Bonifátii": "Boniface", "Eleuthérii": "Éleuthère", "Felícis": "Félix", "Felíce": "Félix",
    "Gervásii": "Gervais", "Protásii": "Protais", "Leónis": "Léon", "Pii": "Pie", "Pio": "Pie",
    "Symphorósæ": "Symphorose", "Xysti, Felicíssimi": "Sixte, Félicissime", "Agapíti": "Agapit",
    "Cyríaci, Largi": "Cyriaque, Large", "Smarágdi": "Smaragde", "Cornélii": "Corneille",
    "Cypriáni": "Cyprien", "Januárii": "Janvier", "Eustáchii": "Eustache", "Eustáchio": "Eustache",
    "Remígio": "Remi", "Plácidi": "Placide", "Úrsulæ": "Ursule", "Evarísti": "Évariste",
    "Cároli": "Charles", "Pontiáni": "Pontien", "Joánnis a Cruce": "Jean de la Croix",
    "Sabbas": "Sabas", "Melchíadis": "Melchiade", "Melchíade": "Melchiade",
    "Telésphorum": "Télesphore", "Hygínum": "Hygin", "Lúcium": "Luce", "Anicétum": "Anicet",
    "Urbánum": "Urbain", "Urbáni": "Urbain", "Urbáno": "Urbain", "Eleuthérium": "Éleuthère",
    "Joánnem": "Jean", "Felícem": "Félix", "Silvérium": "Silvère", "Pium": "Pie",
    "Anaclétum": "Anaclet", "Stéphanum": "Étienne", "Zephyrínum": "Zéphyrin", "Linum": "Lin",
    "Evarístum": "Évariste", "Martínum": "Martin", "Cleméntem": "Clément", "Melchíadem": "Melchiade",
    "Leónem": "Léon", "Sotérem": "Soter", "Cajum": "Caïus", "Cletum": "Clet", "Marcellínum": "Marcellin",
    "Eusébio": "Eusèbe", "Antónius": "Antoine", "Polycárpo": "Polycarpe", "Blásio": "Blaise",
    "Romuáldus": "Romuald", "Petrus": "Pierre", "Petro": "Pierre", "Gregório": "Grégoire",
    "Gervásio": "Gervais", "Protásio": "Protais", "Guliélmius": "Guillaume", "Januário": "Janvier",
    "Hilárion": "Hilarion", "Vitále": "Vital", "Agrícola": "Agricola", "Canúto": "Canut",
    "Emerentiánæ": "Émérentienne", "Emerentiána": "Émérentienne", "Dorótheæ": "Dorothée",
    "Doróthea": "Dorothée", "Christínæ": "Christine", "Christína": "Christine",
    "Timotheo": "Timothée", "Timothei": "Timothée", "Joánnes Chrysóstomus": "Jean Chrysostome",
    "Joánnis Chrysóstomi": "Jean Chrysostome", "Francíscus": "François", "Francísci": "François",
    "Francísco": "François", "Ignátio": "Ignace", "Andréa": "André", "Tito": "Tite",
    "Simeóne": "Siméon", "Simeónis": "Siméon", "Thomas": "Thomas", "Thomæ": "Thomas",
    "Patrício": "Patrice", "Toríbio": "Turibe", "Antoníno": "Antonin", "Bonifátio": "Boniface",
    "Ubáldo": "Ubald", "Joánnis Baptístæ": "Jean-Baptiste", "Norbérto": "Norbert",
    "Paulíno": "Paulin", "Symphorósa": "Symphorose", "Vincéntio": "Vincent", "Lauréntius": "Laurent",
    "Lauréntio": "Laurent", "Libório": "Libère", "Libórii": "Libère", "Bernárdus": "Bernard",
    "Bernárdi": "Bernard", "Philíppo": "Philippe", "Augustínus": "Augustin", "Augustíni": "Augustin",
    "Nicoláo": "Nicolas", "Cypriáno": "Cyprien", "Justína": "Justine", "Plácido": "Placide",
    "Brunóne": "Bruno", "Ursula": "Ursule", "Antónii Maríæ": "Antoine-Marie", "Matthǽi": "Matthieu",
    "Matthíæ": "Matthias", "Jacóbi": "Jacques", "Sabínæ": "Sabine", "Bonaventúræ": "Bonaventure",
    "Benedíctus": "Benoît", "Maurus": "Maur", "Fabiáno": "Fabien", "Fabiáni": "Fabien",
    "Sebastiáno": "Sébastien", "Sebastiáni": "Sébastien", "Tryphóne": "Tryphon", "Respício": "Respice",
    "Nympha": "Nymphe", "Dídaco": "Didace", "Carólo": "Charles", "Petrus Chrysólogus": "Pierre Chrysologue",
    "Petri Chrysólogi": "Pierre Chrysologue",
}

UNNAMED = Counter()       # Latin names a Common's pattern caught but no French was found for

HAND = {fold(k): v for k, v in {
    "!Sequentia dicitur usque ad Sabbatum in Albis inclusive.":
        "!La Séquence se dit jusqu’au Samedi in Albis inclusivement.",
    "In Vigilia Paschali antiphona ad Offertorium non dicitur.":
        "À la Vigile pascale, on ne dit pas d’antienne à l’Offertoire.",
    # fix_mass_prayers.PROPER (St Rita's from DO's French Office)
    "Deus, qui sanctæ Ritæ tantam grátiam conférre dignátus es, ut inimícos dilígeret et in corde ac fronte caritátis et passiónis tuæ signa portáret: da nobis, quǽsumus, ejus intercessióne et méritis; inimícis nostris sic párcere et passiónis tuæ dolóres contemplári, ut promíssa mítibus ac lugéntibus prǽmia consequámur:":
        "Dieu, qui avez daigné accorder à sainte Rita une telle grâce qu’elle a aimé ses ennemis et porté dans son cœur et sur son front les signes de votre charité et de votre passion : accordez-nous, nous vous en prions, par son intercession et ses mérites, de pardonner ainsi à nos ennemis et de contempler les douleurs de votre Passion, afin que nous obtenions les récompenses promises aux doux et à ceux qui pleurent :",
    "Súscipe, Dómine, múnera, quæ in ejus tibi sollemnitáte deférimus: cujus nos confídimus patrocínio liberári.":
        "Recevez, Seigneur, les offrandes que nous vous présentons en la solennité de celui par le patronage duquel nous espérons être exempts de tout péril.",
    "Múnera tibi, Dómine, dicáta sanctífica: et, intercedénte beáto Joánne Apóstolo tuo, per éadem nos placátus inténde.":
        "Sanctifiez, Seigneur, les dons qui vous sont consacrés et, par l’intercession du bienheureux Jean, votre Apôtre, regardez-nous favorablement à cause d’eux.",
    # lines the import's nearest match gave another verse's French
    "V. Qui ad justítiam erúdiunt multos quasi stellæ in perpétuas æternitátes. Allelúja.":
        "V. Ceux qui en auront instruit plusieurs dans la justice luiront comme des étoiles dans des éternités sans fin. Alléluia.",
    "V. Amávit eum Dóminus et ornávit eum: stolam glóriæ índuit eum. Allelúja.":
        "V. Le Seigneur l’a aimé et l’a orné. Il l’a revêtu d’une robe de gloire. Alléluia.",
    "Hóstias, quǽsumus, Dómine, placátus assúme: quas et pro renatórum expiatióne peccáti deférimus, et pro acceleratióne cœléstis auxílii.":
        "Daignez, Seigneur, accueillir favorablement ce sacrifice que nous vous offrons pour expier les péchés de ceux qui viennent de naître à une vie nouvelle, et pour hâter les secours du ciel.",
}.items()}


def heading_fr(lat):
    """The French form of a reading's title line, as the hand missals print it."""
    k = fold(lat)
    cross = " + " if "+" in lat else " "
    m = re.fullmatch(r"(sequentia|initium|lectio) sancti euangeli\w* secundum (\w+)", k)
    if m and m.group(2) in BOOKS:
        first = {"sequentia": "Suite", "initium": "Commencement", "lectio": "Lecture"}[m.group(1)]
        return f"{first}{cross}du saint Évangile selon saint {BOOKS[m.group(2)]}"
    m = re.fullmatch(r"passio domini nostri iesu christi secundum (\w+)", k)
    if m and m.group(1) in BOOKS:
        return f"Passion de notre Seigneur Jésus-Christ selon saint {BOOKS[m.group(1)]}"
    m = re.fullmatch(r"lectio (?:prima )?epistolae (?:beati|sancti) pauli apostoli ad (\w+)", k)
    if m and m.group(1) in PAUL:
        return f"Lecture de l’Épître du bienheureux Apôtre Paul {PAUL[m.group(1)]}"
    m = re.fullmatch(r"lectio epistolae beati (\w+) apostoli", k)
    if m and m.group(1) in APOSTLES:
        return f"Lecture de l’Épître du bienheureux Apôtre {APOSTLES[m.group(1)]}"
    if k == "lectio actuum apostolorum":
        return "Lecture des Actes des Apôtres"
    m = re.fullmatch(r"lectio libri (.+)", k)
    if m and m.group(1) in LIBRI:
        return f"Lecture {LIBRI[m.group(1)]}"
    m = re.fullmatch(r"lectio (\w+) prophetae", k)
    if m and m.group(1) in PROPHETS:
        return f"Lecture du Prophète {PROPHETS[m.group(1)]}"
    return None


def missal(dumps, do=None):
    dumps = Path(dumps)
    variants = {}          # folded Latin line -> Counter of the French lines DO pairs with it
    by_file = {}           # DO file ("tempora/adv1-0") -> {folded Latin line: French line}

    def add(lat, fr, file=None):
        k = fold(lat)
        f = tidy(MARK_RE.sub("", fr.strip()))
        if len(k) < 3 or not f or fold(f) == k:
            return
        if f.startswith(("$", "&", "!", "@", "#")):
            return
        def put(k, f):
            variants.setdefault(k, Counter())[f] += 1
            if file:
                by_file.setdefault(file, {}).setdefault(k, f)
        put(k, f)
        # the same line without its Paschal alleluias
        bl, nl = strip_alleluia(lat.strip())
        if nl and len(fold(bl)) >= 3:
            put(fold(bl), strip_alleluia(f)[0])

    def lines_of(text, prayers, side, rubrics=False):
        """A section's lines as the apps carry them: references dropped,
        the Gloria Patri and the conclusions written out on one line."""
        out = []
        for l in (text or "").split("\n"):
            l = l.strip()
            if not l or l == "_" or (l.startswith("!") and not rubrics):
                continue
            if out and ALLELUIA_ONLY.match(l) and not out[-1].startswith(("$", "&", "!")):
                out[-1] = out[-1].rstrip() + " " + l   # "Allelúja, allelúja." closes the line before it
                continue
            m = re.match(r"^[$&]\s*(.+?)\s*$", l)
            if m:
                p = prayers.get(m.group(1)) or prayers.get(m.group(1).replace("Per eundem", "Per eumdem"))
                t = (p or {}).get(side)
                if not t:
                    out.append(l)
                    continue
                out.append(" ".join(MARK_RE.sub("", x.strip()) for x in t.split("\n") if x.strip()))
                continue
            out.append(l)
        return out

    stats = Counter()
    rubrics_fr = {}
    for rite in RITES:
        p = dumps / f"missa_{rite}.json"
        if not p.exists():
            sys.exit(f"missing {p} (dodump.pl ... missa with DO_LANG2=Francais)")
        d = load(p)
        prayers = d.get("Ordo/Prayers.txt", {})
        for name, sec in prayers.items():
            if sec.get("lat") and sec.get("eng"):
                join = lambda t: " ".join(MARK_RE.sub("", x.strip()) for x in t.split("\n") if x.strip())
                add(join(sec["lat"]), join(sec["eng"]))
                add(re.sub(r"\s*Amen\.?$", "", join(sec["lat"])), re.sub(r"\s*(Ainsi soit-il|Amen)\.?$", "", join(sec["eng"])))
        for f, secs in d.items():
            if f.startswith("Ordo/"):
                continue
            for name, sec in secs.items():
                if name in ("Rank", "Rule", "Officium") or not isinstance(sec, dict):
                    continue
                lat, fr = sec.get("lat"), sec.get("eng")
                if not lat or not fr or lat == fr:
                    continue
                ll, fl = lines_of(lat, prayers, "lat"), lines_of(fr, prayers, "eng")
                if len(ll) != len(fl):
                    # rubric lines "(…)" and "/:…:/" may sit on one side only
                    drop = lambda xs: [x for x in xs if not re.match(r"^(\(.*\)|/:.*:/|#.*)$", x)]
                    ll, fl = drop(ll), drop(fl)
                if len(ll) != len(fl):
                    stats["sections misaligned"] += 1
                    continue
                stats["sections paired"] += 1
                for a, b in zip(ll, fl):
                    add(a, b, f.lower()[:-4])
                # the rubric lines ("!…"), where the two sides carry the same number
                rl, rf = lines_of(lat, prayers, "lat", True), lines_of(fr, prayers, "eng", True)
                if len(rl) == len(rf):
                    for a, b in zip(rl, rf):
                        if a.startswith("!") and b.startswith("!") and fold(a[1:]) != fold(b[1:]) \
                                and not re.match(r"^!\s*\d?\s?[A-Z][a-z]+\.?\s*\d+[:,]", a):
                            rubrics_fr.setdefault("!" + fold(a[1:]), "!" + tidy(b[1:]))

    # DO's own rendering of each saint's collect, secret and postcommunion
    # (dodump.pl missaprayers: the Common's text with the name filled in),
    # which is what the corrected Latin of missal_sanctoral.json now is.
    for mp in (dumps / "missaprayers_1962.json", dumps / "missaparts_1962.json"):
        if not mp.exists():
            continue
        for f, secs in load(mp).items():
            for sec in secs.values():
                if not isinstance(sec, dict):
                    continue
                lat, fr = sec.get("lat"), sec.get("eng")
                if not lat or not fr:
                    continue
                ll, fl = lines_of(lat, prayers, "lat"), lines_of(fr, prayers, "eng")
                if len(ll) == len(fl):
                    stats["rendered prayers paired"] += 1
                    for a, b in zip(ll, fl):
                        add(re.sub(r"^v\.\s*", "", a), re.sub(r"^v\.\s*", "", b), f.lower()[:-4])

    # The Commons of the Saints: DO's Mass draws them from the Office's
    # Commune files (horas/<lang>/Commune), which the dumps above do not
    # carry; their sections are paired header by header.
    if do:
        def sections_of(path):
            out, cur = {}, None
            for l in path.read_text(encoding="utf-8", errors="replace").split("\n"):
                m = re.match(r"^\[([^\]]+)\]\s*(\(.*\))?\s*$", l)
                if m:
                    cur = l.strip()
                    out[cur] = []
                elif cur:
                    out[cur].append(l)
            return {k: "\n".join(v) for k, v in out.items()}
        www = Path(do) / "web/www/horas"
        for lat_p in sorted((www / "Latin" / "Commune").glob("*.txt")):
            fr_p = www / "Francais" / "Commune" / lat_p.name
            if not fr_p.exists():
                continue
            ls, fs = sections_of(lat_p), sections_of(fr_p)
            for head, lat in ls.items():
                fr = fs.get(head)
                if not fr or head.startswith(("[Rank", "[Rule", "[Officium", "[Name")):
                    continue
                ll, fl = lines_of(lat, prayers, "lat"), lines_of(fr, prayers, "eng")
                if len(ll) != len(fl):
                    drop = lambda xs: [x for x in xs if not re.match(r"^(\(.*\)|/:.*:/|#.*|@.*)$", x)]
                    ll, fl = drop(ll), drop(fl)
                if len(ll) != len(fl):
                    stats["commune sections misaligned"] += 1
                    continue
                stats["commune sections paired"] += 1
                for a, b in zip(ll, fl):
                    if not a.startswith("@"):
                        add(a, b, "commune/" + lat_p.stem.lower())

    # One French line per Latin line: DO's commonest pairing. A short line
    # ("eórum.") means different things in different places, so it is taken
    # only from the day's own file or when DO never pairs it otherwise.
    linemap = {}
    for k, c in variants.items():
        if len(c) == 1 or len(k) >= 25:
            linemap[k] = c.most_common(1)[0][0]
    print("missal: conflicting line pairs", sum(1 for c in variants.values() if len(c) > 1),
          "of which too short to trust", sum(1 for k, c in variants.items() if len(c) > 1 and len(k) < 25))

    # The Commons' prayers carry "N." for the saint; the Masses that borrow
    # them name the saint ("beáti Ignátii Mártyris"). Each such Latin line
    # becomes a pattern, the name is read off the Mass's line and put in
    # the French in place of its "N." (office_names_fr.json gives the
    # French of every Latin case form, NAMES_EXTRA the few it lacks).
    names_fr = {fold(k): v for k, v in load(FR / "office_names_fr.json").items()}
    names_fr.update({fold(k): v for k, v in NAMES_EXTRA.items()})
    names_fr["n"] = "N."          # a Common's own prayer keeps its "N."
    templates = {}
    for k in linemap:
        if re.search(r"(^| )n( |$)", k) and len(k) >= 25:
            words = k.split(" ")
            rx = re.compile("^" + " ".join("(.+?)" if w == "n" else re.escape(w) for w in words) + "$")
            templates.setdefault(" ".join(words[:2]), []).append((rx, linemap[k]))

    def by_template(l):
        fl = fold(l)
        for rx, fr in templates.get(" ".join(fl.split(" ")[:2]), []):
            m = rx.match(fl)
            if not m:
                continue
            got = [names_fr.get(g) for g in m.groups()]
            if None in got or fr.count("N.") != len(got):
                UNNAMED.update(g for g, x in zip(m.groups(), got) if x is None)
                continue
            for g in got:
                fr = re.sub(r"\bN\.", g, fr, count=1)
            return fr
        return None

    def files_for(key):
        """The DO files a missal key was imported from, most specific first."""
        k = key.lower()
        if re.match(r"^\d\d-\d\d", k):
            return ["sancti/" + k, "sancti/" + k[:5]]
        if re.match(r"^c\d", k):
            return ["commune/" + k]
        return ["tempora/" + k, "tempora/" + re.sub(r"[a-z]+$", "", k)]

    def lookup(l, key):
        l = l.strip()
        if l == "_" or re.fullmatch(r"\(.*\)", l):
            return l                      # a stanza break, a rubric condition
        if fold(l) in HAND:
            return HAND[fold(l)]
        if l.startswith("!"):
            return rubrics_fr.get("!" + fold(l[1:]))
        if ALLELUIA_ONLY.match(l) or re.fullmatch(r"Amen\.(\s*[Aa]llel[uú][ij]a\.?)*", l):
            return tidy(l)                # the same words in French
        # a data artifact: "… Amen. eiusdem" flags the ejúsdem (same Spirit) conclusion
        if l.endswith(" eiusdem"):
            l = l[:-len(" eiusdem")].replace("in unitáte Spíritus Sancti", "in unitáte ejúsdem Spíritus Sancti")
        def find(k):
            for f in files_for(key):
                if k in by_file.get(f, {}):
                    return by_file[f][k]
            return linemap.get(k)
        f = heading_fr(l) or find(fold(l)) or by_template(l)    # one form for every title line
        if f is None:
            base, n = strip_alleluia(l)
            b = find(fold(base)) if n else None
            if b:
                f = b.rstrip(" ,;:")
                if f[-1:] not in ".!?»":
                    f += "."
                tail = ", ".join(["Alléluia"] + ["alléluia"] * (n - 1)) + "."
                f += f" ({tail})" if l.rstrip().endswith(")") else " " + tail
        return f

    def translate(lat, key):
        out, bad = [], []
        lines = lat.split("\n")
        for i, l in enumerate(lines):
            if not l.strip():
                out.append("")
                continue
            f = lookup(l, key)
            # "(sed post Septuagesimam dicitur)" + the antiphon's last word
            # again, to be said without the alleluia: the French line's own
            if f is None and i >= 2 and re.fullmatch(r"\(sed post Septuagesimam \w+\)", lines[i - 1].strip()) \
                    and len(l.split()) == 1 and strip_alleluia(out[i - 2])[1]:
                f = strip_alleluia(out[i - 2])[0].rstrip(" ,;:.!").split(" ")[-1] + "."
            if f is None:
                bad.append(l)
                out.append(l)
                continue
            m = re.match(r"^(V\.|R\.|℣\.|℟\.)\s*", l.strip())
            out.append((m.group(1) + " " if m else "") + f)
        if bad:
            return None, bad
        return "\n".join(out), None

    propers, readings = {}, {}
    cov, miss = Counter(), Counter()
    examples = []
    # Whole sections, for a part whose lines DO divides otherwise (the
    # Dies iræ in stanzas, Good Friday's chants): DO's French of a section
    # whose Latin has the same words, taken entire. Each language is shown
    # as its own block, so the French need not follow the Latin line for line.
    def section_words(t, side):
        ls = [re.sub(r"^[vV]\.\s*", "", x) for x in lines_of(t, prayers, side) if x != "_"]
        if ls and re.match(r"^(L[eé]ctio|Lesson|Lecture|Sequ[eé]ntia|Suite|In[ií]tium|Commencement)\b", ls[0]):
            ls = ls[1:]
        return fold(" ".join(ls))
    whole = {}
    sources = [dumps / f"missa_{r}.json" for r in RITES] + [dumps / "missaparts_1962.json"]
    for src in sources:
        if not src.exists():
            continue
        for f, secs in load(src).items():
            for sec in secs.values():
                if isinstance(sec, dict) and sec.get("lat") and sec.get("eng") and sec["lat"] != sec["eng"]:
                    fr_lines = [tidy(MARK_RE.sub("", x)) for x in lines_of(sec["eng"], prayers, "eng") if x != "_" and not x.startswith(("$", "&", "@"))]
                    if fr_lines:
                        whole.setdefault(section_words(sec["lat"], "lat"), "\n".join(fr_lines))
    # The Requiem: DO's Latin Mass of the dead sits in the Office's Common
    # (horas/Latin/Commune/C9), its French in missa/Francais/Votive.
    if do:
        www = Path(do) / "web/www"
        def secs_of(path):
            out, cur = {}, None
            for l in path.read_text(encoding="utf-8", errors="replace").split("\n"):
                m = re.match(r"^\[([^\]]+)\]\s*$", l.strip())
                if m:
                    cur = m.group(1).strip()
                    out[cur] = []
                elif cur:
                    out[cur].append(l)
            return {k: "\n".join(v) for k, v in out.items()}
        lat_c9 = www / "horas/Latin/Commune/C9.txt"
        fr_def = www / "missa/Francais/Votive/Defunctorum.txt"
        if lat_c9.exists() and fr_def.exists():
            ls, fs = secs_of(lat_c9), secs_of(fr_def)
            for name in ("Introitus", "Graduale", "Tractus", "Sequentia", "Offertorium", "Communio"):
                if ls.get(name) and fs.get(name):
                    fr_lines = [tidy(MARK_RE.sub("", x)) for x in lines_of(fs[name], prayers, "eng") if x != "_" and not x.startswith(("$", "&", "@"))]
                    whole.setdefault(section_words(ls[name], "lat"), "\n".join(fr_lines))

    for name in ("missal_tempora.json", "missal_sanctoral.json"):
        for key, entry in load(ASSETS / name).items():
            for field in ("introitus", "oratio", "lectio", "graduale", "gradualeP", "tractus", "sequentia",
                          "evangelium", "offertorium", "secreta", "communio", "postcommunio"):
                v = entry.get(field)
                if not isinstance(v, dict) or not v.get("lat"):
                    continue
                fr, bad = translate(v["lat"], key)
                if fr is None:
                    w = section_words(v["lat"], "lat")
                    if w in whole:
                        fr = re.sub(r"(?m)^[vV]\.\s*", "", whole[w]) if not re.search(r"(?m)^V\.", v["lat"]) else whole[w]
                        fl, ll = fr.split("\n"), v["lat"].split("\n")
                        if len(fl) > len(ll):
                            # the reading's body in one line, as the Latin has it
                            fl = fl[:len(ll) - 1] + [" ".join(fl[len(ll) - 1:])]
                        if len(fl) == len(ll) or field == "sequentia":
                            fr = "\n".join(fl)
                            stats["whole sections"] += 1
                        else:
                            fr = None
                if fr is None:
                    miss[field] += 1
                    for b in bad:
                        examples.append((key, field, b))
                    continue
                cov[field] += 1
                (readings if field in ("lectio", "evangelium") else propers).setdefault(key, {})[field] = fr
    # whole fields DO has no line-for-line French for (Holy Week, a few
    # saints): composed from DO's French or translated, kept by hand
    fx = FR / "missal_fixes_fr.json"
    if fx.exists():
        for key, fields in load(fx).items():
            for field, text in fields.items():
                (readings if field in ("lectio", "evangelium") else propers).setdefault(key, {})[field] = text
    dump(propers, "missal_propers_fr.json")
    dump(readings, "missal_readings_fr.json")
    print("missal: line pairs", len(linemap), dict(stats))
    for f in sorted(set(cov) | set(miss)):
        print(f"  {f}: {cov[f]} in French, {miss[f]} left in English")
    if "--report" in sys.argv:
        for n, c in UNNAMED.most_common():
            print("   unnamed", n, c, sep=" | ")
        for e in examples:
            print("   missing", *e, sep=" | ")


# ------------------------------------------------------- Marian antiphons

MARIAN = {  # the app's antiphon -> DO's section of Psalterium/Mariaant.txt, and its French title
    "alma": ("Advent", "Sainte Mère du Rédempteur"),
    "ave": ("Quadragesimae", "Salut, Reine des cieux"),
    "regina": ("Paschalis", "Reine du ciel"),
    "salve": ("Postpentecost", "Salut, ô Reine"),
}


def marian(dumps):
    """marian_antiphons_fr.json from DO's Mariaant.txt (psalt.json): the
    antiphon as one paragraph, its versicle and its collect."""
    d = load(Path(dumps) / "psalt.json")
    fr, prayers = d["Francais/Mariaant.txt"], d["Francais/Common/Prayers.txt"]

    def parse(sec):
        blocks, cur = [], []
        for l in fr[sec].split("\n"):
            l = tidy(re.sub(r"\{:[^}]*:\}", "", l)).replace("{::}", "").replace("~", "").strip()
            if l == "_" or not l:
                if cur:
                    blocks.append(cur)
                cur = []
            else:
                cur.append(l)
        if cur:
            blocks.append(cur)
        vi = next(i for i, b in enumerate(blocks) if b[0].startswith("V."))
        # verse by verse, as DO sets it
        body = "\n".join(MARK_RE.sub("", l).strip() for b in blocks[:vi] for l in b)
        v = " ".join(re.sub(r"^V\.\s*", "℣. ", re.sub(r"^R\.\s*", "℟. ", l)) for l in blocks[vi])
        collect = []
        for l in blocks[vi + 1]:
            m = re.match(r"^[$&]\s*(.+?)\s*$", l)
            if m and m.group(1).startswith("Oremus"):
                continue
            if m:
                t = prayers.get(m.group(1), "")
                collect.append(" ".join(MARK_RE.sub("", x.strip()) for x in t.split("\n") if x.strip()))
            else:
                collect.append(MARK_RE.sub("", l))
        collect = " ".join(collect).replace("J.-C. N.-S.", "Jésus-Christ notre Seigneur.")
        return re.sub(r"[ \t]{2,}", " ", body), re.sub(r"\s{2,}", " ", v), re.sub(r"\s{2,}", " ", collect)

    out = {}
    for slug, (sec, title) in MARIAN.items():
        body, v, collect = parse(sec)
        out[slug] = {"title_fr": title, "body_fr": body, "versicle_fr": v, "collect_fr": collect}
    _, v, collect = parse("Nativiti")
    out["alma"]["versicle_fr_christmas"], out["alma"]["collect_fr_christmas"] = v, collect
    dump(out, "marian_antiphons_fr.json")
    print("marian antiphons:", len(out))


# ------------------------------------------------------------------ names

def first_section(path, name):
    """The lines of a DO file's first unconditional [name] section."""
    out, on = [], False
    for l in path.read_text(encoding="utf-8", errors="replace").split("\n"):
        m = re.match(r"^\[([^\]]+)\]\s*(\(.*\))?\s*$", l)
        if m:
            if on:
                break
            on = m.group(1) == name and not m.group(2)
            continue
        if on and l.strip():
            out.append(l.strip())
    return out


def clean_title(t):
    t = tidy(t).rstrip(". ")
    t = re.sub(r"\bSt\b\.?(?=\s)", "S.", t).replace("Evêque", "Évêque").replace("Eglise", "Église")
    return t


def names(do):
    """ordo_names_fr.json (the calendar's Latin titles -> French, from the
    [Officium] line of DO's French Office and Mass files) and
    office_names_fr.json (the saints' names the collects fill in for "N.",
    every Latin case form -> the French name, from the [Name] sections)."""
    www = Path(do) / "web/www"
    titles, saints = {}, {}
    for tree in ("horas", "missa"):
        for d in ("Tempora", "Sancti", "Commune"):
            for lat in sorted((www / tree / "Latin" / d).glob("*.txt")):
                fr = www / tree / "Francais" / d / lat.name
                if not fr.exists():
                    continue
                a, b = first_section(lat, "Officium"), first_section(fr, "Officium")
                if a and b and fold(a[0]) != fold(b[0]):
                    titles.setdefault(fold(a[0]), clean_title(b[0]))
                if tree == "horas":
                    na, nb = first_section(lat, "Name"), first_section(fr, "Name")
                    if na and nb:
                        name = tidy(nb[0].split("=")[-1])
                        for l in na:
                            if l.startswith("("):
                                continue          # a rubric condition, not a name
                            form = unicodedata.normalize("NFC", l.split("=")[-1].strip())
                            if form:
                                saints.setdefault(form, name)
    src = load(ASSETS / "ordo_names_en.json")
    out, missing = {}, []
    for k in src:
        # "… post Octavam Pentecostes II. Augusti": the ordo tags the day with
        # its Scripture week, which the title itself does not carry
        base = re.sub(r"\s+[IVX]+\.\s+\w+$", "", k)
        f = titles.get(fold(k)) or titles.get(fold(base)) or titles.get(fold(re.sub(r"^De ", "", base)))
        if f:
            out[k] = f
        else:
            missing.append(k)
    # titles DO's French lacks or leaves in Latin, in the file's own style
    # (french-translation/ordo_names_fixes_fr.json, kept by hand)
    fx = FR / "ordo_names_fixes_fr.json"
    if fx.exists():
        for k, v in load(fx).items():
            if k in src:
                out[k] = v
                if k in missing:
                    missing.remove(k)
    dump(out, "ordo_names_fr.json")
    dump(saints, "office_names_fr.json")
    dump(sorted(missing), "ordo_names_missing_fr.json")
    print(f"names: {len(out)} of {len(src)} calendar titles in French ({len(missing)} left, listed in ordo_names_missing_fr.json); {len(saints)} saints' name forms")


# ------------------------------------------------------------- martyrology

MONTHS_FR = "janvier|février|mars|avril|mai|juin|juillet|août|septembre|octobre|novembre|décembre"


def all_sections(path):
    """{(name, condition): text} of a DO file, in order."""
    out, name = {}, None
    if not path.exists():
        return out
    for l in path.read_text(encoding="utf-8", errors="replace").split("\n"):
        m = re.match(r"^\[([^\]]+)\]\s*(\(.*\))?\s*$", l)
        if m:
            name = (m.group(1), m.group(2) or "")
            out[name] = []
            continue
        if name and l.strip():
            out[name].append(l.strip())
    return {k: " ".join(v) for k, v in out.items()}


def martyrology(do):
    """martyrology_fr.json: DO's French Martyrology, entry for entry.

    DO keys each entry of a day by a name ("[Chrysogoni]") in the Latin and
    in the French file alike: an entry of martyrology.json is found by its
    Latin among the day's Latin sections, and takes the French section of
    the same name. french-translation/martyrology_fixes_fr.json supplies
    the few entries DO's French lacks ({"MM-DD": {"<entry index>": text}}).
    A day is written only when every entry has its French, as the apps
    require."""
    import difflib
    base = Path(do) / "web/www/horas"
    src = load(ASSETS / "martyrology.json")
    fx = FR / "martyrology_fixes_fr.json"
    fixes = load(fx) if fx.exists() else {}
    days, missing, stats = {}, [], Counter()
    for day, d in src["days"].items():
        lat = all_sections(base / "Latin" / "Martyrologium" / f"{day}.txt")
        fr = {k: v for (k, cond), v in all_sections(base / "Francais" / "Martyrologium" / f"{day}.txt").items() if not cond}
        index = {}
        for (k, cond), text in lat.items():
            if k not in ("Titulus", "Martyrologium"):
                index.setdefault(fold(text), k)
        entries = []
        for i, e in enumerate(d["entries"]):
            f = fold(e["lat"])
            k = index.get(f)
            if k is None and index:     # the same entry in a slightly different edition
                best = max(index, key=lambda x: difflib.SequenceMatcher(None, f, x).quick_ratio())
                if difflib.SequenceMatcher(None, f, best).ratio() > 0.85:
                    k = index[best]
            t = (fixes.get(day) or {}).get(str(i)) or (tidy(fr[k]) if k in fr and fold(fr[k]) != f else None)
            if t is None:
                missing.append({"day": day, "index": i, "lat": e["lat"], "eng": e["eng"]})
            # DO's inline rubrics "/:…:/" are not part of the reading
            # (written "/:…:/", and here and there ":/…:/")
            if t:
                t = re.sub(r"\s*(?:/:|:/)[^/]*?(?::/|/:)\s*", " ", t)
                # DO's French adds modern glosses the Martyrology does not have
                # ("(aujourd’hui Kayseri en Turquie)", "[en l’an 309]"); the
                # day a Roman date falls on ("(14 décembre)") is kept.
                if "(" not in e["lat"]:
                    t = re.sub(r"\s*\((?!\s*(?:le\s+)?\d{1,2}(?:er)?\s+(?:%s)\s*\))[^)]*\)" % MONTHS_FR, "", t)
                t = re.sub(r"\s*\[[^\]]*\]", "", t)
                t = re.sub(r"\s{2,}", " ", re.sub(r"\s+([,.;])", r"\1", t)).strip()
                if t and t[-1] not in ".!?»)" and e["lat"].rstrip()[-1:] == ".":
                    t = t.rstrip(",;: ") + "."      # a gloss stood before the full stop
            entries.append(t or None)
            stats["entries" if t else "missing"] += 1
        if all(entries):
            days[day] = {"entries_fr": entries}
    mob = {k.lower(): tidy(v) for (k, cond), v in all_sections(base / "Francais" / "Martyrologium" / "Mobile.txt").items() if not cond}
    mobile = {k: mob[k] for k in src["mobile"] if k in mob}
    dump({"days": days, "mobile": mobile}, "martyrology_fr.json")
    dump(missing, "martyrology_missing_fr.json")
    print(f"martyrology: {stats['entries']} of {stats['entries'] + stats['missing']} entries, "
          f"{len(days)} of {len(src['days'])} days complete, {len(mobile)} of {len(src['mobile'])} movable announcements")


def main():
    do, dumps = arg("--do"), arg("--dumps")
    steps = [a for a in sys.argv[1:] if a in ("psalter", "missal", "marian", "names", "martyrology")] or ["psalter", "missal", "marian", "names", "martyrology"]
    if "psalter" in steps:
        if not do:
            sys.exit("--do DO_ROOT is needed for the psalter")
        psalter(do)
    if "missal" in steps:
        if not dumps:
            sys.exit("--dumps DIR is needed for the missal")
        missal(dumps, do)
    if "marian" in steps:
        marian(dumps)
    if "names" in steps:
        names(do)
    if "martyrology" in steps:
        martyrology(do)


if __name__ == "__main__":
    main()
