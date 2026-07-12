#!/usr/bin/env python3
"""Import the pre-1955 Octave-of-Epiphany Matins lessons from DivinumOfficium.

DO's Sancti/01-07..01-13 files default to the OLD-RITE octave office (the
1962 ferial "Die Septima Januarii" reading is the `(rubrica 196…)` branch).
The app's original import took the 1962 branch, so pre-1955 users see plain
Christmastide ferias during the octave.

This extracts Lectio4..Lectio9 (Matins nocturns II-III — the festive lessons
the o-variant overlay mechanism layers on) choosing the OLD-RITE branch of
each rubric conditional, and writes them into sanctoral_propers.json as
"MM-DDo" overlay keys (both platform copies). The app applies them for the
PRE_1955 rite only, on top of the base "MM-DD" office.

Needs a DivinumOfficium checkout at /tmp/do_repo (sparse: web/www/horas).
Run from repo root:  python3 scripts/import_epiphany_octave.py
"""
import json
import re
from pathlib import Path

DO_LAT = Path("/tmp/do_repo/web/www/horas/Latin/Sancti")
DO_ENG = Path("/tmp/do_repo/web/www/horas/English/Sancti")
DAYS = [f"01-{d:02d}" for d in range(7, 13)]  # Jan 7-12 (Jan 13's office already imported)
LESSONS = [f"Lectio{n}" for n in range(4, 10)]

TARGETS = [
    "android/app/src/main/assets/sanctoral_propers.json",
    "Introibo/Resources/sanctoral_propers.json",
]


def sections(path):
    """Parse a DO file into {section: [lines]}."""
    out, cur = {}, None
    for raw in path.read_text(encoding="utf-8").splitlines():
        m = re.match(r"\[(.+?)\]\s*$", raw)
        if m:
            cur = m.group(1)
            out[cur] = []
        elif cur is not None:
            out[cur].append(raw)
    return out


def old_rite_text(lines):
    """Resolve rubric conditionals, keeping the OLD-RITE (default/tridentine)
    branch: text before any condition is the default; a `(… rubrica …)` line
    starts a branch that applies only under the named rubrics — skip branches
    naming the newer books (1955/1960/196/newcal), keep tridentina/divino ones.
    """
    out, skipping = [], False
    for line in lines:
        m = re.match(r"\((?:sed\s+)?(?:.*\brubrica\b.*)\)\s*$", line.strip())
        if m:
            cond = line.lower()
            skipping = any(t in cond for t in ("196", "1955", "1960", "newcal", "monastica"))
            continue
        if not skipping:
            out.append(line)
    # Drop DO reference/citation markers; keep body text.
    body = [l for l in out if not l.startswith("!")]
    text = "\n".join(body).strip()
    text = re.sub(r"\n{3,}", "\n\n", text)
    text = text.replace("&teDeum", "").replace("_", "").strip()
    return text


def extract(day):
    lat = sections(DO_LAT / f"{day}.txt")
    eng_path = DO_ENG / f"{day}.txt"
    eng = sections(eng_path) if eng_path.exists() else {}
    parts = {}
    for lesson in LESSONS:
        if lesson not in lat:
            continue
        lat_text = old_rite_text(lat[lesson])
        eng_text = old_rite_text(eng.get(lesson, []))
        if not lat_text:
            continue
        key = lesson.lower()
        parts[key] = {
            "type": "reading",
            "variationKey": key,
            "lat": lat_text,
            "eng": eng_text,
        }
    return parts


def main():
    overlays = {}
    for day in DAYS:
        parts = extract(day)
        if parts:
            overlays[f"{day}o"] = parts
            print(f"{day}o: {len(parts)} lessons")
    if not overlays:
        raise SystemExit("nothing extracted — is /tmp/do_repo present?")

    for target in TARGETS:
        data = json.load(open(target))
        data.update(overlays)
        with open(target, "w") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
            f.write("\n")
        print(f"updated {target} (+{len(overlays)} overlay keys)")


if __name__ == "__main__":
    main()
