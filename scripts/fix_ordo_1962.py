#!/usr/bin/env python3
"""
1962 ordo repairs from the calendar QA (DO-runtime-verified findings):

- Holy Name Sunday pointed at the DATE's pre-1960 key (e.g. "01-04" = the
  old Octave of the Innocents, whose Mass stub redirects to the
  Circumcision) — a II-class feast served the wrong Mass and office. The
  winner now uses DO's floating key "01-00" (Mass + office data added by
  fix_missal_content.py).
- On Our-Lady-on-Saturday days the commemoration key held the Saturday
  FERIA instead of the day's rank-1 saint (S. Valentine, S. Silverius,
  Ss. Machabees, ...) — the saint's commemoration was lost.
- Jan 5 ferias commemorated the abolished Vigil of Epiphany ("01-05");
  the 1962 books commemorate S. Telesphorus ("01-05cc").
- Transferred feasts (e.g. Annunciation on 2027-04-05) commemorated the
  feria instead of the displaced saint (S. Vincent Ferrer).
- Per-annum ferias are never commemorated: spurious pentNN-D / epiN-D
  commemoration keys on feast days nulled.
- The Vigil of Pentecost was white in all three ordos; the Mass is red.

Idempotent; writes byte-identically to both platforms' assets.
"""

import json
import re
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
RESOURCES = REPO / "Introibo" / "Resources"
ANDROID = REPO / "android" / "app" / "src" / "main" / "assets"

PER_ANNUM_FERIA = re.compile(r"^(pent|epi)\d+-[1-6]$")


def fix_1962(ordo: dict) -> dict:
    holy_name = bvm = jan5 = transfer = spurious = 0
    for date, e in ordo.items():
        mmdd = date[5:]
        name = e.get("name") or ""
        # Holy Name Sunday: floating key.
        if name.startswith("Sanctissimi Nominis Jesu") and e.get("winnerKey") != "01-00":
            e["winnerKey"] = "01-00"
            e["sanctoral"] = "01-00"
            holy_name += 1
        # BVM Saturday: commemorate the day's saint, not the feria.
        if e.get("winnerKey") == "bvm-sab" and e.get("sanctoral") \
                and e.get("commemoration") != e["sanctoral"]:
            e["commemoration"] = e["sanctoral"]
            bvm += 1
        # Jan 5 feria: S. Telesphorus, not the abolished vigil.
        if mmdd == "01-05" and e.get("commemoration") == "01-05":
            e["commemoration"] = "01-05cc"
            jan5 += 1
        # Transferred sanctoral winner: commemorate the displaced saint.
        comm = e.get("commemoration") or ""
        if e.get("winner") == "sanctoral" and e.get("winnerKey") != mmdd \
                and e.get("sanctoral") == mmdd and PER_ANNUM_FERIA.match(comm):
            e["commemoration"] = e["sanctoral"]
            transfer += 1
        # Per-annum ferias are never commemorated.
        comm = e.get("commemoration") or ""
        if e.get("winner") == "sanctoral" and PER_ANNUM_FERIA.match(comm):
            e["commemoration"] = None
            spurious += 1
    print(f"  1962: holyName={holy_name} bvmComm={bvm} jan5={jan5} "
          f"transferComm={transfer} spuriousFeriaComm={spurious}")
    return ordo


def fix_pentecost_vigil_color(ordo: dict) -> int:
    n = 0
    for e in ordo.values():
        if (e.get("name") or "").startswith("Sabbato in Vigilia Pentecostes") \
                and e.get("color") != "red":
            e["color"] = "red"
            n += 1
    return n


def write_both(name: str, data) -> None:
    text = json.dumps(data, ensure_ascii=False, indent=2) + "\n"
    for root in (RESOURCES, ANDROID):
        (root / name).write_text(text, encoding="utf-8")


def main():
    ordo = json.loads((RESOURCES / "ordo.json").read_text())
    fix_1962(ordo)
    reds = fix_pentecost_vigil_color(ordo)
    write_both("ordo.json", ordo)

    for name in ("ordo_1955.json", "ordo_pre1955.json"):
        data = json.loads((RESOURCES / name).read_text())
        reds += fix_pentecost_vigil_color(data)
        write_both(name, data)
    print(f"  Pentecost-vigil color -> red on {reds} entries")

    # QA
    check = json.loads((RESOURCES / "ordo.json").read_text())
    for date, e in check.items():
        if (e.get("name") or "").startswith("Sanctissimi Nominis Jesu"):
            assert e["winnerKey"] == "01-00"
        comm = e.get("commemoration") or ""
        if e.get("winner") == "sanctoral":
            assert not PER_ANNUM_FERIA.match(comm), (date, comm)
    print("QA: 1962 ordo assertions passed.")


if __name__ == "__main__":
    main()
