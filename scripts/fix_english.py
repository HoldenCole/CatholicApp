#!/usr/bin/env python3
"""English where the app shows Latin (or nothing) in its place.

1. The Mass (missal_sanctoral.json, missal_tempora.json): an English line
   that is only its Latin repeated (a psalm verse, a "Glória Patri", a
   whole prayer where Divinum Officium's English falls back to the Latin)
   takes the English that the same Latin line has elsewhere: in the app's
   own aligned parts, or in DO's English (dodump.pl dumps). Leading spaces
   left by the import are taken off. A Collect, Secret or Postcommunion
   carrying a commemoration (Orémus and a second prayer) whose English
   stops after the first prayer, or is another day's, is written again line
   by line; St Liborius's prayers lose DO's raw second form (FIRST_FORM).
   A line of nothing but alleluias is never touched: its English is the
   same words.
2. The Office data: a part whose English is its Latin takes the English of
   its Latin lines the same way; a part with no English at all whose Latin
   DO gives whole (the feasts' own hymn doxologies) takes it (EMPTY_FILL).
3. The Office: the texts an hour shows without English (OFFICE_GAPS, from a
   year's English dump: SpanishAuditDump with SPANISH_AUDIT_LANG=en) get an
   entry in office_texts_en.json (Latin -> English), which the hours apply
   only where a part has no English of its own.

What no source has is listed, and the English kept in HAND (translated
from the Latin, in the register of the app's other English).

Run:
  python3 scripts/fix_english.py --do-en /tmp/doen [--gaps gaps.json] [--dry-run]
"""
import json
import re
import sys
import unicodedata
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ASSETS = [ROOT / "android/app/src/main/assets", ROOT / "Introibo/Resources"]
MISSAL = ("missal_sanctoral.json", "missal_tempora.json")
GLORIA_LAT = ("Glória Patri, et Fílio, et Spirítui Sancto. Sicut erat in princípio, et nunc, "
              "et semper, et in sǽcula sæculórum. Amen.")
GLORIA_ENG = ("Glory be to the Father, and to the Son, and to the Holy Ghost. As it was in the "
              "beginning, is now, and ever shall be, world without end. Amen.")

# English that no source supplies: Latin line -> English (by hand), kept in
# scripts/english_hand.json.
HAND = {k: v for k, v in json.load(open(Path(__file__).with_name("english_hand.json"), encoding="utf-8")).items()
        if not k.startswith("_")}


def nfc(s):
    return unicodedata.normalize("NFC", s or "")


def fold(t):
    t = unicodedata.normalize("NFD", nfc(t))
    t = "".join(c for c in t if unicodedata.category(c) != "Mn").lower()
    t = t.replace("æ", "ae").replace("œ", "ae").replace("oe", "ae").replace("j", "i").replace("v", "u")
    t = re.sub(r"ci(?=[aeiou])", "ti", t)
    return re.sub(r"\s+", " ", re.sub(r"[^a-z0-9 ]+", " ", t)).strip()


MARK = re.compile(r"^(V\.|R\.|℣\.|℟\.|℟\.br\.|Ant\.|v\.)\s*")


def core(l):
    return MARK.sub("", l.strip()).replace("*", " ").strip()


LAT_ACC = re.compile(r"\b\w*[áéíóúǽ]\w*\b")
LAT_WORD = re.compile(r"\b(et|qui|quæ|ut|tuis|tuæ|tuórum|nobis|Dómine|Deus|est|sunt|eórum|ejus|quǽsumus|in|cum|ad|per|non|sicut|super)\b")


def latin_text(line):
    """An English line that is Latin (DO's fallback, a name put in English)."""
    w = re.findall(r"[^\W\d_]+", line)
    return len(w) >= 5 and (len(LAT_ACC.findall(line)) + len(LAT_WORD.findall(line))) / len(w) > 0.35


# a line of nothing but alleluias (and marks): the same words in English
ALLELUIA_ONLY = re.compile(r"^[\s*℟℣.,:;()]*(?:(?:R|V)\.\s*)?(?:allel[uú][ij]a[\s,.;:*()!]*)+$", re.I)


