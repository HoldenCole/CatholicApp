#!/usr/bin/env python3
"""office_conclusions.json: the conclusion Divinum Officium prints after each
collect (Per Dóminum / Per eúndem / Qui vivis / Qui tecum, with or without
'ejúsdem'), keyed by the collect's normalised text (compare.norm: accents,
j/i, u/v and punctuation folded). The propers assets carry the collects
without DO's "$Per Dominum" markers; the apps look the conclusion up here
and fall back to the classical rule when a collect is not in the table.

    python3 scripts/office_qa/build_office_conclusions.py --do DIR
"""
import argparse, glob, json, os, re, sys
sys.path.insert(0, os.path.dirname(__file__))
from compare import norm  # noqa: E402

KINDS = [("Per Dóminum", "PD"), ("Per eúndem", "PE"), ("Qui vivis", "QV"), ("Qui tecum", "QT"), ("Per Christum", "PC")]

def kind(line):
    l = line.replace("Iesum", "Jesum")
    for k, code in KINDS:
        if l.startswith(k):
            return code + ("e" if re.search(r"e[ij]úsdem", l) else "")
    return None

def main():
    ap = argparse.ArgumentParser(); ap.add_argument("--do", required=True); ap.add_argument("--out", default="Introibo/Resources/office_conclusions.json")
    a = ap.parse_args()
    table = {}; conflicts = 0
    for f in sorted(glob.glob(f"{a.do}/*/*/*.json")):
        d = json.load(open(f))
        for sec in d["sections"]:
            ls = sec["lines"]
            for i, l in enumerate(ls):
                if l != "Orémus." or i + 2 >= len(ls):
                    continue
                j = i + 1
                if j + 1 < len(ls) and not re.search(r"[,:;.]", ls[j]):
                    j += 1  # a rubric title before the collect
                body, nxt = ls[j], ls[j + 1] if j + 1 < len(ls) else ""
                k = kind(nxt)
                if not k:
                    continue
                key = norm(body)
                if key in table and table[key] != k:
                    conflicts += 1
                    continue
                table[key] = k
    out = {"_doc": "collect (compare.norm) -> conclusion code: PD Per Dóminum, PE Per eúndem, QV Qui vivis, QT Qui tecum, PC Per Christum; suffix e = ejúsdem Spíritus Sancti", "collects": dict(sorted(table.items()))}
    for path in (a.out, a.out.replace("Introibo/Resources", "android/app/src/main/assets")):
        with open(path, "w", encoding="utf-8") as fh:
            json.dump(out, fh, ensure_ascii=False, indent=1); fh.write("\n")
    from collections import Counter
    print(len(table), "collects;", conflicts, "conflicts;", Counter(table.values()))

if __name__ == "__main__":
    main()
