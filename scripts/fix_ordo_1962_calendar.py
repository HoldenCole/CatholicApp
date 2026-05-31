#!/usr/bin/env python3
"""Fix confirmed 1962-calendar accuracy bugs in ordo.json, verified against
DivinumOfficium's authoritative 1960/1962 Kalendarium chain.

Each fix only applies when the SANCTORAL feast wins that date (Sundays/higher
temporal days that legitimately outrank the feast are left untouched), and only
to ordo.json (the 1962 rite). The 1955 and pre-1955 ordos are correct as-is —
these feasts genuinely differed before 1960.

Bugs fixed (all span every year in the data):
  07-03  St Leo  -> St Irenaeus (1960 moved Irenaeus here)
  07-21  St Praxedes -> St Lawrence of Brindisi, Dr (1960 new 3cl; Praxedes commem)
  08-08  Ss Cyriacus & co -> St John Vianney (1960 moved Vianney to Aug 8)
  08-09  St John Vianney -> Vigil of St Lawrence (Vianney vacated Aug 9)

Commemoration cleanups (feast abolished in the 1962 calendar):
  05-03  drop commemoration of the Finding of the Holy Cross (abolished 1960)
  11-08  drop commemoration of the Octave of All Saints (abolished 1955)
"""
import json
from pathlib import Path

ORDO = Path("/home/user/CatholicApp/Introibo/Resources/ordo.json")
ANDROID = Path("/home/user/CatholicApp/android/app/src/main/assets/ordo.json")

# date -> replacement when winner == 'sanctoral'
NAME_FIXES = {
    "07-03": {"winnerKey": "07-03r", "name": "S. Irenæi Episcopi et Martyris",
              "rank": 3.0, "color": "red", "commem_from_old_name": True},
    "07-21": {"winnerKey": "07-21r",
              "name": "S. Laurentii a Brundusio Confessoris et Ecclesiæ Doctoris",
              "rank": 3.0, "color": "white", "commem_keep": "07-21"},
    "08-08": {"winnerKey": "08-09", "name": "S. Joannis Mariæ Vianney Confessoris",
              "rank": 3.0, "color": "white", "commem_keep": "08-08"},
    "08-09": {"winnerKey": "08-09t", "name": "In Vigilia S. Laurentii Mart.",
              "rank": 3.0, "color": "violet"},
}
# date -> abolished commemoration key to clear
COMMEM_DROPS = {"05-03": "05-03", "11-08": "11-08"}

# Christmas-octave reduction (1960): Dec 29 & 31 become the within-octave day
# (temporal wins, "Die N infra octavam Nativitatis", 4th class) with the former
# saint demoted to a commemoration — exactly as Dec 30 already resolves. Only
# applied when our ordo still shows the saint as the sanctoral winner.
# (Dec 26/27/28 — the comites Christi: Stephen/John/Innocents — keep their feasts.)
OCTAVE_FIXES = {
    "12-29": {"temporal": "nat04", "name": "Die Quinta infra Octavam Nativitatis",
              "commem": "12-29"},
    "12-31": {"temporal": "nat06", "name": "Die Septima infra Octavam Nativitatis",
              "commem": "12-31"},
}


def apply(path, label):
    data = json.loads(path.read_text())
    changes = 0
    for key in sorted(data):
        mmdd = key[5:]
        e = data[key]
        if mmdd in NAME_FIXES and e.get("winner") == "sanctoral":
            fix = NAME_FIXES[mmdd]
            # preserve any existing temporal commemoration
            e["winnerKey"] = fix["winnerKey"]
            e["sanctoral"] = fix["winnerKey"]
            e["name"] = fix["name"]
            e["rank"] = fix["rank"]
            e["color"] = fix["color"]
            if fix.get("commem_keep") and not e.get("commemoration"):
                e["commemoration"] = fix["commem_keep"]
            changes += 1
        if mmdd in COMMEM_DROPS and e.get("commemoration") == COMMEM_DROPS[mmdd]:
            e["commemoration"] = None
            changes += 1
        if mmdd in OCTAVE_FIXES and e.get("winner") == "sanctoral":
            fix = OCTAVE_FIXES[mmdd]
            e["winner"] = "temporal"
            e["winnerKey"] = fix["temporal"]
            e["name"] = fix["name"]
            e["rank"] = 1.0
            e["color"] = "white"
            e["commemoration"] = fix["commem"]
            changes += 1
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2))
    print(f"{label}: {changes} entries updated")


def main():
    apply(ORDO, "iOS  ordo.json")
    if ANDROID.exists():
        apply(ANDROID, "Android ordo.json")


if __name__ == "__main__":
    main()
