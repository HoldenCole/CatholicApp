#!/usr/bin/env python3
"""Put the proper parts of the Mass right (Introit, Lesson, Gradual, Gospel,
Offertory, Communion, Sequence), from Divinum Officium's own text.

Comparing every part of missal_sanctoral.json and missal_tempora.json with
what DO's missa/propers.pl getitem() finds for it (dodump.pl ... missaparts:
the file's own section, else its Common's, "N." filled from [Name]) found
the import had taken many saints' parts from the wrong Mass of the Common
(St Louis's Introit "Justus ut palma" for "Os justi", a martyr's Lesson for
St John Damascene), left out the Gradual of 146 saints' Masses, cut verses
short and let rubric lines into the text (the Gospel of 14 August).

A part is replaced only where its words differ from DO's (spelling,
punctuation and line breaks aside), so that the vernacular lines already
laid over a correct part stay with it. DO's seasonal forms of the Gradual
are added beside it (gradualeP for Paschaltide, tractus from Septuagesima),
which the Mass picks by the season as DO does. Every part is written as the
app writes the others: references off the text (the first into "ref"),
"&Gloria" written out, DO's verse marks dropped.

Run:
  DO_LANG2=English perl scripts/office_qa/dodump.pl "Rubrics 1960 - 1960" missaparts > /tmp/doen/missaparts_1962.json
  python3 scripts/fix_mass_parts.py --do-en /tmp/doen [--dry-run] [--verbose]
"""
import difflib
import json
import re
import sys
import unicodedata
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ASSETS = [ROOT / "android/app/src/main/assets", ROOT / "Introibo/Resources"]
FILES = {"missal_sanctoral.json": "Sancti", "missal_tempora.json": "Tempora"}
PARTS = {"introitus": "Introitus", "lectio": "Lectio", "graduale": "Graduale",
         "evangelium": "Evangelium", "offertorium": "Offertorium", "communio": "Communio",
         "sequentia": "Sequentia"}
SEASONAL = {"gradualeP": "GradualeP", "tractus": "Tractus"}

# DO's line breaks inside a sentence: (key, part) -> the start of the line
# that belongs to the line before it.
JOIN = {("04-14", "tractus"): "Deus ante sǽcula"}

# Near-identical parts where DO's has words the app's lacks.
NEAR_TAKE = {("epi1-0", "lectio"), ("epi5-0", "lectio"), ("06-02", "introitus")}


def lines(t):
    return [l for l in nfc(t).split("\n") if l.strip()]


GLORIA_LAT = ("Glória Patri, et Fílio, et Spirítui Sancto. Sicut erat in princípio, et nunc, "
              "et semper, et in sǽcula sæculórum. Amen.")
GLORIA_ENG = ("Glory be to the Father, and to the Son, and to the Holy Ghost. As it was in the "
              "beginning, is now, and ever shall be, world without end. Amen.")


def nfc(s):
    return unicodedata.normalize("NFC", s or "")


def fold(t):
    t = unicodedata.normalize("NFD", nfc(t))
    t = "".join(c for c in t if unicodedata.category(c) != "Mn").lower()
    t = t.replace("æ", "ae").replace("œ", "ae").replace("oe", "ae").replace("j", "i").replace("v", "u")
    t = re.sub(r"ci(?=[aeiou])", "ti", t)
    return re.sub(r"\s+", " ", re.sub(r"[^a-z0-9 ]+", " ", t)).strip()


TITLE = re.compile(r"^(L[eé]ctio|Sequ[eé]ntia|In[ií]tium|Oratio Jerem|Lamentatio)\b")


def words(t):
    """The words of a part for comparison: verse marks, the Gloria Patri
    (the app writes it out, DO by macro) and a reading's title line aside."""
    ls = [l for l in nfc(t).split("\n") if l.strip() and not l.strip().startswith(("!", "&", "$", "@", "#"))]
    if ls and TITLE.match(ls[0].strip()):
        ls = ls[1:]
    t = "\n".join(ls)
    t = re.sub(r"(?m)^\s*[vV]\.\s*", "", t).replace("℣.", "").replace("℟.", "")
    return fold(t)


