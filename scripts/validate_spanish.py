#!/usr/bin/env python3
"""Validate the spanish-translation staging folder against the bundled sources.

Guards the future integration: every Spanish file must align slug-for-slug and
line-for-line with its English/Latin source, so merging can never silently
misalign a prayer. Run from repo root:  python3 scripts/validate_spanish.py
"""
import json
import sys
from pathlib import Path

SRC = Path("Introibo/Resources")
ES = Path("spanish-translation")

failures = []


def check(cond, msg):
    if not cond:
        failures.append(msg)


def validate_prayers():
    path = ES / "prayers_es.json"
    if not path.exists():
        print("prayers_es.json: not present (skipped)")
        return
    src = {p["slug"]: p for p in json.load(open(SRC / "prayers.json"))}
    es = json.load(open(path))
    check(set(es) == set(src),
          f"prayers: slug mismatch — missing {set(src) - set(es)}, extra {set(es) - set(src)}")
    for slug, entry in es.items():
        if slug not in src:
            continue
        check(isinstance(entry.get("title_es"), str) and entry["title_es"].strip(),
              f"prayers[{slug}]: empty title_es")
        want = len(src[slug].get("lines", []))
        got = len(entry.get("lines_es", []))
        check(want == got, f"prayers[{slug}]: line count {got} != source {want}")
        for i, line in enumerate(entry.get("lines_es", [])):
            check(isinstance(line, str) and line.strip(),
                  f"prayers[{slug}].lines_es[{i}]: empty")
    print(f"prayers_es.json: {len(es)} prayers checked")


def validate_keyed(name, src_name, required_fields):
    path = ES / name
    if not path.exists():
        print(f"{name}: not present (skipped)")
        return
    src_slugs = {x["slug"] for x in json.load(open(SRC / src_name))}
    es = json.load(open(path))
    keys = {k for k in es if not k.startswith("_")}
    check(keys == src_slugs,
          f"{name}: slug mismatch — missing {src_slugs - keys}, extra {keys - src_slugs}")
    for slug in keys & src_slugs:
        for field in required_fields:
            check(isinstance(es[slug].get(field), str) and es[slug][field].strip(),
                  f"{name}[{slug}]: empty {field}")
    print(f"{name}: {len(keys)} entries checked")


def main():
    validate_prayers()
    validate_keyed("marian_antiphons_es.json", "marian_antiphons.json",
                   ["title_es", "body_es", "versicle_es", "collect_es"])
    validate_keyed("hours_es.json", "hours.json",
                   ["name_es", "time_es", "intro_es"])
    # ui_strings_es.json has no bundled source; just require valid JSON + strings.
    ui = ES / "ui_strings_es.json"
    if ui.exists():
        d = json.load(open(ui))
        for k, v in d.items():
            check(isinstance(v, str) and v.strip(), f"ui_strings[{k}]: empty")
        print(f"ui_strings_es.json: {len(d)} strings checked")

    if failures:
        print("\nFAILURES:")
        for f in failures:
            print(" -", f)
        sys.exit(1)
    print("\nAll Spanish staging files aligned.")


if __name__ == "__main__":
    main()