def latinish(eng, lat):
    if ALLELUIA_ONLY.match(eng) or ALLELUIA_ONLY.match(lat):
        return False
    if fold(core(eng)) == fold(core(lat)) and len(fold(core(lat))) > 12:
        return True
    return latin_text(eng) and latin_text(lat)

# Latin the import garbled: (key, part) -> the Latin as the Missal has it.
LATIN_FIX = {
    ("08-18bmv", "postcommunio"): ("Mensae coelestis participles effecti, imploramus clementiam tuam, Domine Deus noster; ut, qui Assumptionem Dei Genetricis colimus, a cunctis malis imminentibus, ejus intercessione liberemur.",
                                   "Mensæ cœléstis partícipes effécti, implorámus cleméntiam tuam, Dómine, Deus noster: ut, qui Assumptiónem Dei Genetrícis cólimus, a cunctis malis imminéntibus, ejus intercessióne liberémur."),
}


PRAYERS = ("oratio", "secreta", "postcommunio")

# Office parts the data carries with no English, written whole from DO's
# English (horas): the feasts' own hymn doxologies, which the 1955 and
# earlier hours put in place of every hymn's last stanza, and St Joseph the
# Worker's second versicle. The Holy Family's lacks DO's "Amen." line.
EMPTY_FILL = {
    "Jesu, tibi sit glória,\nQui te revélas párvulis,\nCum Patre, et almo Spíritu,\nIn sempitérna sǽcula.\nAmen.":
        "Jesu, to thee our praise we pay,\nTo little ones revealed today,\nWith Father and Blest Spirit One\nUntil the ages' course is done.\nAmen.",
    "Jesu, tibi sit glória,\nQui passus es pro sérvulis,\nCum Patre et almo Spíritu,\nIn sempitérna sǽcula.\nAmen.":
        "Lord Jesu, slain for us, to thee\nEternal praise be given,\nWith Father, Spirit, One and Three,\nHere as it is in heaven.\nAmen.",
    "Jesu, tibi sit glória,\nQui sceptra mundi témperas,\nCum Patre, et almo Spíritu,\nIn sempitérna sǽcula.\nAmen.":
        "All glory be, Jesu, to thee,\nThy scepter over all that be;\nAll glory, as is ever meet,\nTo Father and to Paraclete.\nAmen.",
    "Jesu, tuis obédiens\nQui factus es paréntibus,\nCum Patre summo ac Spíritu\nSemper tibi sit glória.\nAmen.":
        "All praise to Thee, O Jesus,\nwho parents dost obey;\nPraise to the sovereign Father\nand Paraclete for aye.\nAmen.",
    "℣. Dedísti mihi protectiónem salútis tuæ, allelúja.": "℣. Thou hast given me the shield of thy salvation, alleluia.",
    "℟. Et déxtera tua suscépit me, allelúja.": "℟. And thy right hand hath holden me up, alleluia.",
}

# DO's St Liborius (Sancti/07-23cc) gives a second form "(sed feria 7 nisi
# rubrica 1955 nisi rubrica 196)", which the 1960 rubrics never take: the
# first form, as DO's 1962 Mass has it, stands alone.
FIRST_FORM = {("07-23cc", "secreta"), ("07-23cc", "postcommunio")}


def do_lines(text, gloria):
    out = []
    for l in nfc(text or "").split("\n"):
        l = l.strip()
        if not l or l == "_" or l.startswith(("!", "$", "@", "#")):
            continue
        if l.startswith("&"):
            if l[1:].lower().startswith("gloria"):
                out.append(gloria)
            continue
        out.append(re.sub(r"^v\.\s*", "", l))
    return out