def convert(text, gloria):
    """DO's section text -> (the app's lines, the first reference)."""
    out, ref, carry = [], None, ""
    for l in nfc(text).split("\n"):
        l = l.strip()
        if not l or l == "_":
            continue
        if l.startswith("!"):
            r = l[1:].strip().rstrip(".")
            # DO's slip: the verse's first words on the reference line
            # ("!Ps 33:2 Benedícam Dóminum" / "in omni témpore …")
            m = re.match(r"^(\d?\s?[A-Z][a-z]+\.?\s*[\d:;,\-–. ]*\d)\s+([A-ZÁÉÍÓÚǼ][^\d]*)$", r)
            if m:
                r, carry = m.group(1), m.group(2) + " "
            if ref is None and re.match(r"^\d?\s?[A-Z][a-z]+\.?\s*\d", r):
                ref = r
            continue
        if carry:
            l, carry = carry + l, ""
        if l.startswith("&"):
            if l[1:].strip().lower().startswith("gloria"):
                out.append(gloria)
            continue
        if l.startswith(("$", "@", "#")):
            continue
        l = re.sub(r"^v\.\s*", "", l)           # DO's mark on an antiphon's first line
        if re.fullmatch(r"(?:All[eé]l[uú][ij]a[,.]?\s*)+", l) and out and not out[-1].startswith("V."):
            out.append(l)
            continue
        out.append(l)
    return out, ref


def season_reachable(key, form):
    """Whether a Mass can be said in the season a Gradual form is for.
    A saint's day falls from Septuagesima to Holy Saturday only between
    18 January and 24 April, in Paschaltide only between 22 March and
    19 June; a temporal Mass only in its own cycle."""
    m = re.match(r"^(\d\d)-(\d\d)", key)
    if m:
        md = (int(m.group(1)), int(m.group(2)))
        if form == "tractus":
            return (1, 18) <= md <= (4, 24)
        return (3, 22) <= md <= (6, 19)
    k = key.lower()
    if form == "tractus":
        return k.startswith("quad")
    return k.startswith("pasc")


