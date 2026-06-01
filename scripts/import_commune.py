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
    """feast-key -> commune code. Picks up both `vide CXX` (3rd/4th-class
    saints that take the whole common Office) and a top-level `@Commune/CXX`
    include (major feasts that have a proper Office but inherit a few parts —
    e.g. the Matins invitatory & hymn — from their common, like Ss Peter &
    Paul → C1). Keyed by the full file stem so -r/-t variants resolve to their
    own common."""
    out = {}
    for fn in sorted(os.listdir(SANCTI_LAT)):
        m0 = re.match(r"(\d{2}-\d{2}[a-z0-9]*)\.txt$", fn)
        if not m0:
            continue
        key = m0.group(1)
        secs = IDO.parse_do_file(SANCTI_LAT / fn)
        text = (SANCTI_LAT / fn).read_text(encoding="utf-8", errors="replace")

        code = None
        # 1. The Office common is declared at the top of the [Rule] section as
        #    "ex CXX" or "vide CXX".
        rule = "\n".join(secs.get("Rule", []))
        m = re.search(r"\b(?:ex|vide)\s+(C\d+[a-z]*(?:-\d+)?)\b", rule)
        if m:
            code = m.group(1)
        # 2. Fallbacks: a `vide CXX` anywhere, then a top-level `@Commune/CXX`.
        if not code:
            m = re.search(r"vide\s+(C\d+[a-z]*(?:-\d+)?)", text)
            code = m.group(1) if m else None
        if not code:
            m = re.search(r"(?m)^@Commune/(C\d+[a-z]*(?:-\d+)?)\b", text)
            code = m.group(1) if m else None
        if code:
            out[key] = code
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


def extract_office_inherit():
    """feast-key -> source feast-key, for feasts whose [Rule] borrows the
    Office from another feast via `ex Sancti/MM-DD` (e.g. the Exaltation of
    the Cross 09-14 takes its hymns/antiphons from the Holy Cross office 05-03,
    St Michael 09-29 from 05-08). The source's parts fill whatever the target
    doesn't define; the target's own proper still wins."""
    out = {}
    for fn in sorted(os.listdir(SANCTI_LAT)):
        m0 = re.match(r"(\d{2}-\d{2}[a-z0-9]*)\.txt$", fn)
        if not m0:
            continue
        key = m0.group(1)
        secs = IDO.parse_do_file(SANCTI_LAT / fn)
        rule = "\n".join(secs.get("Rule", []))
        m = re.search(r"\bex\s+Sancti/(\d{2}-\d{2}[a-z0-9]*)", rule)
        if m and m.group(1) != key:
            out[key] = m.group(1)
    return out


def extract_office_vide():
    """feast-key -> source feast-key, for feasts whose Office *is* another
    feast's entirely (`vide Sancti/MM-DD`): the translated Ss Philip & James
    (05-11 → 05-01), the Four Crowned Martyrs (11-08 → 11-01), the Octave of
    the Immaculate Conception (12-15 → 12-08). DO ships these with an empty or
    stub Office file and resolves the date to the source feast. Unlike the
    partial `ex Sancti` borrow, the target carries no Office of its own, so it
    must also inherit the source's *commune* (the structural Little Chapter /
    Hymn) — handled in main()."""
    out = {}
    for fn in sorted(os.listdir(SANCTI_LAT)):
        m0 = re.match(r"(\d{2}-\d{2}[a-z0-9]*)\.txt$", fn)
        if not m0:
            continue
        key = m0.group(1)
        secs = IDO.parse_do_file(SANCTI_LAT / fn)
        rule = "\n".join(secs.get("Rule", []))
        m = re.search(r"\bvide\s+Sancti/(\d{2}-\d{2}[a-z0-9]*)", rule)
        if m and m.group(1) != key:
            out[key] = m.group(1)
    return out


def _raw_section_lines(sections, sec_name):
    """Return the raw lines for *sec_name*, or None if absent."""
    if sec_name not in sections:
        return None
    return sections[sec_name]


def _strip_psalm_suffix(line):
    """Remove trailing ``;;NNN`` (or ``;;NNN;NNN;NNN``) psalm-number markers."""
    return re.sub(r";;[\d;]+\s*$", "", line).strip()


