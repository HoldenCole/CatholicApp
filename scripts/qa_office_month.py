#!/usr/bin/env python3
"""QA harness: check the Divine Office + Mass + calendar resolution for a
given month of 2026, flagging likely issues. REPORT ONLY — makes no changes.

Usage:  python3 scripts/qa_office_month.py 2026 7
"""
import json, sys, os
from pathlib import Path

R = Path(__file__).resolve().parent.parent / "Introibo" / "Resources"
ordo = json.load(open(R / "ordo.json"))
sp = json.load(open(R / "sanctoral_propers.json"))
tp = json.load(open(R / "temporal_propers.json")) if (R / "temporal_propers.json").exists() else {}
commune = json.load(open(R / "commune_office.json"))
sc = json.load(open(R / "saint_commune.json"))
mt = json.load(open(R / "missal_tempora.json"))
ms = json.load(open(R / "missal_sanctoral.json"))
names_en = json.load(open(R / "ordo_names_en.json"))
office_inherit = json.load(open(R / "saint_office_inherit.json")) if (R / "saint_office_inherit.json").exists() else {}

HOUR_KEYS = {
    "Lauds":   ["capitulum_laudes", "hymnus_laudes", "ant_laudes"],
    "Vespers": ["vesperae.capitulum", "hymnus_vespera", "ant_vespera"],
    "Terce":   ["tertia.capitulum"],
    "Sext":    ["capitulum_sexta"],
    "None":    ["capitulum_nona"],
    "Matins":  ["invit", "hymnus_matutinum"],
}


def merged_for(wk, winner, temporal):
    m = {}
    if winner == "sanctoral":
        # Layer to match ContentStore: commune fallback, then a borrowed
        # feast's Office (ex Sancti/MM-DD), then the saint's own proper.
        code = sc.get(wk) or sc.get(wk[:5])
        if code in commune:
            m.update(commune[code])
        src = office_inherit.get(wk) or office_inherit.get(wk[:5])
        if src and src in sp:
            m.update(sp[src])
        if wk in sp:
            m.update(sp[wk])
        if "capitulum_laudes" in m:
            m.setdefault("vesperae.capitulum", m["capitulum_laudes"])
            m.setdefault("tertia.capitulum", m["capitulum_laudes"])
    elif temporal and temporal in tp:
        m.update(tp[temporal])
    return m


def check_day(k, e):
    issues = []
    winner, wk, temporal = e["winner"], e["winnerKey"], e.get("temporal")
    name = e["name"]
    is_vigil = "Vigilia" in name
    is_feria = name.startswith(("Feria", "Sabbato", "Dominica", "Die"))

    # 1) English translation present for the displayed feast name
    if name not in names_en:
        issues.append(f"no English name for {name!r}")

    # 2) Office part coverage (sanctoral feasts, excluding vigils/ferias)
    if winner == "sanctoral" and not is_vigil:
        m = merged_for(wk, winner, temporal)
        code = sc.get(wk) or sc.get(wk[:5])
        has_proper = any(x.startswith(("capitulum", "hymnus", "ant_", "invit")) for x in sp.get(wk, {}))
        if not code and not has_proper:
            issues.append("Office: no commune & no proper → ferial fallback")
        else:
            miss = []
            for hour, keys in HOUR_KEYS.items():
                mm = [kk for kk in keys if kk not in m]
                if mm:
                    miss.append(f"{hour}{mm}")
            if miss:
                issues.append("Office missing: " + " ".join(miss))
        # collect present?
        if wk in sp and "oratio" not in sp[wk]:
            issues.append("no proper collect")

    # 3) Mass proper resolves
    mass = None
    if winner == "sanctoral":
        mass = ms.get(wk) or ms.get(wk[:5])
    else:
        mass = mt.get(wk) or (mt.get(temporal) if temporal else None)
    if mass is None and not is_feria:
        issues.append(f"no Mass proper for winnerKey {wk}")
    elif mass is not None:
        # Check the Mass has the core elements
        core = ["introitus", "oratio", "lectio", "evangelium"]
        miss = [c for c in core if c not in mass]
        if miss:
            issues.append(f"Mass missing {miss}")

    # 4) Colour sanity
    if e.get("color") not in {"white", "red", "green", "violet", "rose", "black"}:
        issues.append(f"odd colour {e.get('color')!r}")

    return issues


def main():
    year, month = int(sys.argv[1]), int(sys.argv[2])
    print(f"=== Office/Mass QA for {year}-{month:02d} ===\n")
    total = flagged = 0
    for day in range(1, 32):
        k = f"{year}-{month:02d}-{day:02d}"
        e = ordo.get(k)
        if not e:
            continue
        total += 1
        issues = check_day(k, e)
        if issues:
            flagged += 1
            print(f"{k}  {e['name'][:44]}")
            print(f"   winner={e['winner']} key={e['winnerKey']} rank={e.get('rank')} colour={e.get('color')}")
            for i in issues:
                print(f"   ⚠ {i}")
            print()
    print(f"--- {flagged}/{total} days flagged ---")


if __name__ == "__main__":
    main()
