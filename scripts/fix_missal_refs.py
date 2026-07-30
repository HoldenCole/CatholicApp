#!/usr/bin/env python3
"""
Resolve residual import gaps in the MISSAL propers:

1. Unresolved DO cross-references left verbatim in field text — the
   Commemoration of St. Paul (06-30) ends its collect and postcommunion with
   "@Sancti/02-22:Oratio Petri" / ":Postcommunio Petri" (the second oration
   of St. Peter that this Mass always adds). Resolve them from the DO missa
   files, in both languages.
2. Fields whose Latin is populated but whose English is empty (35 fields,
   all in missal_sanctoral.json) — pull the English from the corresponding
   DO missa English section, following one level of @-references (with
   sed-style substitutions) into the Commune where needed.

Usage: python3 scripts/fix_missal_refs.py [path-to-do-checkout]
Idempotent; writes byte-identically to both platforms' assets.
"""

import json
import re
import sys
from pathlib import Path

DO_ROOT = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(
    "/tmp/claude-0/-home-user-CatholicApp/71906fbb-67e9-553f-b996-d8565178e126/scratchpad/do_repo"
)
REPO = Path(__file__).resolve().parent.parent
RESOURCES = REPO / "Introibo" / "Resources"
ANDROID = REPO / "android" / "app" / "src" / "main" / "assets"

FIELD_TO_SECTION = {
    "introitus": "Introitus", "oratio": "Oratio", "lectio": "Lectio",
    "graduale": "Graduale", "evangelium": "Evangelium",
    "offertorium": "Offertorium", "secreta": "Secreta",
    "communio": "Communio", "postcommunio": "Postcommunio",
    "tractus": "Tractus", "sequentia": "Sequentia",
}


def missa_root(lang: str) -> Path:
    return DO_ROOT / "web/www/missa" / lang


def parse_sections(path: Path) -> dict:
    sections = {}
    current = None
    if not path.exists():
        return sections
    for raw in path.read_text(encoding="utf-8").splitlines():
        m = re.match(r"^\[([^\]]+)\]\s*(\(.*\))?\s*$", raw)
        if m:
            current = None if m.group(2) else m.group(1)
            if current is not None:
                sections[current] = []
            continue
        if current is not None:
            sections[current].append(raw)
    for k in sections:
        while sections[k] and not sections[k][-1].strip():
            sections[k].pop()
    return sections


def apply_subs(text: str, subs: str) -> str:
    """Apply DO's sed-style payload: one or more s/pat/repl/[g][i]."""
    for m in re.finditer(r"s/((?:[^/\\]|\\.)*)/((?:[^/\\]|\\.)*)/([gi]*)", subs):
        pat, repl, flags = m.group(1), m.group(2), m.group(3)
        count = 0 if "g" in flags else 1
        re_flags = re.IGNORECASE if "i" in flags else 0
        try:
            text = re.sub(pat, repl.replace("$1", r"\1"), text, count=count, flags=re_flags)
        except re.error:
            pass
    return text


def resolve_section(lang: str, file_rel: str, section: str, depth: int = 0) -> str | None:
    """Text of [section] in missa/<lang>/<file_rel>.txt, following @-refs."""
    if depth > 3:
        return None
    sections = parse_sections(missa_root(lang) / f"{file_rel}.txt")
    if section not in sections:
        return None
    out_lines = []
    for line in sections[section]:
        s = line.strip()
        m = re.match(r"^@([A-Za-z0-9/-]*):([^:]+?)(:(.*))?$", s)
        if m:
            target = m.group(1) or file_rel
            resolved = resolve_section(lang, target, m.group(2).strip(), depth + 1)
            if resolved is None:
                return None
            if m.group(4):
                resolved = apply_subs(resolved, m.group(4))
            out_lines.append(resolved)
        elif s.startswith("!") or s.startswith("#"):
            continue  # rubric / comment lines
        else:
            out_lines.append(line)
    text = "\n".join(out_lines).strip()
    text = re.sub(r"\{:[^}]*:\}", "", text)
    text = text.replace("v. ", "").replace("V. ", "V. ")
    return text or None


def key_to_do_file(key: str) -> str:
    """Our sanctoral keys map to DO missa files: '05-22n' -> 'Sancti/05-22n',
    '06-30octt' -> no direct file (skip via existence check)."""
    return f"Sancti/{key}"


