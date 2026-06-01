#!/usr/bin/env python3
"""Import the Commune (common Office) data from DivinumOfficium so that
3rd/4th-class saints without their own proper Office parts inherit the
correct Capitulum, Hymn, Versicle, and Benedictus/Magnificat antiphons.

Produces two files (bundled on iOS + Android):
  commune_office.json  — { commune_code: { app_key: {lat,eng,type,variationKey} } }
  saint_commune.json   — { "MM-DD": "commune_code" }

The DO→app key mapping is explicit because DO numbers its versicles and
antiphons by hour position (Vespers = "1", Lauds = "2") whereas the app
keys them by hour name.
"""
import sys, re, os, json
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import import_do as IDO

DO_LAT = IDO.DO_HORAS_LATIN
DO_ENG = IDO.DO_HORAS_ENGLISH
COMMUNE_LAT = DO_LAT / "Commune"
SANCTI_LAT = DO_LAT / "Sancti"

ROOT = Path(__file__).resolve().parent.parent
OUT_IOS = ROOT / "Introibo" / "Resources"
OUT_ANDROID = ROOT / "android" / "app" / "src" / "main" / "assets"

# DO commune section name -> (app variationKey, part type)
# Lauds: capitulum_laudes, hymnus_laudes, versum_1 (versicle), ant_laudes (Benedictus)
# Vespers: vesperae.capitulum, hymnus_vespera, versum_2 (versicle), ant_vespera (Magnificat)
SECTION_MAP = {
    # Lauds
    "Capitulum Laudes": ("capitulum_laudes", "capitulum"),
    "Hymnus Laudes":    ("hymnus_laudes", "hymn"),
    "Versum 2":         ("versum_1", "vr"),       # DO "Versum 2" is the Lauds versicle
    "Ant 2":            ("ant_laudes", "antiphon"), # DO "Ant 2" is the Benedictus antiphon
    # Vespers
    "Hymnus Vespera":   ("hymnus_vespera", "hymn"),
    "Versum 1":         ("versum_2", "vr"),       # DO "Versum 1" is the Vespers versicle
    "Ant 1":            ("ant_vespera", "antiphon"), # DO "Ant 1" is the Magnificat antiphon
    # Little Hours
    "Capitulum Sexta":  ("capitulum_sexta", "capitulum"),
    "Capitulum Nona":   ("capitulum_nona", "capitulum"),
    "Responsory Breve Tertia": ("responsory_breve_tertia", "responsory"),
    "Responsory Breve Sexta":  ("responsory_breve_sexta", "responsory"),
    "Responsory Breve Nona":   ("responsory_breve_nona", "responsory"),
    "Lectio Prima":     ("lectio_prima", "reading"),
    # Matins (structural — invitatory + hymn; lessons stay proper)
    "Invit":            ("invit", "antiphon"),
    "Hymnus Matutinum": ("hymnus_matutinum", "hymn"),
}


def clean_antiphon(text):
    """Strip DO psalm-number markers (`;;109`) and parenthetical alleluia
    hints, and take only the first antiphon if several are listed."""
    first = text.split("\n")[0]
    first = re.sub(r";;\d+\s*$", "", first).strip()
    return first


def extract_saint_commune():
    """feast-key -> commune code, from each saint file's first `vide CXX`.
    Keyed by the full file stem (incl. -r/-t variants, e.g. "07-21r") so a
    1960-reformed feast resolves to its own commune rather than the base
    date's saint."""
    out = {}
    for fn in sorted(os.listdir(SANCTI_LAT)):
        m0 = re.match(r"(\d{2}-\d{2}[a-z0-9]*)\.txt$", fn)
        if not m0:
            continue
        key = m0.group(1)
        text = (SANCTI_LAT / fn).read_text(encoding="utf-8", errors="replace")
        m = re.search(r"vide\s+(C\d+[a-z]*(?:-\d+)?)", text)
        if m:
            out[key] = m.group(1)
    return out


def section_text(sections, sec_name, lang_path, lang_root):
    if sec_name not in sections:
        return None
    try:
        return IDO.process_section_text(
            sections[sec_name], lang_path, lang_root, sections,
            english=(lang_root == DO_ENG), section_name=sec_name,
        ).strip()
    except Exception:
        # Fall back to a naive join if the processor chokes on a macro
        return "\n".join(sections[sec_name]).strip()


