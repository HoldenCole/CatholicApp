#!/usr/bin/env python3
"""Build spanish-translation/missal_readings_es.json — the Mass Scripture
readings (Lectio / Evangelium) in Spanish, from the public-domain
Petisco/Torres Amat Bible (translated from the Vulgate, 1798/1825).

Sources (kept OUTSIDE the repo, passed by path):
  --bible  a theWord .ont module of the Torres Amat text: one verse per
           line in KJV order (31,102 lines, 66 books), UTF-8 with BOM.
  --kjv    getbible.net v2 kjv.json, used ONLY for its versification
           structure (verse counts per chapter) to index the .ont lines.

Each reading is composed exactly the way a hand missal does it:
  <intro line>            translated from the Latin heading
                          ("Léctio Epístolæ beáti Pauli Apóstoli ad
                          Romános" -> "Lección de la Epístola del
                          Apóstol San Pablo a los Romanos")
  <incipit> <verses...>   the liturgical incipit from the Latin body
                          ("Fratres:" -> "Hermanos:", "In illo témpore:"
                          -> "En aquel tiempo:") followed by the Torres
                          Amat text of the verses in the entry's ref.

A reading is only emitted when every part resolves: known book, verses
in range, intro parsed. Days whose refs reach the deuterocanonical books
(Wisdom, Sirach, Tobit, Judith, Baruch, Maccabees, Daniel 3:24+/13/14,
Esther 10+), which the 66-book module lacks, take their body from
spanish-translation/readings_deutero_es.json — our own tier-2
translations from the Vulgate, keyed by ref (28 pericopes cover every
deutero reading in the missal).

Run:  python3 scripts/import_spanish_readings.py \
          --bible <torres_amat.ont> --kjv <kjv.json>
      python3 scripts/sync_spanish_assets.py
"""
import json
import re
import sys
import unicodedata
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "spanish-translation" / "missal_readings_es.json"


def nfc(s):
    return unicodedata.normalize("NFC", s)


def arg(flag, default=None):
    if flag in sys.argv:
        return sys.argv[sys.argv.index(flag) + 1]
    return default


# ---- Book aliases: missal ref abbreviation -> KJV book name (or DEUTERO) --
DEUTERO = "DEUTERO"
BOOKS = {
    "Gen": "Genesis", "Exod": "Exodus", "Ex": "Exodus", "Lev": "Leviticus",
    "Num": "Numbers", "Deut": "Deuteronomy", "Jos": "Joshua",
    "1 Reg": "1 Samuel", "2 Reg": "2 Samuel",
    "3 Reg": "1 Kings", "4 Reg": "2 Kings",
    "1 Par": "1 Chronicles", "2 Par": "2 Chronicles",
    "1 Esd": "Ezra", "Neh": "Nehemiah", "2 Esd": "Nehemiah",
    "Esth": "Esther",   # chapters > 10 are deuterocanonical (handled below)
    "Job": "Job", "Prov": "Proverbs", "Eccles": "Ecclesiastes",
    "Cant": "Song of Songs",
    "Is": "Isaiah", "Isa": "Isaiah", "Jer": "Jeremiah",
    "Lam": "Lamentations", "Ezech": "Ezekiel",
    "Dan": "Daniel",    # chapters 13-14 and 3:24-90 are deuterocanonical
    "Os": "Hosea", "Osee": "Hosea", "Joel": "Joel", "Joël": "Joel",
    "Amos": "Amos", "Abd": "Obadiah", "Jonæ": "Jonah", "Jon": "Jonah",
    "Mich": "Micah", "Nah": "Nahum", "Hab": "Habakkuk", "Soph": "Zephaniah",
    "Agg": "Haggai", "Zach": "Zechariah", "Malach": "Malachi",
    "Mal": "Malachi",
    "Matt": "Matthew", "Mt": "Matthew", "Marc": "Mark", "Mc": "Mark",
    "Luc": "Luke", "Lc": "Luke",
    "Joann": "John", "Joannes": "John", "John": "John", "Jo": "John",
    "Act": "Acts", "Acts": "Acts", "Rom": "Romans",
    "1 Cor": "1 Corinthians", "2 Cor": "2 Corinthians",
    "Gal": "Galatians", "Eph": "Ephesians", "Ephes": "Ephesians",
    "Phil": "Philippians", "Philipp": "Philippians",
    "Col": "Colossians", "Coloss": "Colossians",
    "1 Thess": "1 Thessalonians", "2 Thess": "2 Thessalonians",
    "1 Tim": "1 Timothy", "1. Tim": "1 Timothy", "2 Tim": "2 Timothy",
    "Tit": "Titus", "Philem": "Philemon",
    "Hebr": "Hebrews", "Heb": "Hebrews",
    "Jac": "James", "Jas": "James", "Jc": "James",
    "1 Pet": "1 Peter", "1 Petr": "1 Peter", "1 Petri": "1 Peter",
    "2 Pet": "2 Peter", "2 Petr": "2 Peter", "2 Petri": "2 Peter",
    "1 Joann": "1 John", "1 Joannes": "1 John", "1 Joannnes": "1 John",
    "1 John": "1 John", "2 Joann": "2 John", "3 Joann": "3 John",
    "Jud": "Jude", "Apoc": "Revelation", "Joh": "John",
    # deuterocanon: not in the 66-book module
    "Sap": DEUTERO, "Eccli": DEUTERO, "Sir": DEUTERO, "Tob": DEUTERO,
    "Judith": DEUTERO, "Bar": DEUTERO, "1 Mach": DEUTERO, "2 Mach": DEUTERO,
}

