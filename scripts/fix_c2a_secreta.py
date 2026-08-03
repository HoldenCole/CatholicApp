#!/usr/bin/env python3
"""Fix the two days that wrongly carry the C2a martyr's secret.

DO's Tempora/Quadp1-0 (Septuagesima) resolves its [Secreta] via
@Commune/C2a; the earlier commune expansion took the MISSA C2a secret
("Accépta sit in conspéctu tuo … pro cujus sollemnitáte defértur" — a
martyr's-feast text) instead of the intended "Munéribus nostris" prayer.
The 1962 Missale assigns "Munéribus nostris, quǽsumus, Dómine …" as the
secret of BOTH Septuagesima Sunday and the Circumcision (Jan 1) — the same
prayer Advent Ember Friday already carries correctly in our data.

The martyr's text remains correct everywhere else it appears (the
single-martyr sanctoral feasts and C2a itself).

Idempotent; writes byte-identically to both asset dirs.
"""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ASSET_DIRS = [
    ROOT / "Introibo" / "Resources",
    ROOT / "android" / "app" / "src" / "main" / "assets",
]

LAT = ("Munéribus nostris, quǽsumus, Dómine, precibúsque suscéptis: "
       "et cœléstibus nos munda mystériis, et cleménter exáudi.\n"
       "Per Dóminum nostrum Jesum Christum, Fílium tuum: qui tecum vivit et "
       "regnat in unitáte Spíritus Sancti, Deus, per ómnia sǽcula sæculórum. "
       "Amen.")
ENG = ("As thou hast received our gifts and prayers, O Lord, cleanse us, we "
       "ask by thy heavenly mysteries, and graciously hear us.\n"
       "Through our Lord Jesus Christ, Thy Son, Who liveth and reigneth with "
       "Thee in the unity of the Holy Ghost, God, world without end. Amen.")

WRONG = "Accépta sit in conspéctu tuo"


def fix(path, key):
    d = json.load(open(path, encoding="utf-8"))
    entry = d[key]
    changed = False
    if WRONG in entry["secreta"]["lat"]:
        entry["secreta"]["lat"] = LAT
        entry["secreta"]["eng"] = ENG
        changed = True
    assert entry["secreta"]["lat"].startswith("Munéribus nostris"), key
    text = json.dumps(d, ensure_ascii=False, indent=2) + "\n"
    path.write_text(text, encoding="utf-8")
    return changed


def main():
    for name, key in [("missal_tempora.json", "quadp1-0"),
                      ("missal_sanctoral.json", "01-01")]:
        results = [fix(d / name, key) for d in ASSET_DIRS]
        print(f"{name}[{key}]: {'fixed' if any(results) else 'already correct'}")
    for name in ("missal_tempora.json", "missal_sanctoral.json"):
        a = (ASSET_DIRS[0] / name).read_bytes()
        b = (ASSET_DIRS[1] / name).read_bytes()
        assert a == b, name
    print("QA OK")


if __name__ == "__main__":
    main()
