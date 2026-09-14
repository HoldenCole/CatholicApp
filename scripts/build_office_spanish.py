#!/usr/bin/env python3
"""Spanish for the Divinum Officium office assets (office_psalterium,
office_commune, office_propers_<rite>), gathered from the Spanish the app
already carries for the same Latin texts (the hours, the weekly psalter,
the commons, the temporal and sanctoral propers, the seasonal hymns, the
prayers and the Marian antiphons).

Writes spanish-translation/office_texts_es.json: { normalised Latin ->
Spanish }. Both apps apply it to every Latin text of the DO assets (parts'
lat/latR/antiphonLat, antiphon lists' ant/v/r) when the vernacular is
Spanish; a Latin text without an entry keeps its English.

  python3 scripts/build_office_spanish.py [--report]
"""
import json, re, sys, unicodedata
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / "android" / "app" / "src" / "main" / "assets"
ES = ROOT / "spanish-translation"


def norm(t):
    """The key both apps compute: NFC, <br>/~ as spaces, whitespace collapsed."""
    t = unicodedata.normalize("NFC", t or "")
    t = re.sub(r"<br\s*/?>", " ", t)
    t = t.replace("~", " ").replace(" ", " ")
    return re.sub(r"\s+", " ", t).strip()


def load(p):
    return json.load(open(p, encoding="utf-8"))


def es_text(t):
    if not isinstance(t, str):
        return None
    t = unicodedata.normalize("NFC", t)
    t = re.sub(r"<br\s*/?>", "\n", t)
    t = t.strip()
    return t or None