def build_map(do_en):
    m = defaultdict(Counter)

    def add(lat, eng):
        a, b = core(lat), core(eng)
        if not a or not b or latinish(b, a) or ALLELUIA_ONLY.match(a) or ALLELUIA_ONLY.match(b):
            return
        m[fold(a)][b] += 1

    m[fold(GLORIA_LAT)][GLORIA_ENG] += 100
    # the app's own aligned parts
    for name in MISSAL:
        for e in json.load(open(ASSETS[0] / name, encoding="utf-8")).values():
            for v in e.values():
                if isinstance(v, dict) and v.get("lat") and v.get("eng"):
                    L, E = nfc(v["lat"]).split("\n"), nfc(v["eng"]).split("\n")
                    if len(L) == len(E):
                        for a, b in zip(L, E):
                            add(a, b)
    # DO's English
    for p in sorted(Path(do_en).glob("*.json")):
        try:
            d = json.load(open(p, encoding="utf-8"))
        except Exception:
            continue
        for f, secs in d.items():
            if not isinstance(secs, dict):
                continue
            for sec in secs.values():
                if not isinstance(sec, dict):
                    continue
                lat, eng = sec.get("lat"), sec.get("eng")
                if not isinstance(lat, str) or not isinstance(eng, str):
                    continue
                L, E = do_lines(lat, GLORIA_LAT), do_lines(eng, GLORIA_ENG)
                if len(L) == len(E):
                    for a, b in zip(L, E):
                        add(a, b)
    for a, b in HAND.items():
        m[fold(core(a))] = Counter({b: 10 ** 6})
    return m


def english(m, lat):
    """The English of one Latin line, its verse mark kept."""
    mk = MARK.match(lat.strip())
    c = m.get(fold(core(lat)))
    if not c:
        return None
    e = c.most_common(1)[0][0]
    if mk and mk.group(1) in ("V.", "R.", "℣.", "℟.", "℟.br.", "Ant."):
        e = mk.group(1) + " " + e
    return e