def _antiphon_lines_from_raw(raw_lines):
    """Given the raw content lines of an ``[Ant …]`` section, return only the
    actual antiphon text lines (non-empty, non-comment, non-directive) with
    psalm suffixes stripped.  Returns a list of strings."""
    out = []
    for line in raw_lines:
        s = line.strip()
        if not s:
            continue
        # Skip comments / rubrical conditionals / directives
        if s.startswith(("#", "!", "(", "v.")):
            continue
        # Skip @-references (we handle those at a higher level)
        if s.startswith("@"):
            continue
        out.append(_strip_psalm_suffix(s))
    return out


def _resolve_ant_section(sections, sec_name, file_path, lang_root, _depth=0):
    """Resolve an ``[Ant Vespera]`` or ``[Ant Laudes]`` section to its list of
    5 antiphon-text lines, following ``@:`` self-references and ``@Commune/``
    cross-file redirects.

    Returns a list of antiphon strings (ideally 5), or an empty list on
    failure.  *_depth* guards against infinite loops.
    """
    if _depth > 5:
        return []
    raw = _raw_section_lines(sections, sec_name)
    if raw is None:
        return []

    # Check for single-line redirects that cover the whole section.
    non_empty = [l.strip() for l in raw if l.strip()
                 and not l.strip().startswith(("#", "!", "("))]

    # --- Self-reference: ``@:Ant Vespera`` (with optional sed suffix) --------
    if len(non_empty) == 1 and non_empty[0].startswith("@:"):
        ref = non_empty[0][2:]  # e.g. "Ant Vespera: s/;;.*//g" or "Ant Vespera"
        target_sec = ref.split(":")[0].strip()
        return _resolve_ant_section(sections, target_sec, file_path, lang_root,
                                    _depth + 1)

    # --- Cross-file redirect: ``@Commune/CXX`` (whole section) --------------
    if len(non_empty) == 1 and re.match(r"@Commune/(C\d+[A-Za-z0-9]*(?:-\d+)?)\s*$",
                                         non_empty[0]):
        m = re.match(r"@Commune/(C\d+[A-Za-z0-9]*(?:-\d+)?)", non_empty[0])
        target_code = m.group(1)
        target_file = lang_root / "Commune" / f"{target_code}.txt"
        if target_file.exists():
            target_secs = IDO.parse_do_file(target_file)
            return _resolve_ant_section(target_secs, sec_name, target_file,
                                        lang_root, _depth + 1)
        return []

    # --- Plain antiphon lines (possibly mixed with per-line @ refs) ----------
    # For sections whose lines are individual @-references to single antiphon
    # lines in other sections/files (e.g. C11), we attempt line-by-line
    # resolution, but only for simple ``@Commune/CXX:Section:N`` patterns.
    result = []
    for line in raw:
        s = line.strip()
        if not s or s.startswith(("#", "!", "(")):
            continue
        if s.startswith("@:"):
            # Per-line self-reference: ``@:SectionName:N`` — take line N from
            # that section (1-indexed).
            parts = s[2:].split(":")
            target_sec = parts[0].strip()
            line_idx = None
            for p in parts[1:]:
                p = p.strip()
                if p.isdigit():
                    line_idx = int(p)
                    break
            target_lines = _raw_section_lines(sections, target_sec)
            if target_lines and line_idx is not None:
                # DO line indices are 1-based, pointing into *antiphon* lines
                ant_lines = _antiphon_lines_from_raw(target_lines)
                if 1 <= line_idx <= len(ant_lines):
                    result.append(ant_lines[line_idx - 1])
            elif target_lines and line_idx is None:
                # Whole-section redirect (handled above for single-line case)
                resolved = _antiphon_lines_from_raw(target_lines)
                result.extend(resolved)
        elif s.startswith("@Commune/"):
            # Cross-file per-line reference.
            # Formats: @Commune/C7::1        (empty section, line 1)
            #          @Commune/C6:Ant Matutinum:7 s/95/121/
            #          @Commune/C11           (whole-section redirect)
            m = re.match(
                r"@Commune/(C\d+[A-Za-z0-9]*(?:-\d+)?)"
                r"(?::([^:]*?))?(?::(\d+))?"
                r"(?:\s+s/.*)?$", s)
            if m:
                target_code = m.group(1)
                target_sec = m.group(2).strip() if m.group(2) else ""
                target_sec = target_sec or sec_name
                line_idx = int(m.group(3)) if m.group(3) else None
                target_file = lang_root / "Commune" / f"{target_code}.txt"
                if target_file.exists():
                    target_secs = IDO.parse_do_file(target_file)
                    if line_idx is not None:
                        target_lines = _raw_section_lines(target_secs, target_sec)
                        if target_lines:
                            ant_lines = _antiphon_lines_from_raw(target_lines)
                            if 1 <= line_idx <= len(ant_lines):
                                result.append(ant_lines[line_idx - 1])
                    else:
                        resolved = _resolve_ant_section(target_secs, target_sec,
                                                        target_file, lang_root,
                                                        _depth + 1)
                        result.extend(resolved)
        elif s.startswith("@"):
            # Other @-references (e.g. @Sancti/...) — skip, too specific
            continue
        else:
            result.append(_strip_psalm_suffix(s))

    return result