# ---- Liturgical incipits (Latin body opening -> Spanish) ----
INCIPITS = [
    ("In illo témpore:", "En aquel tiempo:"),
    ("In illo tempore:", "En aquel tiempo:"),
    ("Fratres:", "Hermanos:"),
    ("In diébus illis:", "En aquellos días:"),
    ("Caríssime:", "Carísimo:"),
    ("Caríssimi:", "Carísimos:"),
    ("Hæc dicit Dóminus Deus:", "Esto dice el Señor Dios:"),
    ("Hæc dicit Dóminus:", "Esto dice el Señor:"),
]

# ---- Intro-line translation (the reading's heading) ----
EPISTLE_DEST = {  # "ad X" -> Spanish
    "Romános": "a los Romanos", "Romanos": "a los Romanos",
    "Corínthios": "a los Corintios", "Corinthios": "a los Corintios",
    "Gálatas": "a los Gálatas", "Galatas": "a los Gálatas",
    "Ephésios": "a los Efesios", "Ephesios": "a los Efesios",
    "Philippénses": "a los Filipenses", "Philippenses": "a los Filipenses",
    "Colossénses": "a los Colosenses", "Colossenses": "a los Colosenses",
    "Thessalonicénses": "a los Tesalonicenses",
    "Thessalonicenses": "a los Tesalonicenses",
    "Timótheum": "a Timoteo", "Timotheum": "a Timoteo",
    "Titum": "a Tito", "Philemónem": "a Filemón", "Philemonem": "a Filemón",
    "Hebrǽos": "a los Hebreos", "Hebræos": "a los Hebreos",
}
APOSTLE = {
    "Pauli": "San Pablo", "Petri": "San Pedro", "Joánnis": "San Juan",
    "Joannis": "San Juan", "Joánni": "San Juan",
    "Jacóbi": "Santiago", "Jacobi": "Santiago", "Judæ": "San Judas",
}
EVANGELIST = {
    "Matthǽum": "San Mateo", "Matthæum": "San Mateo",
    "Marcum": "San Marcos", "Lucam": "San Lucas",
    "Joánnem": "San Juan", "Joannem": "San Juan",
}
PROPHET = {
    "Isaíæ": "Isaías", "Isaiæ": "Isaías", "Jeremíæ": "Jeremías",
    "Jeremiæ": "Jeremías", "Ezechiélis": "Ezequiel",
    "Ezechielis": "Ezequiel", "Daniélis": "Daniel", "Danielis": "Daniel",
    "Joélis": "Joel", "Joelis": "Joel", "Jonæ": "Jonás",
    "Osée": "Oseas", "Malachíæ": "Malaquías", "Malachiæ": "Malaquías",
    "Michǽæ": "Miqueas", "Zacharíæ": "Zacarías",
}
LIBRI = {
    "Sapiéntiæ": "de la Sabiduría", "Sapientiæ": "de la Sabiduría",
    "Génesis": "del Génesis", "Genesis": "del Génesis",
    "Exodi": "del Éxodo", "Éxodi": "del Éxodo",
    "Levítici": "del Levítico", "Numerórum": "de los Números",
    "Deuteronómii": "del Deuteronomio",
    "Regum": "de los Reyes", "Esdræ": "de Esdras",
    "Esther": "de Ester", "Esther.": "de Ester",
    "Job": "de Job", "Proverbiórum": "de los Proverbios",
    "Ecclesiástes": "del Eclesiastés",
    "Judith": "de Judit", "Tobíæ": "de Tobías",
    "Machabæórum": "de los Macabeos", "Numeri": "de los Números",
}