def main():
    do_en = sys.argv[sys.argv.index("--do-en") + 1]
    m = build_map(do_en)
    missing = Counter()
    fixed = Counter()
    for name in MISSAL:
        data = json.load(open(ASSETS[0] / name, encoding="utf-8"))
        for key, e in data.items():
            for f, v in e.items():
                if not isinstance(v, dict) or not v.get("lat") or not v.get("eng"):
                    continue
                if (key, f) in LATIN_FIX:
                    v["lat"] = v["lat"].replace(*LATIN_FIX[(key, f)])
                if (key, f) in FIRST_FORM:
                    v["lat"] = "\n".join(nfc(v["lat"]).split("\n")[:2])
                L, E = nfc(v["lat"]).split("\n"), nfc(v["eng"]).split("\n")
                E = [x.strip() if x.startswith(" ") else x for x in E]
                if f in PRAYERS and len(L) != len(E):
                    # a commemoration's prayer whose English stops after the
                    # first (or is another's): written again line by line
                    t = [english(m, a) for a in L]
                    if all(t):
                        v["eng"] = "\n".join(t)
                        fixed["realigned " + f] += 1
                    else:
                        missing.update(a for a, x in zip(L, t) if not x)
                    continue
                if len(L) == len(E):
                    pairs = list(zip(L, E))
                else:
                    pairs = [(next((a for a in L if latinish(b, a)), None), b) for b in E]
                out = []
                for a, b in pairs:
                    if a is not None and latinish(b, a):
                        t = english(m, a)
                        if t:
                            out.append(t)
                            if t != b:
                                fixed[f] += 1
                            continue
                        missing[a] += 1
                    out.append(b)
                new = "\n".join(out)
                if new != v["eng"]:
                    v["eng"] = new
        if "--dry-run" not in sys.argv:
            text = json.dumps(data, ensure_ascii=False, indent=2)
            for d in ASSETS:
                (d / name).write_text(text, encoding="utf-8")
    print("mass: English lines put in place of Latin", dict(fixed), sum(fixed.values()))

    # The Office's own data: a {lat, eng} (or latR/engR, ant/antEng) whose
    # English is its Latin (DO's fallback) takes the English of its Latin
    # lines; a Common's "N." stays "N." for the hours to fill.
    office_files = ["office_commune.json", "office_propers_1962.json", "office_propers_1955.json",
                    "office_propers_pre1955.json", "office_psalterium.json", "sanctoral_propers.json",
                    "commune_office.json", "office_ants.json", "hours.json", "office_lessons.json"]
    office_left = Counter()
    PAIRS = (("lat", "eng"), ("latR", "engR"), ("ant", "antEng"))

    def fill(lat, eng):
        L, E = nfc(lat).split("\n"), nfc(eng).split("\n")
        if len(L) != len(E):
            return None
        out, changed = [], False
        for a, b in zip(L, E):
            directive = a.strip().startswith(("$", "@", "&", "!", "#", "(", "/:")) or a.strip() == "_" \
                or "=" in a.split(" ")[0] or a.strip().endswith("...") or "..." in a
            if a.strip() and b.strip() and not directive and latinish(b, a):
                t = english(m, a)
                if t is None:
                    office_left[a] += 1
                    out.append(b)
                    continue
                out.append(t)
                changed = changed or t != b
            else:
                out.append(b)
        return "\n".join(out) if changed else None

    def walk(o):
        n = 0
        if isinstance(o, dict):
            # a part with no English at all whose Latin DO gives whole
            for a, b in PAIRS:
                t = EMPTY_FILL.get(nfc(o.get(a) or "").strip())
                if t and not (o.get(b) or "").strip():
                    o[b] = t
                    n += 1
            for a, b in PAIRS:
                if isinstance(o.get(a), str) and isinstance(o.get(b), str) and o[a].strip():
                    t = fill(o[a], o[b])
                    if t is not None:
                        o[b] = t
                        n += 1
            for v in o.values():
                n += walk(v)
        elif isinstance(o, list):
            for v in o:
                n += walk(v)
        return n

    for name in office_files:
        p = ASSETS[0] / name
        if not p.exists():
            continue
        text = p.read_text(encoding="utf-8")
        data = json.loads(text)
        n = walk(data)
        fixed["office " + name] += n
        if n and "--dry-run" not in sys.argv:
            indent = 2 if text.startswith('{\n  "') or text.startswith('[\n  ') else (1 if text.startswith(('{\n "', '[\n ')) else None)
            out_t = json.dumps(data, ensure_ascii=False, indent=indent) + ("\n" if text.endswith("\n") else "")
            for d in ASSETS:
                (d / name).write_text(out_t, encoding="utf-8")
    print("office data:", {k: v for k, v in fixed.items() if k.startswith("office ")})
    for a, c in office_left.most_common():
        print("  office no English |", c, "|", a[:150])

    # the seasonal hymn doxologies: one whose English (or Spanish, French)
    # is its Latin takes that of the doxology with the same Latin words
    # ("Corp", the Christmas "Qui natus es de Vírgine")
    dp = ASSETS[0] / "office_doxologies.json"
    dtext = dp.read_text(encoding="utf-8")
    dd = json.loads(dtext)
    doxs = dd.get("doxologies", {})
    for k, v in doxs.items():
        for lang in ("eng", "es", "fr"):
            if fold(v.get(lang) or v["lat"]) == fold(v["lat"]):
                twin = next((w for j, w in doxs.items() if j != k and fold(w["lat"]) == fold(v["lat"])
                             and w.get(lang) and fold(w[lang]) != fold(w["lat"])), None)
                if twin:
                    v[lang] = twin[lang]
                    fixed["doxology " + lang] += 1
    if "--dry-run" not in sys.argv:
        out_d = json.dumps(dd, ensure_ascii=False, indent=1 if dtext.startswith('{\n "') else 2)
        if dtext.endswith("\n"):
            out_d += "\n"
        for d in ASSETS:
            (d / "office_doxologies.json").write_text(out_d, encoding="utf-8")
    print("doxologies:", {k: v for k, v in fixed.items() if k.startswith("doxology")})

    # the Office's gaps
    gaps = json.load(open(sys.argv[sys.argv.index("--gaps") + 1], encoding="utf-8")) if "--gaps" in sys.argv else []
    out, left = {}, []
    for lat in gaps:
        lines = nfc(lat).split("\n")
        tr = []
        for l in lines:
            if not l.strip():
                tr.append("")
                continue
            t = english(m, l)
            if t is None:
                left.append(l)
                break
            tr.append(t)
        else:
            out[re.sub(r"\s+", " ", nfc(lat).replace("~", " ")).strip()] = "\n".join(tr)
    print(f"office: {len(out)} of {len(gaps)} texts given English, {len(left)} without a source")
    for a in sorted(set(missing) | set(left)):
        print("  no English |", a[:150])
    if "--dry-run" not in sys.argv and gaps:
        text = json.dumps(dict(sorted(out.items())), ensure_ascii=False, indent=1) + "\n"
        for d in ASSETS:
            (d / "office_texts_en.json").write_text(text, encoding="utf-8")


if __name__ == "__main__":
    main()
