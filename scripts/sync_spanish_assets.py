#!/usr/bin/env python3
"""Bundle the Spanish content overlay into both app asset directories.

Runs the alignment validator first (a misaligned overlay must never ship),
then copies the three CONTENT files byte-identically into
Introibo/Resources/ and android/app/src/main/assets/.

ui_strings_es.json stays in staging: the UI chrome is hardcoded English on
both platforms and localizing it is a separate pass.
"""

import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
STAGING = ROOT / "spanish-translation"
ASSET_DIRS = [
    ROOT / "Introibo" / "Resources",
    ROOT / "android" / "app" / "src" / "main" / "assets",
]
FILES = [
    "prayers_es.json",
    "marian_antiphons_es.json",
    "hours_es.json",
    "missal_es.json",
    "canon_variants_es.json",
]


def main():
    r = subprocess.run([sys.executable, str(ROOT / "scripts" / "validate_spanish.py")])
    if r.returncode != 0:
        sys.exit("validator failed — not syncing")

    for name in FILES:
        src = STAGING / name
        for d in ASSET_DIRS:
            shutil.copyfile(src, d / name)
        print(f"synced {name}")

    for name in FILES:
        a = (ASSET_DIRS[0] / name).read_bytes()
        b = (ASSET_DIRS[1] / name).read_bytes()
        assert a == b == (STAGING / name).read_bytes(), name
    print("QA OK — asset copies byte-identical to staging")


if __name__ == "__main__":
    main()