def fold(s):
    """Accent-insensitive comparison key: the source data is inconsistent
    about which syllables carry the acute."""
    s = unicodedata.normalize("NFD", s)
    s = "".join(c for c in s if not unicodedata.combining(c))
    return s.lower().replace("æ", "ae").replace("œ", "oe")


EPISTLE_DEST_F = {fold(k): v for k, v in EPISTLE_DEST.items()}
APOSTLE_F = {fold(k): v for k, v in APOSTLE.items()}
EVANGELIST_F = {fold(k): v for k, v in EVANGELIST.items()}
PROPHET_F = {fold(k): v for k, v in PROPHET.items()}
LIBRI_F = {fold(k): v for k, v in LIBRI.items()}


def translate_intro(line):
    line = re.sub(r"\s+", " ", nfc(line.strip()).rstrip("."))
    norm = fold(line)
    m = re.match(r"^lectio (?:prima )?(?:epistolae )?(?:beati|sancti) pauli "
                 r"apostoli ad (\S+)$", norm)
    if m and m.group(1) in EPISTLE_DEST_F:
        return ("Lección de la Epístola del Apóstol San Pablo "
                + EPISTLE_DEST_F[m.group(1)])
    m = re.match(r"^lectio epistolae (?:beati|sancti) (\S+) apostoli$", norm)
    if m and m.group(1) in APOSTLE_F:
        return "Lección de la Epístola del Apóstol " + APOSTLE_F[m.group(1)]
    m = re.match(r"^lectio sancti evangeli\w* secundum (\S+)$", norm)
    if m and m.group(1) in EVANGELIST_F:
        return ("Lección del santo Evangelio según "
                + EVANGELIST_F[m.group(1)])
    m = re.match(r"^(sequentia|initium)(?:\s*\++)*\s*sancti evangeli\w* "
                 r"secundum (\S+)$", norm)
    if m and m.group(2) in EVANGELIST_F:
        head = ("Continuación + del santo Evangelio según "
                if m.group(1) == "sequentia"
                else "Comienzo + del santo Evangelio según ")
        return head + EVANGELIST_F[m.group(2)]
    m = re.match(r"^passio domini nostri jesu christi secundum (\S+)$", norm)
    if m:
        ev = {"matthaeum": "San Mateo", "marcum": "San Marcos",
              "lucam": "San Lucas", "joannem": "San Juan"}.get(m.group(1))
        if ev:
            return "Pasión de nuestro Señor Jesucristo según " + ev
    m = re.match(r"^lectio (\S+) prophetae$", norm)
    if m and m.group(1) in PROPHET_F:
        return "Lección del Profeta " + PROPHET_F[m.group(1)]
    if re.match(r"^lectio libri apocalypsis beati joannis apostoli$", norm):
        return "Lección del libro del Apocalipsis del Apóstol San Juan"
    if re.match(r"^lectio actuum apostolorum$", norm):
        return "Lección de los Hechos de los Apóstoles"
    m = re.match(r"^lectio libri (\S+)$", norm)
    if m and m.group(1) in LIBRI_F:
        return "Lección del libro " + LIBRI_F[m.group(1)]
    return None


# Vulgate/KJV chapter-verse offsets for the few divergent spots the missal
# actually reads from: KJV verse = Vulgate verse + shift.
VULGATE_SHIFTS = {("Hosea", 14): -1}


