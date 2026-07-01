#!/usr/bin/env python3
"""Strip import-provenance metadata from the Office propers JSON.

import_do.py writes `officium` (string) and `rank` (int) provenance keys
into each day's entry in temporal_propers.json / sanctoral_propers.json.
Both apps decode those files as Map<String, Map<String, Hour.Part>>; a
scalar value cannot decode as a Part, so the WHOLE file fails to decode
and the loader silently returns empty — the Office loses every seasonal
and sanctoral proper without any visible error.

This already happened once (fixed in 2aab98a for sanctoral_propers) and
was reintroduced by a later bulk re-import. Run this after ANY regeneration
of the propers files, for both platforms' copies. The Android unit test
AssetsDecodeTest fails if this is forgotten.

Run from repo root:  python3 scripts/strip_propers_metadata.py
"""
import json
import os

FILES = ["temporal_propers.json", "sanctoral_propers.json"]
ROOTS = ["android/app/src/main/assets", "Introibo/Resources"]


def strip(path):
    with open(path) as f:
        data = json.load(f)
    removed = 0
    for key, entry in data.items():
        if not isinstance(entry, dict):
            continue
        for k in [k for k, v in entry.items() if not isinstance(v, dict)]:
            del entry[k]
            removed += 1
    with open(path, "w") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write("\n")
    return removed


def main():
    for name in FILES:
        for root in ROOTS:
            p = os.path.join(root, name)
            if not os.path.exists(p):
                print(f"skip {p} (absent)")
                continue
            n = strip(p)
            print(f"{p}: removed {n} scalar metadata values")


if __name__ == "__main__":
    main()
