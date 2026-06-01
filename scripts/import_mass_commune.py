#!/usr/bin/env python3
"""Fill in the Mass propers for sanctoral feasts whose formulary is taken
wholesale from a Common (DO missa `[Rule]: vide CXX`).

About a third of the sanctoral cycle (Common of a Martyr-Bishop, of an Abbot,
of a Doctor, …) ships in DivinumOfficium as a tiny Sancti/MM-DD missa file
holding only a proper [Oratio] (or just a [Name]) plus `vide CXX`; the
Introit, Epistle, Gradual, Gospel, Offertory, Secret, Communion and
Postcommunion all live in the common Mass CXX. The original import only kept
what the file literally contained, so those days displayed a collect and
nothing else.

This reads the full common Mass from DO's obsolete missa commons (Latin +
English), substitutes the feast's [Name] for the "N." placeholder (honouring
per-section case overrides like `Postcommunio=Pio`), and writes the resolved
parts into any Mass slot the feast doesn't already define — never overwriting
a proper the feast carries itself. iOS Resources + Android assets stay in sync.
"""
import sys, re, json
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import import_do as IDO
from import_do import process_mass_file, parse_do_file

MISSA_LAT_SANCTI = IDO.DO_MISSA_LATIN / "Sancti"
COMMUNE_LAT = IDO.DO_MISSA_COMMUNE_LATIN
COMMUNE_ENG = IDO.DO_MISSA_COMMUNE_ENGLISH

ROOT = Path(__file__).resolve().parent.parent
DIRS = [ROOT / "Introibo" / "Resources", ROOT / "android" / "app" / "src" / "main" / "assets"]

# Mass slots we fill from the common (everything except the proper collect,
# which the feast supplies). Order mirrors MASS_SECTION_MAP.
FILL_FIELDS = ["introitus", "lectio", "graduale", "evangelium",
               "offertorium", "secreta", "communio", "postcommunio"]
# json field -> DO section name (for matching per-section [Name] overrides)
FIELD_TO_SECTION = {v: k for k, v in IDO.MASS_SECTION_MAP.items()}

_commune_cache = {}


def commune_mass(code):
    if code in _commune_cache:
        return _commune_cache[code]
    # A trailing `-N` (e.g. C2b-1) only selects which collect formulary within
    # the common to use; the Mass body lives in the base file (C2b.txt) and the
    # feast keeps its own proper collect regardless, so fall back to the base.
    lat = COMMUNE_LAT / f"{code}.txt"
    if not lat.exists():
        base = re.sub(r"-\d+$", "", code)
        lat = COMMUNE_LAT / f"{base}.txt"
        code = base
    eng = COMMUNE_ENG / f"{code}.txt"
    res = process_mass_file(lat, eng) if lat.exists() else None
    _commune_cache[code] = res
    return res


def rule_commune_code(secs):
    """The Mass common code from a missa [Rule]'s leading `vide/ex CXX`."""
    rule = "\n".join(secs.get("Rule", []))
    m = re.search(r"\b(?:vide|ex)\s+(C\d+[a-z]*(?:-\d+)?)\b", rule)
    if m:
        return m.group(1)
    rank = "\n".join(secs.get("Rank", []))
    m = re.search(r"vide\s+(C\d+[a-z]*(?:-\d+)?)", rank)
    return m.group(1) if m else None


def rule_sancti_redirect(secs):
    """A `vide Sancti/MM-DD` whole-Mass borrow (octave days, BVM Saturdays …)."""
    blob = "\n".join(secs.get("Rule", []) + secs.get("Rank", []))
    m = re.search(r"\bvide\s+Sancti/(\d{2}-\d{2}[a-z0-9]*)", blob)
    return m.group(1) if m else None


def parse_names(secs):
    """Return (default_name, {DO_section: name}) from a missa [Name] section.
    Lines look like:
        Ægídii                 <- default substitution
        (sed communi …)        <- annotation, ignored
        Secreta=Ægídius        <- per-section override
    """
    default, overrides = None, {}
    for line in secs.get("Name", []):
        line = line.strip()
        if not line or line.startswith("("):
            continue
        m = re.match(r"([A-Za-z]+)\s*=\s*(.+)$", line)
        if m:
            overrides[m.group(1)] = m.group(2).strip()
        elif default is None:
            default = line
    return default, overrides


def subst(text, name):
    if not name or not text:
        return text
    text = re.sub(r"\bN\. et N\.\b", name, text)
    text = re.sub(r"\bN\.", name, text)
    return text


def main():
    sanctoral_path = DIRS[0] / "missal_sanctoral.json"
    ms = json.loads(sanctoral_path.read_text())

    filled, no_common, sancti_redirects = [], [], []
    for key in sorted(ms):
        if not re.match(r"^\d{2}-\d{2}[a-z0-9]*$", key):
            continue
        entry = ms[key]
        missing = [f for f in ("introitus", "lectio", "evangelium") if f not in entry]
        if not missing or entry.get("rule", {}).get("commune"):
            continue  # already complete, or resolves via an existing redirect

        missa_file = MISSA_LAT_SANCTI / f"{key}.txt"
        if not missa_file.exists():
            continue
        secs = parse_do_file(missa_file)

        # Whole-Mass borrow from another feast (`vide Sancti/MM-DD`): leave the
        # resolution to the app's rule.commune redirect so the target's own
        # propers (and any future edits to them) flow through.
        redir = rule_sancti_redirect(secs)
        if redir and redir in ms and all(c in ms[redir] for c in ("introitus", "lectio", "evangelium")):
            entry.setdefault("rule", {})["commune"] = f"Sancti/{redir}"
            sancti_redirects.append((key, redir))
            continue

        code = rule_commune_code(secs)
        if not code:
            continue
        common = commune_mass(code)
        if not common:
            no_common.append((key, code))
            continue

        default_name, overrides = parse_names(secs)
        added = []
        for field in FILL_FIELDS:
            if field in entry or field not in common:
                continue
            part = dict(common[field])
            do_sec = FIELD_TO_SECTION.get(field, "")
            name = overrides.get(do_sec, default_name)
            if "lat" in part:
                part["lat"] = subst(part["lat"], name)
            if "eng" in part:
                part["eng"] = subst(part["eng"], name)
            entry[field] = part
            added.append(field)
        if added:
            filled.append((key, code, len(added)))

    blob = json.dumps(ms, ensure_ascii=False, indent=1)
    if "--dry-run" not in sys.argv:
        for d in DIRS:
            (d / "missal_sanctoral.json").write_text(blob)

    print(f"feasts filled from common Mass: {len(filled)}")
    for k, c, n in filled:
        print(f"  {k}  <- {c}  (+{n} parts)")
    print(f"feasts given a Sancti/ redirect: {len(sancti_redirects)}")
    for k, t in sancti_redirects:
        print(f"  {k}  -> Sancti/{t}")
    if no_common:
        print("NO COMMON FILE for:", no_common)


if __name__ == "__main__":
    main()
