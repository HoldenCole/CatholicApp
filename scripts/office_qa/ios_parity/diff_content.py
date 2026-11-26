#!/usr/bin/env python3
"""iOS/Android parity of a vernacular outside the Office and the Mass.

  diff_content.py ANDROID_DIR IOS_DIR LANG

ANDROID_DIR holds ContentAuditDump's content_en.json and content_<LANG>.json;
IOS_DIR the harness's ios_content_en.json and ios_content_<LANG>.json
(CONTENT_AUDIT_OUT). The two platforms' models differ in their fields, so
the comparison is of the strings a language puts in place of the English:
every string the overlay introduces on one platform must be there on the
other, collection by collection.
"""
import json, sys
from collections import Counter

PAIRS = {"prayers": "prayers", "rosary_prayers": "rosaryPrayers", "mysteries": "mysterySets", "stations": "stations",
         "confession_examen": "examen", "confession_guides": "confessionGuides", "missal": "missal",
         "canon_variants": "canonVariants", "marian_antiphons": "marianAntiphons", "martyrology": "martyrology",
         "hours": "hours", "saints": "saints", "reference": "reference", "courses": "courses",
         "daily_psalm": "dailyPsalmES", "ordo_names": "ordoNamesEn"}


def strings(v, acc):
    if isinstance(v, str):
        acc.append(v)
    elif isinstance(v, dict):
        for x in v.values():
            strings(x, acc)
    elif isinstance(v, list):
        for x in v:
            strings(x, acc)
    return acc


def main():
    a, i, lang = sys.argv[1], sys.argv[2], sys.argv[3]
    ae, al = (json.load(open(f"{a}/content_{l}.json")) for l in ("en", lang))
    ie, il = (json.load(open(f"{i}/ios_content_{l}.json")) for l in ("en", lang))
    bad = 0
    for ka, ki in PAIRS.items():
        A = Counter(strings(al[ka], [])) - Counter(strings(ae[ka], []))   # what the language brings, Android
        I = Counter(il.get(ki, [])) - Counter(ie.get(ki, []))             # and iOS
        onlyA, onlyI = A - I, I - A
        n = sum(onlyA.values()) + sum(onlyI.values())
        bad += n
        print(f"{ka:18s} android {sum(A.values()):6d}  ios {sum(I.values()):6d}  differing {n}")
        for s, c in list(onlyA.items())[:3]:
            print("    android only:", c, s[:100].replace("\n", " / "))
        for s, c in list(onlyI.items())[:3]:
            print("    ios only:    ", c, s[:100].replace("\n", " / "))
    print("TOTAL differing strings:", bad)
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