def main():
    report = "--report" in sys.argv
    corpus = {}
    conflicts = Counter()

    def add(lat, es, src):
        k = norm(lat)
        e = es_text(es)
        if not k or not e or len(k) < 4:
            return
        # an overlay field left in Latin, or a DO marker, is no translation
        if norm(e) == k or e.startswith("$"):
            return
        if k in corpus and corpus[k] != e:
            conflicts[src] += 1
            return  # first source wins (the hours and psalter come first)
        corpus.setdefault(k, e)

    # 1. The hours' fixed parts.
    hours = {h["slug"]: h for h in load(ASSETS / "hours.json")}
    for slug, idx in load(ES / "hours_parts_es.json").items():
        parts = hours.get(slug, {}).get("parts", [])
        for i, o in idx.items():
            if not i.isdigit() or int(i) >= len(parts):
                continue
            p = parts[int(i)]
            for lf, ef in (("lat", "eng"), ("latR", "engR"), ("antiphonLat", "antiphonEng"),
                           ("v1Lat", "v1Eng"), ("r1Lat", "r1Eng"), ("v2Lat", "v2Eng"), ("r2Lat", "r2Eng")):
                if p.get(lf) and o.get(ef):
                    add(p[lf], o[ef], "hours")
    # 2. The weekly psalter's parts (antiphons, capitula, versicles, hymns).
    pw = load(ASSETS / "psalter_weekly.json")
    for day, m in load(ES / "psalter_weekly_parts_es.json").items():
        for key, es in m.items():
            p = (pw.get(day) or {}).get(key)
            if isinstance(p, dict):
                lat = p.get("antiphonLat") if isinstance(es, str) and p.get("antiphonLat") and not p.get("lat") else p.get("lat")
                if isinstance(es, str) and lat:
                    add(lat, es, "psalter_weekly")
                elif isinstance(es, dict):
                    for lf, ef in (("lat", "eng"), ("latR", "engR"), ("antiphonLat", "antiphonEng")):
                        if p.get(lf) and es.get(ef):
                            add(p[lf], es[ef], "psalter_weekly")
    # 3. The Office commons, propers and seasonal hymns.
    PAIRS = (("lat", "eng"), ("latR", "engR"), ("antiphonLat", "antiphonEng"),
             ("v1Lat", "v1Eng"), ("r1Lat", "r1Eng"), ("v2Lat", "v2Eng"), ("r2Lat", "r2Eng"))
    for sname, ename in (("commune_office.json", "commune_office_es.json"),
                         ("temporal_propers.json", "temporal_propers_es.json"),
                         ("sanctoral_propers.json", "sanctoral_propers_es.json"),
                         ("hymns_seasonal.json", "hymns_seasonal_es.json")):
        src = load(ASSETS / sname)
        for code, entry in load(ES / ename).items():
            for fk, o in entry.items():
                p = (src.get(code) or {}).get(fk)
                if not isinstance(p, dict) or not isinstance(o, dict):
                    continue
                for lf, ef in PAIRS:
                    if p.get(lf) and o.get(ef):
                        add(p[lf], o[ef], sname)
    # 4. Supplements keyed "commune:C12:responsory3:eng".
    co = load(ASSETS / "commune_office.json")
    for key, es in load(ES / "hours_supplements_es.json").items():
        m = re.match(r"^commune:([^:]+):([^:]+):(eng|engR|antiphonEng)$", key)
        if not m or not isinstance(es, str):
            continue
        p = (co.get(m.group(1)) or {}).get(m.group(2)) or {}
        lf = {"eng": "lat", "engR": "latR", "antiphonEng": "antiphonLat"}[m.group(3)]
        if p.get(lf):
            add(p[lf], es, "supplements")
    # 5. Prayers and the Marian antiphons.
    pr_es = load(ES / "prayers_es.json")
    for pr in load(ASSETS / "prayers.json"):
        o = pr_es.get(pr["slug"])
        if not o:
            continue
        lines = pr.get("lines") or []
        es_lines = o.get("lines_es") or []
        for l, e in zip(lines, es_lines):
            if isinstance(l, dict) and l.get("lat") and e:
                add(l["lat"], e, "prayers")
    ma_es = load(ES / "marian_antiphons_es.json")
    for m in load(ASSETS / "marian_antiphons.json"):
        o = ma_es.get(m["slug"])
        if o and o.get("body_es") and m.get("lat"):
            add(m["lat"], o["body_es"], "marian")

    # A looser index: without the ℣./℟. marks, the antiphon asterisk and
    # the final punctuation, case-folded (the legacy assets keep versicles
    # bare and place the asterisk differently).
    def loose(k):
        k = re.sub(r"^(℣\.|℟\.|V\.|R\.|v\.|r\.|Ant\.)\s*", "", k)
        k = k.replace("*", " ").replace("†", " ")
        k = re.sub(r"\s+", " ", k).strip().rstrip(".,;:").lower()
        return k
    loose_ix = {}
    for k, e in corpus.items():
        loose_ix.setdefault(loose(k), e)

    # Apply to the DO assets: whole text, else line by line.
    def lookup(lat):
        k = norm(lat)
        if k in corpus:
            return corpus[k]
        if loose(k) in loose_ix and len(loose(k)) >= 8:
            return loose_ix[loose(k)]
        lines = [l for l in re.split(r"\n|<br\s*/?>", lat or "")]
        if len([l for l in lines if l.strip()]) > 1:
            out = []
            for l in lines:
                if not l.strip():
                    out.append("")
                    continue
                e = corpus.get(norm(l))
                if e is None and len(loose(norm(l))) >= 8:
                    e = loose_ix.get(loose(norm(l)))
                if e is None:
                    return None
                out.append(e)
            return "\n".join(out).strip()
        return None

    used = {}
    stats = Counter()
    missing_examples = []

    def try_text(lat, where):
        if not lat or not norm(lat):
            return
        es = lookup(lat)
        if es is None:
            stats[where + ":missing"] += 1
            if len(missing_examples) < 40:
                missing_examples.append((where, norm(lat)[:90]))
        else:
            stats[where + ":ok"] += 1
            k = norm(lat)
            if k in corpus:
                used[k] = corpus[k]
            else:
                used[k] = es  # a line-by-line join: store the whole text too

    def walk(entry, where):
        for sk, part in (entry.get("parts") or {}).items():
            if not isinstance(part, dict):
                continue
            if sk == "Rule" or part.get("type") in ("script", "commemoration", "rubric"):
                # scripts and commemoration blocks carry DO markup; their
                # pieces are matched line by line at render time
                for l in re.split(r"\n", part.get("lat") or ""):
                    if l and not re.match(r"^[#!$&_(@/]", l):
                        try_text(re.sub(r"^(Ant\.|V\.|R\.|v\.|r\.)\s*", "", l), where + "/script")
                continue
            for f in ("lat", "latR", "antiphonLat"):
                if part.get(f):
                    try_text(part[f], where)
        for name, lines in (entry.get("psalmi") or {}).items():
            for l in lines:
                for f in ("ant", "v", "r"):
                    if l.get(f):
                        try_text(l[f], where + "/psalmi")

    walk(load(ASSETS / "office_psalterium.json"), "psalterium")
    for code, entry in load(ASSETS / "office_commune.json").items():
        walk(entry, "commune")
    for rite in ("1962", "1955", "pre1955"):
        for key, entry in load(ASSETS / f"office_propers_{rite}.json").items():
            walk(entry, "propers")

    out = ES / "office_texts_es.json"
    with open(out, "w", encoding="utf-8") as f:
        json.dump(dict(sorted(used.items())), f, ensure_ascii=False, indent=1)
        f.write("\n")
    print(f"corpus {len(corpus)} Latin texts; {len(used)} used by the DO assets -> {out.relative_to(ROOT)}")
    if conflicts:
        print("conflicting Spanish (first source kept):", dict(conflicts))
    for k in sorted(stats):
        print(f"  {k}: {stats[k]}")
    if report:
        for w, l in missing_examples:
            print("   missing", w, "|", l)


if __name__ == "__main__":
    main()