def _parent_code(code):
    """A variant commune file (e.g. C4a) inherits everything from a base via a
    leading `@Commune/CX` directive. Return that base code, if any."""
    lat_file = COMMUNE_LAT / f"{code}.txt"
    if not lat_file.exists():
        return None
    for line in lat_file.read_text(encoding="utf-8", errors="replace").splitlines():
        line = line.strip()
        if not line:
            continue
        m = re.match(r"@Commune/(C\d+[a-z]*(?:-\d+)?)\s*$", line)
        return m.group(1) if m else None
    return None


def build_commune(code, _seen=None):
    """Resolve one commune code's Office parts (Latin + English), merging the
    inherited parent commune as a base when the file declares `@Commune/CX`."""
    _seen = _seen or set()
    if code in _seen:
        return {}
    _seen.add(code)

    lat_file = COMMUNE_LAT / f"{code}.txt"
    eng_file = DO_ENG / "Commune" / f"{code}.txt"
    if not lat_file.exists():
        return None

    # Start from the inherited parent's parts (recursively), then override.
    parent = _parent_code(code)
    parts = dict(build_commune(parent, _seen) or {}) if parent else {}

    lat_sections = IDO.parse_do_file(lat_file)
    eng_sections = IDO.parse_do_file(eng_file) if eng_file.exists() else {}

    for do_sec, (app_key, part_type) in SECTION_MAP.items():
        lat = section_text(lat_sections, do_sec, lat_file, DO_LAT)
        if not lat:
            continue
        eng = section_text(eng_sections, do_sec, eng_file, DO_ENG) or ""
        if part_type == "antiphon":
            lat = clean_antiphon(lat)
            eng = clean_antiphon(eng) if eng else ""
        elif part_type == "hymn":
            lat = re.sub(r"^v\.\s*", "", lat)
            eng = re.sub(r"^v\.\s*", "", eng) if eng else ""
        parts[app_key] = {
            "lat": lat,
            "eng": eng,
            "type": part_type,
            "variationKey": app_key,
        }

    # The Little Chapter is the same at Vespers and Terce as at Lauds.
    if "capitulum_laudes" in parts:
        for vk in ("vesperae.capitulum", "tertia.capitulum"):
            if vk not in parts:
                cap = dict(parts["capitulum_laudes"])
                cap["variationKey"] = vk
                parts[vk] = cap

    # In several commons the Lauds hymn IS the Vespers hymn (DO self-reference
    # that doesn't carry the English text). Backfill the missing translation.
    lh, vh = parts.get("hymnus_laudes"), parts.get("hymnus_vespera")
    if lh and vh and not lh.get("eng", "").strip() and vh.get("eng", "").strip():
        if _same_hymn(lh["lat"], vh["lat"]):
            lh["eng"] = vh["eng"]

    return parts or None


def _same_hymn(a, b):
    """True if two hymn texts share their opening line (same hymn)."""
    fa = a.split("\n", 1)[0].strip().lower()
    fb = b.split("\n", 1)[0].strip().lower()
    return fa and fa == fb


def main():
    saint_commune = extract_saint_commune()
    codes = sorted(set(saint_commune.values()))

    commune_office = {}
    for code in codes:
        built = build_commune(code)
        if built:
            commune_office[code] = built

    # Drop saints whose commune produced no usable parts
    saint_commune = {k: v for k, v in saint_commune.items() if v in commune_office}

    for out_dir in (OUT_IOS, OUT_ANDROID):
        (out_dir / "commune_office.json").write_text(
            json.dumps(commune_office, ensure_ascii=False, indent=1, sort_keys=True))
        (out_dir / "saint_commune.json").write_text(
            json.dumps(saint_commune, ensure_ascii=False, indent=1, sort_keys=True))

    print(f"communes resolved: {len(commune_office)} / {len(codes)} codes")
    print(f"saints mapped:     {len(saint_commune)}")
    # Coverage of each part type
    from collections import Counter
    cov = Counter()
    for parts in commune_office.values():
        for k in parts:
            cov[k] += 1
    print("part coverage across communes:")
    for k, n in cov.most_common():
        print(f"  {k}: {n}/{len(commune_office)}")

    if "--sample" in sys.argv:
        c6 = commune_office.get("C6a") or commune_office.get("C6")
        if c6:
            print("\n=== sample C6a/C6 ===")
            for k, v in c6.items():
                print(f"  {k}: lat={v['lat'][:60]!r}")
                print(f"        eng={v['eng'][:60]!r}")


if __name__ == "__main__":
    main()
