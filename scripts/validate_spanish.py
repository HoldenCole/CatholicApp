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
        src_lines = src[slug].get("lines", [])
        for i, line in enumerate(entry.get("lines_es", [])):
            check(isinstance(line, str), f"prayers[{slug}].lines_es[{i}]: not a string")
            # Blank separator lines in the source stay blank in Spanish.
            src_blank = i < len(src_lines) and not (
                (src_lines[i].get("lat") or "").strip()
                or (src_lines[i].get("eng") or "").strip()
            )
            if not src_blank:
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


def validate_missal():
    """missal_es.json is PARTIAL by design (the Ordinary translates section
    by section); covered sections must align line-for-line with the source
    body, rubrics included."""
    path = ES / "missal_es.json"
    if not path.exists():
        print("missal_es.json: not present (skipped)")
        return
    src = {s["slug"]: s for s in json.load(open(SRC / "missal.json"))}
    es = json.load(open(path))
    for slug, entry in es.items():
        if slug.startswith("_"):
            continue
        check(slug in src, f"missal[{slug}]: no such section in missal.json")
        if slug not in src:
            continue
        body = entry.get("body_es", [])
        want = len(src[slug].get("body", []))
        check(len(body) == want, f"missal[{slug}]: line count {len(body)} != source {want}")
        for i, line in enumerate(body):
            check(isinstance(line.get("eng_es"), str) and line["eng_es"].strip(),
                  f"missal[{slug}].body_es[{i}]: empty eng_es")
            src_rubric = (src[slug]["body"][i].get("rubric") or "").strip() \
                if i < want else ""
            got_rubric = line.get("rubric_es")
            if src_rubric:
                check(isinstance(got_rubric, str) and got_rubric.strip(),
                      f"missal[{slug}].body_es[{i}]: source has a rubric, rubric_es empty")
            else:
                check(got_rubric is None,
                      f"missal[{slug}].body_es[{i}]: rubric_es present, source has none")
    print(f"missal_es.json: {len(es)} sections checked (partial coverage OK)")


def validate_canon_variants():
    path = ES / "canon_variants_es.json"
    if not path.exists():
        print("canon_variants_es.json: not present (skipped)")
        return
    src = json.load(open(SRC / "canon_variants.json"))
    es = json.load(open(path))
    for group, entries in es.items():
        check(group in src, f"canon_variants[{group}]: no such group")
        for key, entry in entries.items():
            check(key in src.get(group, {}),
                  f"canon_variants[{group}][{key}]: no such variant")
            check(isinstance(entry.get("eng_es"), str) and entry["eng_es"].strip(),
                  f"canon_variants[{group}][{key}]: empty eng_es")
    # The 1962 St Joseph insertion anchors on this exact phrase — it must
    # appear exactly once in the standard Communicantes and every variant.
    anchor = ": y también de tus bienaventurados Apóstoles"
    missal = ES / "missal_es.json"
    if missal.exists():
        canon = json.load(open(missal)).get("canon", {})
        comm = [l for l in canon.get("body_es", [])
                if l.get("eng_es", "").startswith("Unidos en una misma comunión")]
        for l in comm:
            check(l["eng_es"].count(anchor) == 1, "missal[canon]: Joseph anchor count != 1")
    for key, entry in es.get("communicantes", {}).items():
        check(entry.get("eng_es", "").count(anchor) == 1,
              f"canon_variants[communicantes][{key}]: Joseph anchor count != 1")
    n = sum(len(v) for v in es.values())
    print(f"canon_variants_es.json: {n} variants checked")


def validate_ordo_names():
    path = ES / "ordo_names_es.json"
    if not path.exists():
        print("ordo_names_es.json: not present (skipped)")
        return
    en = json.load(open(SRC / "ordo_names_en.json"))
    es = json.load(open(path))
    extra = set(es) - set(en)
    check(not extra, f"ordo_names: {len(extra)} keys not in ordo_names_en (e.g. {sorted(extra)[:3]})")
    for k, v in es.items():
        check(isinstance(v, str) and v.strip(), f"ordo_names[{k}]: empty")
    print(f"ordo_names_es.json: {len(es)}/{len(en)} names checked")


def validate_missal_propers():
    """Tranche-based propers overlay: keys must be real formularies, fields
    must stay inside the imported set (scripture ships separately in
    missal_readings_es.json), values must be clean text."""
    path = ES / "missal_propers_es.json"
    if not path.exists():
        print("missal_propers_es.json: not present (skipped)")
        return
    tempora = json.load(open(SRC / "missal_tempora.json"))
    sanctoral = json.load(open(SRC / "missal_sanctoral.json"))
    allowed = {"introitus", "oratio", "graduale", "alleluia", "tractus",
               "offertorium", "secreta", "communio", "postcommunio"}
    es = json.load(open(path))
    for key, fields in es.items():
        check(key in tempora or key in sanctoral,
              f"missal_propers[{key}]: no such formulary")
        src = tempora.get(key) or sanctoral.get(key) or {}
        for field, text in fields.items():
            check(field in allowed,
                  f"missal_propers[{key}].{field}: field not importable "
                  "(scripture belongs in missal_readings_es.json)")
            check(isinstance(text, str) and text.strip(),
                  f"missal_propers[{key}].{field}: empty")
            check(src.get(field) is not None,
                  f"missal_propers[{key}].{field}: English side has no such field")
            for bad in ("@", "&Gloria", "\n$"):
                check(bad not in text,
                      f"missal_propers[{key}].{field}: DO markup left in text")
    n = sum(len(v) for v in es.values())
    print(f"missal_propers_es.json: {len(es)} formularies / {n} fields checked")