def extract_psalm_antiphons(code, lat_sections, eng_sections, lat_file, eng_file):
    """Extract the 5 per-psalm antiphons for Vespers and Lauds from a commune's
    parsed sections.  Returns a dict of app-key -> {lat, eng, type, variationKey}
    entries, or an empty dict if the commune has no psalm antiphons."""
    parts = {}

    for hour, do_sec, key_prefix in (
        ("vesperae", "Ant Vespera", "vesperae.antiphon.psalm"),
        ("laudes",   "Ant Laudes", "laudes.antiphon.psalm"),
    ):
        lat_ants = _resolve_ant_section(lat_sections, do_sec, lat_file, DO_LAT)
        eng_ants = _resolve_ant_section(eng_sections, do_sec, eng_file, DO_ENG) \
            if eng_sections else []

        # Fallback: when the English file lacks the section entirely but the
        # Latin file has cross-references, build a merged section dict that
        # has the Latin structure (for the missing section) plus English content
        # (for self-referenced sub-sections like Ant VesperaBMV), then replay
        # the resolution against English commune files.
        if not eng_ants and lat_ants and eng_sections and do_sec not in eng_sections:
            merged = dict(eng_sections)
            # Copy only the missing structural section from Latin
            if do_sec in lat_sections:
                merged[do_sec] = lat_sections[do_sec]
            eng_ants = _resolve_ant_section(merged, do_sec, eng_file, DO_ENG)

        if not lat_ants:
            continue

        # Pad English list to match Latin length
        while len(eng_ants) < len(lat_ants):
            eng_ants.append("")

        for i, (lat, eng) in enumerate(zip(lat_ants[:5], eng_ants[:5]), start=1):
            app_key = f"{key_prefix}{i}"
            parts[app_key] = {
                "lat": lat,
                "eng": eng,
                "type": "antiphon",
                "variationKey": app_key,
            }

    return parts


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

    # Per-psalm antiphons for Vespers and Lauds
    psalm_ants = extract_psalm_antiphons(code, lat_sections, eng_sections,
                                         lat_file, eng_file)
    parts.update(psalm_ants)

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

    # Feast→feast Office inheritance, kept only where the source actually has
    # Office parts to give.
    sp = json.loads((OUT_IOS / "sanctoral_propers.json").read_text())
    def has_office(key):
        return any(k.startswith(("capitulum", "hymnus", "ant_", "invit", "versum"))
                   for k in sp.get(key, {}))
    office_inherit = {t: s for t, s in extract_office_inherit().items() if has_office(s)}

    # Whole-Office borrows (`vide Sancti/XX`): the target has no Office of its
    # own, so inherit both the source's proper parts AND its commune (for the
    # structural Little Chapter/Hymn the proper doesn't carry).
    vide = extract_office_vide()
    # Translated feasts whose horas file DO ships *empty* (the calendar engine
    # redirects the date, so `vide Sancti/...` lives only in the Mass file):
    # the 1962 translation of Ss Philip & James to 05-11, May 1 having become
    # St Joseph the Worker. Its Office is that of 05-01.
    vide.setdefault("05-11", "05-01")
    for t, s in vide.items():
        if not has_office(s):
            continue
        office_inherit.setdefault(t, s)
        if t not in saint_commune and s in saint_commune:
            saint_commune[t] = saint_commune[s]

    for out_dir in (OUT_IOS, OUT_ANDROID):
        (out_dir / "commune_office.json").write_text(
            json.dumps(commune_office, ensure_ascii=False, indent=1, sort_keys=True))
        (out_dir / "saint_commune.json").write_text(
            json.dumps(saint_commune, ensure_ascii=False, indent=1, sort_keys=True))
        (out_dir / "saint_office_inherit.json").write_text(
            json.dumps(office_inherit, ensure_ascii=False, indent=1, sort_keys=True))

    print(f"communes resolved: {len(commune_office)} / {len(codes)} codes")
    print(f"saints mapped:     {len(saint_commune)}")
    print(f"office-inherit map: {len(office_inherit)} feasts")
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
