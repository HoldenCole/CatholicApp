#!/usr/bin/env python3
"""Bundle the French content overlay into both app asset directories.

Copies every french-translation/*_fr.json overlay byte-identically into
Introibo/Resources/ and android/app/src/main/assets/, after checking that
each one still lines up with the source file it overlays (an overlay that
is out of step with its Latin must never ship). The working files beside
them (*_fixes_fr.json, *_missing_fr.json) stay out of the apps.

French is built language by language of the same overlay schemas as
Spanish; a file French does not have yet is simply absent, and the apps
fall back to English for it.
"""
import json
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
STAGING = ROOT / "french-translation"
ASSET_DIRS = [
    ROOT / "Introibo" / "Resources",
    ROOT / "android" / "app" / "src" / "main" / "assets",
]
ASSETS = ASSET_DIRS[1]


def load(p):
    return json.load(open(p, encoding="utf-8"))


def check(name, data):
    """Alignment errors of one overlay against its source asset."""
    errs = []
    if name == "psalter_fr.json":
        src = load(ASSETS / "psalter.json")
        for k, v in data.items():
            if k not in src:
                errs.append(f"{k}: no such psalm")
            elif len(v["lines"]) != len(src[k]["lat"]):
                errs.append(f"{k}: {len(v['lines'])} lines for {len(src[k]['lat'])} Latin")
    elif name in ("missal_propers_fr.json", "missal_readings_fr.json"):
        src = {**load(ASSETS / "missal_tempora.json"), **load(ASSETS / "missal_sanctoral.json")}
        for k, fields in data.items():
            for f, text in fields.items():
                lat = ((src.get(k) or {}).get(f) or {}).get("lat")
                if lat is None:
                    errs.append(f"{k}.{f}: no such field")
                elif len(text.split("\n")) != len(lat.split("\n")) and f != "sequentia":
                    # (a Sequence's French may keep DO's stanzas whole)
                    errs.append(f"{k}.{f}: line count differs from the Latin")
    elif name == "office_lessons_fr.json":
        n = len(load(ASSETS / "office_lessons.json")["texts"])
        if len(data) != n:
            errs.append(f"{len(data)} entries for {n} texts")
    elif name == "missal_fr.json":
        src = {s["slug"]: s for s in load(ASSETS / "missal.json")}
        for slug, s in src.items():
            o = data.get(slug)
            if o is None:
                errs.append(f"{slug}: section missing")   # the apps need every line of a section
            elif len(o["body_fr"]) != len(s["body"]):
                errs.append(f"{slug}: {len(o['body_fr'])} lines for {len(s['body'])}")
            elif any(not l.get("eng_fr") for l in o["body_fr"]):
                errs.append(f"{slug}: an empty line")
    elif name == "canon_variants_fr.json":
        for g, v in load(ASSETS / "canon_variants.json").items():
            for k in v:
                if not ((data.get(g) or {}).get(k) or {}).get("eng_fr"):
                    errs.append(f"{g}.{k}: missing")
    elif name == "hours_parts_fr.json":
        src = {h["slug"]: h for h in load(ASSETS / "hours.json")}
        for slug, parts in data.items():
            h = src.get(slug)
            if h is None:
                errs.append(f"{slug}: no such hour")
                continue
            for i, o in parts.items():
                if not i.isdigit() or int(i) >= len(h["parts"]):
                    errs.append(f"{slug}.{i}: no such part")
                elif "verses" in o and len(o["verses"]) != len(h["parts"][int(i)].get("verses") or []):
                    errs.append(f"{slug}.{i}: verse count differs")
    elif name == "rosary_prayers_fr.json":
        src = {p["slug"]: p for p in load(ASSETS / "rosary_prayers.json")}
        for k, v in data.items():
            if k not in src or len(v["lines_fr"]) != len(src[k]["lines"]):
                errs.append(f"{k}: lines differ from the source")
    elif name in ("confession_examen_fr.json", "confession_guides_fr.json", "mysteries_fr.json",
                  "stations_fr.json", "hours_fr.json", "daily_psalm_fr.json",
                  "reference_fr.json", "saints_fr.json", "courses_fr.json", "ui_strings_fr.json"):
        # the same shape as the Spanish overlay, which the Spanish validator ties to the source
        es = load(ROOT / "spanish-translation" / name.replace("_fr.json", "_es.json"))
        def shape(x):
            if isinstance(x, dict):
                return {(k[:-3] + "_fr" if k.endswith("_es") else k.replace("_es_", "_fr_")): shape(v) for k, v in x.items()}
            if isinstance(x, list):
                return [shape(v) for v in x]
            return "text" if isinstance(x, str) else type(x).__name__
        if shape(es) != shape(data):
            errs.append("shape differs from the Spanish overlay")
    elif name == "prayers_fr.json":
        src = {p["slug"]: p for p in load(ASSETS / "prayers.json")}
        for k, v in data.items():
            if k not in src:
                errs.append(f"{k}: no such prayer")
            elif len(v["lines_fr"]) != len(src[k]["lines"]):
                errs.append(f"{k}: {len(v['lines_fr'])} lines for {len(src[k]['lines'])}")
    elif name == "martyrology_fr.json":
        src = load(ASSETS / "martyrology.json")
        for k, v in data.get("days", {}).items():
            if len(v["entries_fr"]) != len(src["days"][k]["entries"]):
                errs.append(f"{k}: entry count differs")
    return errs


def main():
    files = sorted(p for p in STAGING.glob("*_fr.json")
                   if "_fixes_" not in p.name and "_missing_" not in p.name)
    bad = 0
    for p in files:
        # office_lessons_fr.json is written straight into the asset folders
        for e in check(p.name, load(p)):
            print(f"MISALIGNED {p.name}: {e}")
            bad += 1
    lessons = ASSETS / "office_lessons_fr.json"
    if lessons.exists():
        for e in check(lessons.name, load(lessons)):
            print(f"MISALIGNED {lessons.name}: {e}")
            bad += 1
    if bad:
        sys.exit("validator failed — not syncing")
    for p in files:
        for d in ASSET_DIRS:
            shutil.copyfile(p, d / p.name)
        print(f"synced {p.name}")
    for p in files:
        a = (ASSET_DIRS[0] / p.name).read_bytes()
        b = (ASSET_DIRS[1] / p.name).read_bytes()
        assert a == b == p.read_bytes(), p.name
    print("QA OK — asset copies byte-identical to staging")


if __name__ == "__main__":
    main()
