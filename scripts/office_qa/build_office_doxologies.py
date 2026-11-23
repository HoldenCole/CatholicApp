#!/usr/bin/env python3
"""Build office_doxologies.json from a Divinum Officium checkout.

  build_office_doxologies.py --do /path/to/divinum-officium

In the older books (not under the 1960 rubrics) a hymn whose last stanza DO
marks with "*" takes the doxology of the feast or season (hymni.pl:
gethymn, doxology). The asset carries the two things the apps need:

  "starred"     the hymns so marked, by their first two lines (lowercase,
                no accents or punctuation)
  "doxologies"  Psalterium/Doxologies.txt: name -> {lat, eng, es, fr?}

Written byte-identically to both apps' asset folders.
"""
import argparse, glob, json, os, re, unicodedata

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = [os.path.join(ROOT, "android/app/src/main/assets"), os.path.join(ROOT, "Introibo/Resources")]


def norm(s):
    s = unicodedata.normalize("NFD", s.lower())
    s = "".join(c for c in s if unicodedata.category(c) != "Mn")
    s = s.replace("æ", "ae").replace("œ", "oe")
    return re.sub(r"\s+", " ", re.sub(r"[^a-z ]", " ", s)).strip()


def sections(path):
    name = None; out = {}
    for line in open(path, encoding="utf-8", errors="replace").read().split("\n"):
        m = re.match(r"^\[([^\]]+)\]\s*(\(.*\))?\s*$", line)
        if m:
            name = m.group(1) if not m.group(2) else None   # skip rubric-conditional variants
            if name is not None: out.setdefault(name, [])
            continue
        if name is not None: out[name].append(line.rstrip())
    return out


def doxologies(do, lang):
    secs = sections(os.path.join(do, "web/www/horas", lang, "Psalterium/Doxologies.txt"))
    out = {k: "\n".join(l.replace("[", "").replace("]", "") for l in v if l.strip()) for k, v in secs.items()}
    # "@:Nat": the same text as another doxology
    return {k: out.get(v[2:], v) if v.startswith("@:") else v for k, v in out.items()}


if __name__ == "__main__":
    ap = argparse.ArgumentParser(); ap.add_argument("--do", required=True); a = ap.parse_args()
    starred = set()
    base = os.path.join(a.do, "web/www/horas/Latin")
    for f in glob.glob(base + "/**/*.txt", recursive=True):
        for name, lines in sections(f).items():
            if not name.startswith("Hymnus") or not any(l.startswith("*") for l in lines): continue
            body = [re.sub(r"^v\.\s*", "", re.sub(r"^\{[^}]*\}", "", l)) for l in lines]
            text = [l for l in body if l.strip() and not l.startswith(("!", "@", "_", "(", "/"))]
            # two lines: "Verbum supérnum pródiens" opens two different hymns
            if len(text) >= 2: starred.add(norm(text[0] + " " + text[1]))
    lat = doxologies(a.do, "Latin"); eng = doxologies(a.do, "English"); es = doxologies(a.do, "Espanol")
    fr = doxologies(a.do, "Francais")
    dox = {k: {"lat": lat[k], "eng": eng.get(k) or lat[k], "es": es.get(k) or eng.get(k) or lat[k]} for k in sorted(lat) if not k.endswith("T")}
    for k, v in dox.items():
        if fr.get(k): v["fr"] = fr[k]   # absent: the apps fall back to English
    doc = json.dumps({"starred": sorted(starred), "doxologies": dox}, ensure_ascii=False, indent=1) + "\n"
    for o in OUT: open(os.path.join(o, "office_doxologies.json"), "w").write(doc)
    print(len(starred), "starred hymns;", {k: (v["eng"] != v["lat"], v["es"] != v["eng"], "fr" in v) for k, v in dox.items()})