def parse_ref(ref):
    """'Rom 13:11-14' / 'Eccli 24:5, 7, 9-11' / 'Judith 13, 22-25; 15:10' /
    'Os 6:1-6; Ex 12:1-11' (multi-book) / 'Gen 1; Gen 5-8' (whole chapters)
    -> [(book_alias, chapter, verse_or_None), ...] or None.
    verse None means 'the whole chapter'."""
    ref = nfc(ref.strip())
    out = []
    book = None
    last_ch = None
    for seg in ref.split(";"):
        seg = seg.strip().rstrip(".")
        m = re.match(r"^((?:\d\.?\s)?[A-Za-zë̈æœÆŒëïö]+)\.?\s+(.*)$", seg)
        if m and (m.group(1) in BOOKS or m.group(1).rstrip(".") in BOOKS):
            book = m.group(1).rstrip(".")
            rest = m.group(2)
        elif m and book is None:
            return None
        else:
            rest = seg
        if book is None:
            return None
        m2 = re.match(r"^(\d+)\s*[:,]\s*(.+)$", rest)
        if m2:
            ch = int(m2.group(1))
            last_ch = ch
            for item in m2.group(2).split(","):
                item = item.strip().rstrip(".")
                if not item:
                    continue
                m3 = re.match(r"^(\d+)(?:\s*-\s*(\d+))?$", item)
                if not m3:
                    return None
                a = int(m3.group(1))
                b = int(m3.group(2)) if m3.group(2) else a
                if b < a or b - a > 80:
                    return None
                out.extend((book, ch, v) for v in range(a, b + 1))
            continue
        m4 = re.match(r"^(\d+)(?:\s*-\s*(\d+))?$", rest)
        if m4 and m:
            # a bare number right after a book name: whole chapter(s)
            a = int(m4.group(1))
            b = int(m4.group(2)) if m4.group(2) else a
            if b < a or b - a > 12:
                return None
            out.extend((book, ch, None) for ch in range(a, b + 1))
            continue
        if m4 and last_ch is not None:
            # a bare range with no book/chapter: verses of the last chapter
            a = int(m4.group(1))
            b = int(m4.group(2)) if m4.group(2) else a
            if b < a or b - a > 80:
                return None
            out.extend((book, last_ch, v) for v in range(a, b + 1))
            continue
        return None
    return out or None


CM = re.compile(r"\s*<CM>\s*|</?b>")

# The 66-book module lacks the deuterocanon; those pericopes are our own
# tier-2 translations from the Vulgate Latin the app already carries,
# keyed by the entry's ref (whitespace-normalized). Body text only — the
# intro and incipit are composed the same way as for every other reading.
DEUTERO_PATH = ROOT / "spanish-translation" / "readings_deutero_es.json"
DEUTERO_ES = (json.load(open(DEUTERO_PATH, encoding="utf-8"))
              if DEUTERO_PATH.exists() else {})


def ref_key(ref):
    return re.sub(r"\s+", " ", ref.strip())


# Fields whose English is not a plain pericope (the Easter Vigil's
# Exsultet-plus-prophecies block with its chants and collects, and the
# pre-1955 Palm Sunday entry that embeds the Munda cor prayer): composing
# them from raw verse text would replace structure with a blob.
EXCLUDE = {
    ("quad6-6", "lectio"), ("quad6-6r", "lectio"),
    ("quad6-0r", "evangelium"),
    # Vigil of the Assumption's evangelium field is a cross-reference stub
    # ("In Festis Beatae Mariae Virginis: Salve Sancte Parens…"), not a
    # pericope.
    ("08-14", "evangelium"),
}