def main():
    fname = "missal_sanctoral.json"
    data = json.loads((RESOURCES / fname).read_text())

    # 1. The 06-30 second orations of St. Peter.
    fixed_refs = 0
    for field, section in (("oratio", "Oratio Petri"), ("postcommunio", "Postcommunio Petri")):
        entry = data["06-30"][field]
        lat = entry.get("lat") or ""
        m = re.search(r"@Sancti/02-22:([A-Za-z ]+)", lat)
        if m:
            res_lat = resolve_section("Latin", "Sancti/02-22", m.group(1).strip())
            res_eng = resolve_section("English", "Sancti/02-22", m.group(1).strip())
            if res_lat:
                entry["lat"] = lat.replace(m.group(0), res_lat)
                eng = entry.get("eng") or ""
                if res_eng and res_eng not in eng:
                    entry["eng"] = (eng.rstrip() + "\n\nLet us pray.\n" + res_eng).strip()
                fixed_refs += 1
    print(f"  resolved {fixed_refs} @-reference(s) in 06-30")

    # 2. Latin-without-English fields. DO's own English files lack these
    # sections, but the texts are mostly commune pieces (Os justi, Dilexisti,
    # ...) whose translations already exist elsewhere in our corpus — build a
    # Latin→English lookup across BOTH missal files and match on the
    # normalized head of the Latin text.
    tempora = json.loads((RESOURCES / "missal_tempora.json").read_text())

    def norm(s: str) -> str:
        s = re.sub(r"\s+", " ", s).strip().lower()
        s = re.sub(r"[.,;:!*]", "", s)
        return s[:80]

    lookup: dict[str, str] = {}
    for corpus in (data, tempora):
        for entry in corpus.values():
            if not isinstance(entry, dict):
                continue
            for fv in entry.values():
                if not isinstance(fv, dict):
                    continue
                lat, eng = fv.get("lat") or "", fv.get("eng") or ""
                if isinstance(lat, str) and isinstance(eng, str) and len(lat) > 40 and len(eng) > 20:
                    lookup.setdefault(norm(lat), eng)

    # Two collects are unique to their feasts and untranslated in DO's
    # English tree; standard hand-missal translations supplied here.
    HAND_TRANSLATIONS = {
        ("11-29", "oratio"):
            "We beseech Thee, almighty God, that the blessed Apostle Andrew, "
            "whose feast we anticipate, may implore Thy help for us: that, "
            "absolved from our sins, we may also be delivered from all "
            "dangers.\nThrough our Lord Jesus Christ, Thy Son, Who liveth and "
            "reigneth with Thee in the unity of the Holy Ghost, God, world "
            "without end. Amen.",
        ("05-16n", "oratio"):
            "O God, Who didst adorn Thy Church with a new crown of martyrdom "
            "for the unconquered sacramental silence of blessed John: grant "
            "us, by his intercession and example, to keep careful guard over "
            "our tongue, and to endure every evil in this world rather than "
            "harm to the soul.\nThrough our Lord Jesus Christ, Thy Son, Who "
            "liveth and reigneth with Thee in the unity of the Holy Ghost, "
            "God, world without end. Amen.",
    }

    filled = 0
    missing = []
    for key, entry in data.items():
        if not isinstance(entry, dict):
            continue
        for fk, fv in entry.items():
            if not isinstance(fv, dict):
                continue
            lat, eng = fv.get("lat") or "", fv.get("eng") or ""
            if not (isinstance(lat, str) and isinstance(eng, str)):
                continue
            if len(lat) > 40 and len(eng) == 0:
                section = FIELD_TO_SECTION.get(fk.split("_")[0])
                res = (section and resolve_section("English", key_to_do_file(key), section)) \
                    or lookup.get(norm(lat)) \
                    or HAND_TRANSLATIONS.get((key, fk))
                if res:
                    fv["eng"] = res
                    filled += 1
                else:
                    missing.append((key, fk))
    print(f"  filled {filled} empty English field(s); unresolved: {missing}")

    text = json.dumps(data, ensure_ascii=False, indent=2) + "\n"
    for root in (RESOURCES, ANDROID):
        (root / fname).write_text(text, encoding="utf-8")

    # QA
    check = json.loads((RESOURCES / fname).read_text())
    assert "@Sancti" not in json.dumps(check["06-30"])
    print("QA: 06-30 references resolved.")


if __name__ == "__main__":
    main()
