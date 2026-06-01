#!/usr/bin/env python3
"""The September Ember Days (Quattuor Temporum Septembris — the Wed/Fri/Sat
of the September ember week) carry their own proper Office and Mass in
DivinumOfficium's Tempora/093-N files. The ordo generator keyed them by their
week-after-Pentecost position (pentNN-X), where the Office/Mass are merely
ferial. Redirect those days to 093-X (the suffix — 3=Wed, 5=Fri, 6=Sat — is
identical in both DO numbering schemes), fixing the ferial-fallback Office and
the empty Mass at once.

The Advent, Lenten, and Whitsun ember days are unaffected: their week keys
(adv3-N, quad1-N, pasc7-N) already hold the proper content.
"""
import json, re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DIRS = [ROOT / "Introibo" / "Resources", ROOT / "android" / "app" / "src" / "main" / "assets"]
ORDO_FILES = ["ordo.json", "ordo_1955.json", "ordo_pre1955.json"]

EMBER_SEPT = re.compile(r"Quattuor Temporum Septembr")


def fix_ordo(ordo):
    n = 0
    for k, e in ordo.items():
        if e.get("winner") != "temporal":
            continue
        if not EMBER_SEPT.search(e.get("name", "")):
            continue
        wk = e.get("winnerKey", "")
        m = re.search(r"-(\d)$", wk)
        if not m:
            continue
        target = f"093-{m.group(1)}"
        if wk == target:
            continue
        e["winnerKey"] = target
        e["temporal"] = target
        n += 1
    return n


def main():
    # iOS is the source of truth; mirror to Android.
    src = DIRS[0]
    for fn in ORDO_FILES:
        ordo = json.loads((src / fn).read_text())
        n = fix_ordo(ordo)
        blob = json.dumps(ordo, ensure_ascii=False, indent=2)
        for d in DIRS:
            (d / fn).write_text(blob)
        print(f"{fn}: redirected {n} September ember days -> 093-N")


if __name__ == "__main__":
    main()
