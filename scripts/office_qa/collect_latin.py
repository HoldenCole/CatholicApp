#!/usr/bin/env python3
"""Every Latin text the apps render in the Office over a range of days.

  collect_latin.py DUMP_DIR OUT.json

DUMP_DIR is OfficeJsonDump's output (rite/date.json). Writes the distinct
Latin strings of every part (the text, its response, the versicle pairs,
the antiphon) as a sorted JSON list: the texts a vernacular builder has to
find a translation for (build_office_spanish.py --targets OUT.json).
"""
import glob, json, os, sys

FIELDS = ("lat", "latR", "v1", "r1", "v2", "r2", "ant")


def main():
    src, out = sys.argv[1], sys.argv[2]
    seen = set()
    for f in glob.glob(os.path.join(src, "*", "*.json")):
        for parts in json.load(open(f, encoding="utf-8"))["hours"].values():
            for p in parts or []:
                for k in FIELDS:
                    if p.get(k):
                        seen.add(p[k])
    json.dump(sorted(seen), open(out, "w", encoding="utf-8"), ensure_ascii=False, indent=0)
    print(len(seen), "distinct Latin texts ->", out)


if __name__ == "__main__":
    main()
