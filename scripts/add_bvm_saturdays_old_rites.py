#!/usr/bin/env python3
"""Add "Sanctæ Mariæ Sabbato" (Saturday Office of Our Lady) to the old-rite ordos.

The 1962 ordo was generated with BVM Saturdays (winnerKey bvm-sab / bvm-sabN /
bvm-sabP, rank 1.0) but the 1955 and pre-1955 regenerations dropped them, so
those rites show a plain green feria on free Saturdays. The observance predates
all three sets of books — it belongs in every rite.

Rule: for each date where ordo.json has a bvm-sab* winner, if the old-rite row
is a *free feria* (winner == "temporal", rank <= 1.5), replace it with a
BVM-Saturday row mirroring the 1962 shape but keeping the rite's own temporal
key, season, and displaced-feria commemoration. Saturdays the old rite gives to
a saint, an octave day, or an Ember Saturday are left alone — Our Lady's
Saturday office yields to all of those.

Run from repo root:  python3 scripts/add_bvm_saturdays_old_rites.py
"""
import json
from pathlib import Path

ASSET_DIRS = [
    Path("android/app/src/main/assets"),
    Path("Introibo/Resources"),
]
OLD_RITE_ORDOS = ["ordo_1955.json", "ordo_pre1955.json"]


def synthesize(ordo62, ordo_old, label):
    added = 0
    for date, row62 in ordo62.items():
        if not str(row62.get("winnerKey", "")).startswith("bvm-sab"):
            continue
        old = ordo_old.get(date)
        if old is None:
            continue
        if old.get("winner") != "temporal" or (old.get("rank") or 0) > 1.5:
            continue
        ordo_old[date] = {
            "temporal": old.get("temporal"),
            "sanctoral": old.get("sanctoral"),
            "winner": "sanctoral",
            "winnerKey": row62["winnerKey"],
            "rank": 1.0,
            "name": "Sanctæ Mariæ Sabbato",
            "color": "white",
            "season": old.get("season"),
            "commemoration": old.get("temporal"),
        }
        added += 1
    print(f"{label}: {added} BVM Saturdays added")
    return added


def main():
    primary = ASSET_DIRS[0]
    ordo62 = json.load(open(primary / "ordo.json"))
    for name in OLD_RITE_ORDOS:
        data = json.load(open(primary / name))
        if synthesize(ordo62, data, name) == 0:
            continue
        text = json.dumps(data, ensure_ascii=False, indent=2) + "\n"
        for d in ASSET_DIRS:
            (d / name).write_text(text, encoding="utf-8")
            print(f"  wrote {d / name}")


if __name__ == "__main__":
    main()
