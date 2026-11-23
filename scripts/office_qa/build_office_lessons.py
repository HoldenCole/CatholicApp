#!/usr/bin/env python3
"""Build the Matins lesson tables from Divinum Officium's own output.

  build_office_lessons.py --src DIR [--rites 1962,1955,pre1955] [--out DIR ...]

DIR is the output of do_lessons_extract.py (English renders, and Espanol
and Francais ones for the vernacular columns; --langs es,fr).
Texts DO's column lacks in a language take theirs from
<language>-translation/office_lessons_fixes_<code>.json (Latin -> text, by
hand); any still without are listed in office_lessons_missing_<code>.json
beside it.
For every date DO resolves, the lessons of Matins and their responsories
are stored exactly as DO prints them, so the apps read what DO reads
whatever the rule behind it (Scripture occurrens, the month-week books,
the Commons' homilies, contracted and transferred lessons, the ninth
lesson of a commemorated office, ...).

Writes, byte-identically to each --out directory (default: both apps'
asset folders):

  office_lessons.json     {"texts": [{"lat", "eng", "ref"?}], "days": {rite: {date: [[lesson, responsory], ...]}}}
  office_lessons_es.json  [Spanish or null, aligned with "texts"]
  office_lessons_fr.json  [French or null, likewise]

"texts" is de-duplicated across the rites; a responsory index of -1 means DO prints none,
a lesson index of -1 that DO has no text for it (the app keeps its own)
(the Te Deum follows, or the lesson has none).
"""
import argparse, glob, json, os, sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DEFAULT_OUT = [os.path.join(ROOT, "android/app/src/main/assets"), os.path.join(ROOT, "Introibo/Resources")]
DO_NAME = {"es": "Espanol", "fr": "Francais"}
TRANSLATION_DIR = {"es": "spanish-translation", "fr": "french-translation"}


def split(lines):
    """(body lines, first reference, responsory lines) of a lesson section."""
    n = len(lines)
    # "℣. Tu autem / ℟. Deo grátias" closes the lesson: the first ℣. line,
    # answered at once, with no ℟. before it (Tenebrae has no Tu autem, and
    # its responsory's own ℣./℟. pair must not be taken for one).
    first_r = next((i for i in range(n) if lines[i].startswith("℟.")), n)
    tu = next((i for i in range(n - 1)
               if lines[i].startswith("℣.") and lines[i + 1].startswith("℟.") and i < first_r
               and (i + 2 >= n or lines[i + 2] == "")), None)
    if tu is not None:
        body, rest = lines[:tu], lines[tu + 2:]
    else:
        cut = next((i for i in range(n) if lines[i] == "" and i + 1 < n and (lines[i + 1].startswith("℟.") or lines[i + 1].startswith("!"))), n)
        body, rest = lines[:cut], lines[cut:]
    ref = next((l[1:] for l in body if l.startswith("!")), None)
    body = [l for l in body if l and not l.startswith("!")]
    while rest and rest[0] == "": rest = rest[1:]
    resp = []
    if rest and rest[0].startswith("℟."):
        for l in rest:
            if l == "" or l.startswith("!"): break
            resp.append(l)
    return body, ref, resp


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", required=True); ap.add_argument("--rites", default="1962,1955,pre1955")
    ap.add_argument("--out", action="append")
    ap.add_argument("--start", default="", help="first date to include (YYYY-MM-DD); the Office only ever shows today's hours")
    ap.add_argument("--langs", default="es,fr", help="the vernacular columns to build (es,fr)")
    a = ap.parse_args()
    langs = [l for l in a.langs.split(",") if l]
    outs = a.out or DEFAULT_OUT
    texts = []; ver = {l: [] for l in langs}; index = {}; days = {}

    def intern(lat, eng, vs, ref):
        """The index of a text; vs is its vernacular per language (or None)."""
        key = (lat, eng)
        i = index.get(key)
        if i is None:
            i = index[key] = len(texts)
            t = {"lat": lat, "eng": eng}
            if ref: t["ref"] = ref
            texts.append(t)
            for l in langs: ver[l].append(vs.get(l))
        else:
            for l in langs:
                if ver[l][i] is None and vs.get(l): ver[l][i] = vs[l]
        return i

    for rite in a.rites.split(","):
        stats = {"days": 0, "lessons": 0, "misaligned": 0}
        for l in langs: stats["no_" + l] = 0
        days[rite] = {}
        for f in sorted(glob.glob(os.path.join(a.src, "English", rite, "*.json"))):
            date = os.path.basename(f)[:-5]
            if date < a.start: continue
            en = json.load(open(f))["lessons"]
            sp = {}
            for lang in langs:
                g = os.path.join(a.src, DO_NAME[lang], rite, date + ".json")
                sp[lang] = {l["n"]: l for l in json.load(open(g))["lessons"]} if os.path.exists(g) else {}
            row = []
            for k, l in enumerate(en):
                if l["n"] != k + 1: sys.exit("lesson numbering: %s %s %s" % (rite, date, [x["n"] for x in en]))
                lb, ref, lr = split(l["lat"]); eb, _, er = split(l["ver"])
                lat = "\n".join(lb); eng = "\n".join(eb)
                re_ = "\n".join(er)
                body, resp = {}, {}
                for lang in langs:
                    s = sp[lang].get(l["n"])
                    sb = sr = None
                    if s and s["lat"] == l["lat"]:
                        sb, _, sr = split(s["ver"])
                    elif s:
                        stats["misaligned"] += 1
                    # the English or the Latin again is DO's fallback, not a translation
                    t = "\n".join(sb) if sb else None
                    if t is not None and (t == eng or t == lat): t = None
                    if t is None: stats["no_" + lang] += 1
                    body[lang] = t
                    r = "\n".join(sr) if sr else None
                    if r is not None and (r == re_ or r == "\n".join(lr)): r = None
                    resp[lang] = r
                # DO prints the odd lesson as a bare rubric or not at all (a gap in
                # its own files): -1 leaves the app's lesson in place.
                li = intern(lat, eng, body, ref) if lat.strip() else -1
                ri = -1
                if lr:
                    ri = intern("\n".join(lr), re_, resp, None)
                row.append([li, ri]); stats["lessons"] += 1
            days[rite][date] = row; stats["days"] += 1
        print(rite, stats)
    doc = json.dumps({"texts": texts, "days": days}, ensure_ascii=False, separators=(",", ":"))
    for o in outs:
        open(os.path.join(o, "office_lessons.json"), "w").write(doc + "\n")
    print("texts", len(texts), "bytes", len(doc.encode()))
    for lang in langs:
        col = ver[lang]
        d = os.path.join(ROOT, TRANSLATION_DIR[lang])
        fx = os.path.join(d, "office_lessons_fixes_%s.json" % lang)
        fixes = json.load(open(fx)) if os.path.exists(fx) else {}
        for i, t in enumerate(texts):
            if col[i] is None and t["lat"] in fixes: col[i] = fixes[t["lat"]]
        missing = [t for i, t in enumerate(texts) if col[i] is None]
        mf = os.path.join(d, "office_lessons_missing_%s.json" % lang)
        if missing:
            json.dump(missing, open(mf, "w"), ensure_ascii=False, indent=1)
        elif os.path.exists(mf):
            os.remove(mf)
        doc_v = json.dumps(col, ensure_ascii=False, separators=(",", ":"))
        for o in outs:
            open(os.path.join(o, "office_lessons_%s.json" % lang), "w").write(doc_v + "\n")
        print(" ", lang, "with text", sum(1 for x in col if x), "missing", len(missing), "bytes", len(doc_v.encode()))


if __name__ == "__main__":
    main()