def main():
    do_en = Path(sys.argv[sys.argv.index("--do-en") + 1])
    render = json.load(open(do_en / "missaparts_1962.json", encoding="utf-8"))
    verbose = "--verbose" in sys.argv
    report = defaultdict(list)
    for name, tree in FILES.items():
        path = ASSETS[0] / name
        text = path.read_text(encoding="utf-8")
        app = json.loads(text)
        for key, e in app.items():
            d = render.get(f"{tree}/{key}.txt") or render.get(f"{tree}/{key[:1].upper()}{key[1:]}.txt")
            if not d:
                continue
            for f, D in list(PARTS.items()) + list(SEASONAL.items()):
                sec = d.get(D)
                if not isinstance(sec, dict) or not sec.get("lat") or not sec.get("eng"):
                    continue
                lat, ref = convert(sec["lat"], GLORIA_LAT)
                eng, _ = convert(sec["eng"], GLORIA_ENG)
                if not lat or not eng:
                    continue
                if (key, f) in JOIN:
                    j = [i for i, l in enumerate(lat) if l.startswith(JOIN[(key, f)])]
                    for i in reversed(j):
                        lat[i - 1] = lat[i - 1] + " " + lat.pop(i)
                if len(lat) == len(eng):
                    # the verse marks the one side has and the other lacks
                    for i, (a, b) in enumerate(zip(lat, eng)):
                        if b.startswith("V.") and not a.startswith("V."):
                            lat[i] = "V. " + a
                        elif a.startswith("V.") and not b.startswith("V."):
                            eng[i] = "V. " + b
                v = e.get(f)
                if f in SEASONAL and not season_reachable(key, f):
                    if f in e:
                        del e[f]
                        report["unreachable removed"].append((name, key, f))
                    continue
                if f in SEASONAL:
                    g = e.get("graduale") or {}
                    if words("\n".join(lat)) == words(g.get("lat", "")) or words(sec["lat"]) == words(d.get("Graduale", {}).get("lat", "")):
                        continue            # the same as the Gradual: nothing to add
                if isinstance(v, dict) and "lat" in v:
                    a, b = words(v.get("lat", "")), words("\n".join(lat))
                    lines_ok = len(lines(v.get("lat", ""))) == len(lines(v.get("eng", "")))
                    if a == b and (lines_ok or len(lat) != len(eng)):
                        continue
                    if a == b:
                        report["realigned"].append((name, key, f))
                        e[f] = dict(v, lat="\n".join(lat), eng="\n".join(eng))
                        continue
                    r = difflib.SequenceMatcher(None, a, b, autojunk=False).ratio()
                    if r >= 0.97 and (key, f) not in NEAR_TAKE:
                        report["near"].append((name, key, f, round(r, 3)))
                        continue
                    first = lambda x: next((l for l in x if not TITLE.match(l)), "")
                    report["replaced"].append((name, key, f, round(r, 2), first(v["lat"].split("\n"))[:70], first(lat)[:70]))
                else:
                    if f in PARTS and f != "graduale" and f != "sequentia":
                        # a Mass the app builds from elsewhere (a feria, a
                        # redirect): its missing parts are not to be filled
                        continue
                    if f == "sequentia":
                        continue
                    report["added"].append((name, key, f, lat[0][:70]))
                new = {"lat": "\n".join(lat), "eng": "\n".join(eng)}
                if ref:
                    new["ref"] = ref
                elif isinstance(v, dict) and v.get("ref"):
                    new["ref"] = v["ref"]
                e[f] = new
        # DO's "(sed post Septuagesimam dicitur)" variant written out raw:
        # the Mass drops the closing alleluia from Septuagesima itself
        # (MissalProperEntry.seasonalAlleluia), so the variant lines go
        for key, e in app.items():
            for f, v in e.items():
                if not isinstance(v, dict):
                    continue
                for side in ("lat", "eng"):
                    t = v.get(side)
                    if isinstance(t, str) and "post Septuagesimam" in t:
                        ls = t.split("\n")
                        out, i = [], 0
                        while i < len(ls):
                            if re.match(r"^\(sed post Septuagesimam (dicitur|omittitur)\)\s*$", ls[i].strip()):
                                i += 2 if "dicitur" in ls[i] else 1
                                continue
                            out.append(ls[i])
                            i += 1
                        v[side] = "\n".join(out)
                        report["Septuagesima variants removed"].append((name, key, f))
        # a reference DO's English leaves inside a verse ("V. Ps 103:4 You make…")
        inline_ref = re.compile(r"^((?:V\.|℣\.)\s+)(?:\d )?[A-Z][a-z]+\.? \d+:\d+[\d:,;\- ]*\s+(?=[A-Z])", re.M)
        for key, e in app.items():
            for f, v in e.items():
                if isinstance(v, dict) and isinstance(v.get("eng"), str) and inline_ref.search(v["eng"]):
                    v["eng"] = inline_ref.sub(r"\1", v["eng"])
                    report["inline references removed"].append((name, key, f))
        if "--dry-run" not in sys.argv:
            out = json.dumps(app, ensure_ascii=False, indent=2)
            for d in ASSETS:
                (d / name).write_text(out, encoding="utf-8")
    for k in ("replaced", "added", "realigned", "unreachable removed", "inline references removed", "Septuagesima variants removed", "near"):
        print(f"{k}: {len(report[k])}", dict(Counter((x[0][7:-5], x[2]) for x in report[k])))
        if verbose:
            for x in report[k]:
                print("  ", k, *x, sep=" | ")


if __name__ == "__main__":
    main()