# Manual ref corrections/additions for entries whose ref is absent AND whose
# Latin matches no ref-bearing twin, or whose stored ref is a typo.
REF_FIXES = {
    ("06-28r", "evangelium"): "Joann 21:15-19",   # data typo "21:15-10"
    # ref-less entries identified from their (English) text; where lat and
    # eng disagree (02-05, 07-21) the ref follows the ENGLISH pericope,
    # since the Spanish replaces the English side.
    ("01-18", "lectio"): "1 Pet 1:1-7",
    ("02-22", "lectio"): "1 Pet 1:1-7",
    ("02-05", "evangelium"): "Matt 25:1-13",
    ("02-23o", "evangelium"): "Joann 15:12-16",
    ("03-09", "lectio"): "Prov 31:10-31",
    ("03-25", "lectio"): "Is 7:10-15",
    ("03-25", "evangelium"): "Luc 1:26-38",
    ("07-21", "lectio"): "2 Cor 10:17-18; 11:1-2",
    ("11-09", "lectio"): "Apoc 21:2-5",
    # Palm Sunday Passion (its English runs Mt 26:1 through 27:66)
    ("quad6-0", "evangelium"): "Matt 26:1-75; 27:1-66",
    # Commons whose ref-less entries share Latin only with other ref-less
    # twins: Wisdom 5 (martyrs in Eastertide), the vine gospel, the
    # "Loquénte Jesu ad turbas" and Zacchæus gospels, and the two
    # Ecclesiasticus lectios of the apostle-vigil and BVM commons (the
    # apostle-vigil ref follows the ENGLISH pericope, which carries the
    # full 44:25–45:9 cento).
    ("04-14t", "lectio"): "Sap 5:1-5",
    ("05-06", "lectio"): "Sap 5:1-5",
    ("04-14t", "evangelium"): "Joann 15:1-7",
    ("07-16", "evangelium"): "Luc 11:27-28",
    ("09-24", "evangelium"): "Luc 11:27-28",
    ("11-21", "evangelium"): "Luc 11:27-28",
    ("12-08o", "evangelium"): "Luc 11:27-28",
    ("C10", "evangelium"): "Luc 11:27-28",
    ("C11", "evangelium"): "Luc 11:27-28",
    ("11-09", "evangelium"): "Luc 19:1-10",
    ("11-18", "evangelium"): "Luc 19:1-10",
    ("11-18o", "evangelium"): "Luc 19:1-10",
    ("11-18r", "evangelium"): "Luc 19:1-10",
    ("C8", "evangelium"): "Luc 19:1-10",
    ("02-23o", "lectio"): "Eccli 44:25-27; 45:2-4, 6-9",
    ("07-24", "lectio"): "Eccli 44:25-27; 45:2-4, 6-9",
    ("09-20o", "lectio"): "Eccli 44:25-27; 45:2-4, 6-9",
    ("11-29", "lectio"): "Eccli 44:25-27; 45:2-4, 6-9",
    ("12-20o", "lectio"): "Eccli 44:25-27; 45:2-4, 6-9",
    ("09-24", "lectio"): "Eccli 24:14-16",
    ("11-21", "lectio"): "Eccli 24:14-16",
    ("12-08o", "lectio"): "Eccli 24:14-16",
    ("C10", "lectio"): "Eccli 24:14-16",
    ("C11", "lectio"): "Eccli 24:14-16",
}