def validate_missal_readings():
    """Scripture overlay (Torres Amat): keys must be real formularies, only
    the two reading fields, non-empty text with no module markup, and the
    English side must carry the field being replaced."""
    path = ES / "missal_readings_es.json"
    if not path.exists():
        print("missal_readings_es.json: not present (skipped)")
        return
    tempora = json.load(open(SRC / "missal_tempora.json"))
    sanctoral = json.load(open(SRC / "missal_sanctoral.json"))
    es = json.load(open(path))
    for key, fields in es.items():
        check(key in tempora or key in sanctoral,
              f"missal_readings[{key}]: no such formulary")
        src = tempora.get(key) or sanctoral.get(key) or {}
        for field, text in fields.items():
            check(field in ("lectio", "evangelium"),
                  f"missal_readings[{key}].{field}: not a reading field")
            check(isinstance(text, str) and text.strip(),
                  f"missal_readings[{key}].{field}: empty")
            check(src.get(field) is not None,
                  f"missal_readings[{key}].{field}: English side has no such field")
            for bad in ("<CM>", "</b>", "<", ">", "  "):
                check(bad not in text,
                      f"missal_readings[{key}].{field}: markup/artifact in text")
    n = sum(len(v) for v in es.values())
    print(f"missal_readings_es.json: {len(es)} days / {n} fields checked")


def validate_stations():
    """Stations of the Cross: every station covered, all three fields, and
    the Stabat verse keeps the source's line structure (<br> count)."""
    path = ES / "stations_es.json"
    if not path.exists():
        print("stations_es.json: not present (skipped)")
        return
    src = {s["station"]: s for s in json.load(open(SRC / "stations.json"))}
    es = json.load(open(path))
    check(set(es) == set(src),
          f"stations: key mismatch (missing {set(src) - set(es)}, "
          f"extra {set(es) - set(src)})")
    for key, o in es.items():
        check(set(o) == {"title_es", "med_es", "stabat_es"},
              f"stations[{key}]: fields must be title_es/med_es/stabat_es")
        for f, v in o.items():
            check(isinstance(v, str) and v.strip(), f"stations[{key}].{f}: empty")
        if key in src:
            check(o["stabat_es"].count("<br>") == src[key]["stabat_eng"].count("<br>"),
                  f"stations[{key}].stabat_es: <br> count differs from source")
    print(f"stations_es.json: {len(es)} stations checked")


def validate_saints():
    """Saints' devotional programs: every saint covered, and the index-aligned
    lists (sections, practices per section, prayers) match the source counts
    exactly — a silent mismatch would leave English behind at runtime."""
    path = ES / "saints_es.json"
    if not path.exists():
        print("saints_es.json: not present (skipped)")
        return
    src = {s["slug"]: s for s in json.load(open(SRC / "saints.json"))}
    es = json.load(open(path))
    check(set(es) == set(src),
          f"saints: slug mismatch (missing {set(src) - set(es)}, "
          f"extra {set(es) - set(src)})")
    for slug, o in es.items():
        s = src.get(slug)
        if not s:
            continue
        for f in ("name_es", "title_es", "quote_es", "penance_es"):
            check(isinstance(o.get(f), str) and o[f].strip(),
                  f"saints[{slug}].{f}: empty/missing")
        check(len(o.get("sections_es", [])) == len(s["sections"]),
              f"saints[{slug}]: section count differs from source")
        for i, (sec_es, sec) in enumerate(zip(o.get("sections_es", []),
                                              s["sections"])):
            check(sec_es.get("eng_es", "").strip(),
                  f"saints[{slug}].sections[{i}].eng_es: empty")
            check(len(sec_es.get("practices_es", [])) == len(sec["practices"]),
                  f"saints[{slug}].sections[{i}]: practice count differs")
            for j, p in enumerate(sec_es.get("practices_es", [])):
                check(p.get("t_es", "").strip() and p.get("d_es", "").strip(),
                      f"saints[{slug}].sections[{i}].practices[{j}]: empty")
        check(len(o.get("prayers_es", [])) == len(s["prayers"]),
              f"saints[{slug}]: prayer count differs from source")
        for i, p in enumerate(o.get("prayers_es", [])):
            check(p.get("title_es", "").strip() and p.get("eng_es", "").strip(),
                  f"saints[{slug}].prayers[{i}]: empty")
    print(f"saints_es.json: {len(es)} saints checked")


def main():
    validate_prayers()
    validate_ordo_names()
    validate_missal_propers()
    validate_missal_readings()
    validate_stations()
    validate_saints()
    validate_keyed("marian_antiphons_es.json", "marian_antiphons.json",
                   ["title_es", "body_es", "versicle_es", "collect_es"])
    validate_keyed("hours_es.json", "hours.json",
                   ["name_es", "time_es", "intro_es"])
    validate_missal()
    validate_canon_variants()
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
