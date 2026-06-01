#!/usr/bin/env python3
"""Resolve the correct Collect (oratio) for every sanctoral feast from
DivinumOfficium and write it into sanctoral_propers.json + missal_sanctoral.json
(iOS Resources + Android assets).

DO collect resolution for a saint that has no proper [Oratio]:
  1. read the saint's [Rule] → commune code (`vide CXX`)
  2. resolve that commune's [Oratio] (process_section_text follows the
     commune's own @Commune redirects + s/// substitutions)
  3. substitute the remaining "N." / "N. et N." with the saint's [Name]

This fixes: wrong collects (a different saint's prayer baked in), missing
collects (oratio null), and unsubstituted "N." placeholders — all at once.
"""
import sys, re, json
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import import_do as IDO

LAT, ENG = IDO.DO_HORAS_LATIN, IDO.DO_HORAS_ENGLISH
R = Path(__file__).resolve().parent.parent / "Introibo" / "Resources"
A = Path(__file__).resolve().parent.parent / "android" / "app" / "src" / "main" / "assets"


def oratio_section(secs, path, root):
    """Find the [Oratio]-family section (handles annotated headers like
    '[Oratio] (communi Summorum Pontificum)'), resolve includes/macros, and
    return clean text. Follows a leading @Commune redirect with its s/// subs."""
    name = next((k for k in secs if k == "Oratio" or k.startswith("Oratio")), None)
    if not name:
        return None
    try:
        txt = IDO.process_section_text(secs[name], path, root, secs,
                                       english=(root == ENG), section_name=name).strip()
    except Exception:
        txt = "\n".join(secs[name]).strip()
    if not txt:
        return None
    # Strip rubric-variant alternates: keep only the text before a
    # "(sed rubrica …)" / "(communi …)" annotation block.
    txt = re.split(r"\n\(sed |\n\(communi |\n\(rubrica ", txt)[0].strip()
    return txt or None


def commune_oratio(code, root, depth=0):
    """Resolve a commune's Collect, tolerant of annotated headers
    (`[Oratio] (communi …)`), following a `@Commune/CX` redirect inside the
    Oratio or, when the commune has none, the parent `@Commune/CX` at the top."""
    if depth > 6:
        return None
    p = root / "Commune" / f"{code}.txt"
    if not p.exists():
        return None
    raw = p.read_text(encoding="utf-8", errors="replace").splitlines()

    body, in_orat = [], False
    for line in raw:
        if re.match(r"^\[Oratio\b", line):
            in_orat = True
            continue
        if in_orat and re.match(r"^\[", line):
            break
        if in_orat:
            body.append(line)
    body = [l for l in body if l.strip()]

    if body:
        first = body[0].strip()
        m = re.match(r"@Commune/(C\d+[a-z]*(?:-\d+)?)", first)
        if m:                              # redirect to another commune's collect
            base = commune_oratio(m.group(1), root, depth + 1)
            sub = re.search(r"s/N\\?\./([^/]*)/", first)  # e.g. s/N./N. Vírginis tuæ/
            if base and sub:
                base = base.replace("N.", sub.group(1).strip(), 1)
            return base
        # real collect text — drop DO macro lines, strip leading verse markers
        out = []
        for l in body:
            if l.startswith(("$", "&", "!", "_")) or l.startswith("("):
                continue
            out.append(re.sub(r"^v\.\s*", "", l))
        return "\n".join(out).strip() or None

    # No own Oratio → inherit the parent commune's
    for line in raw[:3]:
        m = re.match(r"^@Commune/(C\d+[a-z]*(?:-\d+)?)", line.strip())
        if m:
            return commune_oratio(m.group(1), root, depth + 1)
    return None


def commune_code(secs):
    for key in ("Rule", "Rank"):
        if key in secs:
            blob = "\n".join(secs[key])
            m = re.search(r"vide\s+(C\d+[a-z]*(?:-\d+)?)", blob)
            if m:
                return m.group(1)
    return None


def name_field(secs):
    """First non-empty, non-annotation line of [Name] (the 1962 form)."""
    if "Name" not in secs:
        return None
    for line in secs["Name"]:
        line = line.strip()
        if line and not line.startswith("(") and not line.startswith("Ant="):
            return line
    return None


