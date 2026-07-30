#!/usr/bin/env python3
"""
Deduplicate doubled saint-name substitutions in the MISSAL propers.

The same fix_collects.py substitution bug that doubled names in the Office
collects ("Faustini et Jovitae et Faustini et Jovitae") also hit the Mass
propers. ONLY the oration-family fields (oratio / secreta / postcommunio)
are touched: readings, graduals, and introits legitimately contain doubled
phrases ("in generationem et generationem", Sirach 44:14) that the same
regex would otherwise clip. Every oration-family match was hand-reviewed:
all are saint-name doublings.

Idempotent; writes byte-identically to both platforms' assets.
"""

import json
import re
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
RESOURCES = REPO / "Introibo" / "Resources"
ANDROID = REPO / "android" / "app" / "src" / "main" / "assets"

DUP = re.compile(r"\b(.{8,80}?)\s+(et|and)\s+\1\b")
ORATION_FIELDS = ("oratio", "secreta", "postcommunio")


def dedupe(data: dict, name: str) -> int:
    fixed = 0
    for entry in data.values():
        if not isinstance(entry, dict):
            continue
        for key, field in entry.items():
            if key.split("_")[0] not in ORATION_FIELDS or not isinstance(field, dict):
                continue
            for lang in ("lat", "eng"):
                text = field.get(lang)
                if not isinstance(text, str):
                    continue
                new = DUP.sub(r"\1", text)
                if new != text:
                    field[lang] = new
                    fixed += 1
    print(f"  {name}: {fixed} field(s) deduplicated")
    return fixed


def main():
    for fname in ("missal_sanctoral.json", "missal_tempora.json"):
        data = json.loads((RESOURCES / fname).read_text())
        dedupe(data, fname)
        text = json.dumps(data, ensure_ascii=False, indent=2) + "\n"
        for root in (RESOURCES, ANDROID):
            (root / fname).write_text(text, encoding="utf-8")
    # QA: no doubled phrases remain in any oration field.
    for fname in ("missal_sanctoral.json", "missal_tempora.json"):
        data = json.loads((RESOURCES / fname).read_text())
        for key, entry in data.items():
            if not isinstance(entry, dict):
                continue
            for fk, field in entry.items():
                if fk.split("_")[0] in ORATION_FIELDS and isinstance(field, dict):
                    for lang in ("lat", "eng"):
                        t = field.get(lang)
                        if isinstance(t, str):
                            assert not DUP.search(t), f"{fname}:{key}.{fk}.{lang}"
    print("QA: no doubled name phrases remain in orations.")


if __name__ == "__main__":
    main()