def main():
    bible_path = arg("--bible")
    kjv_path = arg("--kjv")
    if not bible_path or not kjv_path:
        sys.exit("pass --bible <torres_amat.ont> --kjv <kjv.json>")

    verse_lines = open(bible_path, encoding="utf-8-sig",
                       newline="").read().splitlines()
    kjv = json.load(open(kjv_path, encoding="utf-8"))["books"]
    # index: book name -> {(ch, v): line_no}
    index = {}
    line_no = 0
    for b in kjv:
        by_cv = {}
        for ch in b["chapters"]:
            for v in ch["verses"]:
                by_cv[(int(ch["chapter"]), int(v["verse"]))] = line_no
                line_no += 1
        index[b["name"]] = by_cv
    assert line_no == 31102, line_no
    assert verse_lines[index["John"][(3, 16)]].startswith("Que amó tanto Dios")

    tempora = json.load(open(ROOT / "Introibo" / "Resources" /
                             "missal_tempora.json"))
    sanctoral = json.load(open(ROOT / "Introibo" / "Resources" /
                               "missal_sanctoral.json"))

    # ~500 reading entries carry the full Latin but no ref. Readings repeat
    # heavily, so recover the ref from any entry with the same Latin body
    # (normalized); the handful of unique ones are mapped by REF_FIXES.
    def lat_key(lat):
        return re.sub(r"\s+", " ", fold(lat)).strip()

    lat_to_ref = {}
    for d in (tempora, sanctoral):
        for key, entry in d.items():
            for f in ("lectio", "evangelium"):
                v = entry.get(f)
                if v and v.get("ref") and (v.get("lat") or "").strip():
                    lat_to_ref.setdefault(lat_key(v["lat"]), v["ref"])
    for (k, f), r in REF_FIXES.items():
        d = tempora if k in tempora else sanctoral
        v = d.get(k, {}).get(f)
        if v and (v.get("lat") or "").strip():
            lat_to_ref[lat_key(v["lat"])] = r

    def expand(parsed):
        """[(book_alias, ch, v|None)] -> [(kjv_name, ch, v)] verse list,
        or a skip-reason string."""
        verses = []
        for book, ch, v_ in parsed:
            kjv_name = BOOKS.get(book)
            if kjv_name is None:
                return "unknown book"
            if kjv_name == "Ecclesiastes" and ch > 12:
                kjv_name = DEUTERO   # 'Eccles' with Sirach chapter numbers
            if kjv_name == DEUTERO or \
               (kjv_name == "Esther" and ch > 10) or \
               (kjv_name == "Daniel" and
                    (ch > 12 or (ch == 3 and (v_ is None or v_ > 23)))):
                return "deuterocanon"
            by_cv = index[kjv_name]
            shift = VULGATE_SHIFTS.get((kjv_name, ch), 0)
            if v_ is None:
                chapter_verses = sorted(vv for cc, vv in by_cv if cc == ch)
                if not chapter_verses:
                    return "verse out of range"
                verses.extend((kjv_name, ch, vv) for vv in chapter_verses)
            else:
                if (ch, v_ + shift) not in by_cv:
                    return "verse out of range"
                verses.append((kjv_name, ch, v_ + shift))
        return verses

    out, skipped = {}, {}
    for d in (tempora, sanctoral):
        for key, entry in d.items():
            fields = {}
            for f in ("lectio", "evangelium"):
                if (key, f) in EXCLUDE:
                    continue
                v = entry.get(f)
                if not v or not (v.get("eng") or "").strip():
                    continue
                lat = (v.get("lat") or "").strip()
                if not lat:
                    skipped.setdefault("no lat", []).append((key, f))
                    continue
                ref = (REF_FIXES.get((key, f)) or v.get("ref")
                       or lat_to_ref.get(lat_key(lat)))
                if not ref:
                    skipped.setdefault("no ref (unrecovered)", []).append(
                        (key, f, lat.split("\n")[1][:70]
                         if "\n" in lat else lat[:70]))
                    continue
                deutero_body = None
                parsed = parse_ref(ref)
                if not parsed:
                    skipped.setdefault("unparsed ref", []).append((key, f, ref))
                    continue
                verses = expand(parsed)
                if verses == "deuterocanon" and ref_key(ref) in DEUTERO_ES:
                    deutero_body = DEUTERO_ES[ref_key(ref)]
                elif isinstance(verses, str):
                    skipped.setdefault(verses, []).append((key, f, ref))
                    continue
                intro = translate_intro(lat.split("\n")[0])
                if intro is not None:
                    body_lat = "\n".join(lat.split("\n")[1:]).strip()
                elif any(nfc(lat).startswith(l) for l, _ in INCIPITS):
                    # some lessons (e.g. Good Friday's) carry no heading —
                    # the Latin opens directly with the incipit
                    intro, body_lat = "", lat
                else:
                    skipped.setdefault("intro not translated", []).append(
                        (key, f, lat.split("\n")[0][:60]))
                    continue
                incipit = ""
                for l_inc, s_inc in INCIPITS:
                    if nfc(body_lat).startswith(l_inc):
                        incipit = s_inc + " "
                        break
                if deutero_body is not None:
                    text = deutero_body
                else:
                    text = " ".join(
                        CM.sub(" ", verse_lines[index[b][(c, v_)]]).strip()
                        for b, c, v_ in verses)
                text = re.sub(r"\s+", " ", text).strip()
                # the .ont module puts spaces before punctuation
                text = re.sub(r"\s+([,.;:!?])", r"\1", text)
                if incipit:
                    # smooth the seam: a pericope's first verse often opens
                    # with a connective — or its own time-phrase, redundant
                    # after "En aquel tiempo:" — that reads wrong after the
                    # incipit
                    text = re.sub(
                        r"^(?:Y|Pero|Mas|Entonces|"
                        r"(?:Por (?:aquel|este) tiempo|"
                        r"En (?:aquella|esta) sazón|En aquel tiempo),?)\s+",
                        "", text)
                    text = text[:1].upper() + text[1:]
                if not text:
                    skipped.setdefault("empty text", []).append((key, f, ref))
                    continue
                fields[f] = ((intro + "\n") if intro else "") + incipit + text
            if fields:
                out[key] = fields

    OUT.write_text(json.dumps(out, ensure_ascii=False, indent=1,
                              sort_keys=True) + "\n", encoding="utf-8")

    n_fields = sum(len(v) for v in out.values())
    print(f"imported readings for {len(out)} days ({n_fields} fields)")
    for why, items in sorted(skipped.items()):
        print(f"  skipped [{why}]: {len(items)}")
        for it in items:
            print("     ", it)


if __name__ == "__main__":
    main()