def resolve_oratio(key, root):
    """Return the collect text for feast `key` in language `root`, or None.
    The commune code is always taken from the LATIN file (the English Sancti
    file often omits the [Rule]); the [Name] is taken per-language."""
    path = root / "Sancti" / f"{key}.txt"
    lat_path = LAT / "Sancti" / f"{key}.txt"
    if not path.exists() or not lat_path.exists():
        return None
    secs = IDO.parse_do_file(path)
    lat_secs = IDO.parse_do_file(lat_path)
    name = name_field(secs) or name_field(lat_secs)

    # 1. proper [Oratio] on the saint itself
    own = oratio_section(secs, path, root)
    if own:
        return _subst_name(own, name)

    # 2. inherit from the commune (code from the Latin file)
    code = commune_code(lat_secs)
    if not code:
        return None
    cor = commune_oratio(code, root)
    if not cor and root == ENG:
        # English commune file may be a stub without the Oratio/redirect that
        # the Latin chain has; resolve the terminal commune from Latin and
        # fetch its English Oratio.
        term = terminal_oratio_commune(code)
        if term:
            cor = commune_oratio(term, ENG)
    if not cor:
        return None
    return _subst_name(cor, name)


def terminal_oratio_commune(code, depth=0):
    """Follow the LATIN redirect chain to the commune whose [Oratio] is real
    text (not a `@Commune` redirect), and return that code."""
    if depth > 6:
        return code
    p = LAT / "Commune" / f"{code}.txt"
    if not p.exists():
        return code
    raw = p.read_text(encoding="utf-8", errors="replace").splitlines()
    body, in_orat = [], False
    for line in raw:
        if re.match(r"^\[Oratio\b", line):
            in_orat = True
            continue
        if in_orat and re.match(r"^\[", line):
            break
        if in_orat and line.strip():
            body.append(line.strip())
    if body:
        m = re.match(r"@Commune/(C\d+[a-z]*(?:-\d+)?)", body[0])
        return terminal_oratio_commune(m.group(1), depth + 1) if m else code
    for line in raw[:3]:
        m = re.match(r"^@Commune/(C\d+[a-z]*(?:-\d+)?)", line.strip())
        if m:
            return terminal_oratio_commune(m.group(1), depth + 1)
    return code


def _subst_name(text, name):
    if not name:
        return text
    # DO substitutes the [Name] for the "N." placeholder(s).
    text = re.sub(r"\bN\. et N\.\b", name, text)
    text = re.sub(r"\bN\.", name, text)
    return text


# Collects the QA agents confirmed name a DIFFERENT saint (import bug).
WRONG = {"08-05", "08-12", "08-17", "08-20"}


def valid_collect(lat):
    """Reject resolutions that captured an Officium/Rank line or a hour
    preamble instead of the actual collect text."""
    if not lat:
        return False
    if ";;" in lat or "classis" in lat or "Duplex" in lat or "Simplex" in lat:
        return False
    if lat.startswith("℣") or "Dóminus vobíscum" in lat[:40]:
        return False
    if re.search(r"\bN\.", lat):  # unsubstituted placeholder
        return False
    return len(lat) > 25


def needs_fix(orat):
    """True only if the current collect is genuinely broken: absent, or
    carrying an unsubstituted N. placeholder."""
    if orat is None:
        return True
    lat = orat.get("lat", "") if isinstance(orat, dict) else str(orat)
    return bool(re.search(r"\bN\.", lat))


def main():
    sp = json.loads((R / "sanctoral_propers.json").read_text())
    ms = json.loads((R / "missal_sanctoral.json").read_text())

    fixed, skipped_noresolve = [], []
    keys = set(sp.keys()) | set(ms.keys())
    for key in sorted(keys):
        if not re.match(r"^\d{2}-\d{2}[a-z0-9]*$", key):
            continue
        sp_bad = key in sp and needs_fix(sp[key].get("oratio"))
        ms_bad = key in ms and needs_fix(ms[key].get("oratio"))
        if not (sp_bad or ms_bad or key in WRONG):
            continue  # leave correct collects untouched

        lat = resolve_oratio(key, LAT)
        if not valid_collect(lat):
            # Don't write a collect we couldn't fully/cleanly resolve.
            skipped_noresolve.append(key)
            continue
        eng = resolve_oratio(key, ENG) or ""
        collect = {"lat": lat, "eng": eng, "type": "collect", "variationKey": "oratio"}
        if key in sp and (sp_bad or key in WRONG):
            sp[key]["oratio"] = collect
        if key in ms and (ms_bad or key in WRONG):
            ms[key]["oratio"] = collect
        fixed.append((key, lat[:55]))

    if "--dry-run" not in sys.argv:
        for d in (R, A):
            (d / "sanctoral_propers.json").write_text(json.dumps(sp, ensure_ascii=False, indent=1))
            (d / "missal_sanctoral.json").write_text(json.dumps(ms, ensure_ascii=False, indent=1))
    print(f"collects fixed: {len(fixed)}  |  unresolvable (left as-is): {len(skipped_noresolve)}")
    for k, t in fixed:
        print(f"  {k}: {t!r}")
    if skipped_noresolve:
        print("STILL BROKEN (could not resolve cleanly):", skipped_noresolve)


if __name__ == "__main__":
    main()
