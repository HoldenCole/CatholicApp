#!/usr/bin/env python3
"""
Missal content repairs from the DO-verified QA:

- Trinity Sunday (pent01-0) carried the OLD Dominica-I introit ("Domine,
  in tua misericordia"); the 1962 introit is "Benedicta sit sancta
  Trinitas" (the entry's own -r variant has it).
- The composite Christmas entry (12-25) lacked the gradual (Viderunt
  omnes) that its own m3 source carries.
- The Jan 2-5 ferias' Mass redirect now points at Sancti/01-01 (DO's own
  "vide" rule: their Mass is Puer natus), so fixing Holy Name cannot make
  the date-hop serve the Holy Name Mass on them.
- Holy Name data under the floating key "01-00": Mass copied from the
  complete 01-03n formulary; OFFICE imported from DO horas Sancti/01-00
  (it was absent from sanctoral_propers entirely).
- Secreta/postcommunio that DO sources as @Commune/C2a were expanded from
  the WRONG commune file (C2a-1's "Accepta sit ... pro cujus
  sollemnitate"); re-resolved from Commune/C2a.
- Missing sequences imported: Victimae paschali (Easter + octave), Stabat
  Mater (Seven Sorrows + Passion Friday), Dies irae (the All Souls
  Masses).
- Literal DO macros expanded: $Per Dominum-family conclusions (175
  fields, mostly English), &Gloria in introits, stray "v. " markers; the
  spurious leading "Alleluja, alleluja." on the Easter gradual removed.

Requires the DO checkout (default: session scratchpad; /tmp/do_repo
symlink also works). Idempotent; writes both platforms' assets.
"""

import copy
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import import_do  # noqa: E402  (parse/resolve machinery + macro tables)

DO_ROOT = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(
    "/tmp/claude-0/-home-user-CatholicApp/71906fbb-67e9-553f-b996-d8565178e126/scratchpad/do_repo"
)
REPO = Path(__file__).resolve().parent.parent
RESOURCES = REPO / "Introibo" / "Resources"
ANDROID = REPO / "android" / "app" / "src" / "main" / "assets"

MISSA_LAT = DO_ROOT / "web/www/missa/Latin"
MISSA_ENG = DO_ROOT / "web/www/missa/English"
COMMUNE_LAT = DO_ROOT / "obsolete/missa/Latin/Commune"
COMMUNE_ENG = DO_ROOT / "obsolete/missa/English/Commune"


def parse(path: Path) -> dict:
    return import_do.parse_do_file(path) if path.exists() else {}


def section_text(path: Path, lang_root: Path, section: str) -> str | None:
    sections = parse(path)
    if section not in sections:
        return None
    text = import_do.resolve_section_content(
        sections[section], path, lang_root, sections,
        current_section_name=section)
    return (text or "").strip() or None


def write_both(name: str, data) -> None:
    text = json.dumps(data, ensure_ascii=False, indent=2) + "\n"
    for root in (RESOURCES, ANDROID):
        (root / name).write_text(text, encoding="utf-8")


# ── individual fixes ──────────────────────────────────────────────────────────

def fix_trinity_and_christmas(mt: dict, ms: dict) -> None:
    mt["pent01-0"]["introitus"] = copy.deepcopy(mt["pent01-0r"]["introitus"])
    ms["12-25"]["graduale"] = copy.deepcopy(ms["12-25m3"]["graduale"])
    print("  Trinity introit + Christmas gradual fixed")


def fix_january_redirects(mt: dict) -> None:
    for key in ("nat08", "nat09", "nat10", "nat11"):
        entry = mt.setdefault(key, {})
        rule = entry.get("rule") or {}
        rule["commune"] = "Sancti/01-01"
        entry["rule"] = rule
    print("  Jan 2-5 ferias redirect -> Sancti/01-01 (Puer natus)")


def add_holy_name(ms: dict, sp: dict) -> None:
    # Mass: the complete Holy Name formulary already in the corpus.
    ms["01-00"] = copy.deepcopy(ms["01-03n"])
    # Office: targeted import. DO's Sancti/01-00.txt is a whole-file
    # redirect ("@Tempora/Nat2-0"); the Holy Name office content lives in
    # the Tempora file.
    lat_path = DO_ROOT / "web/www/horas/Latin/Tempora/Nat2-0.txt"
    eng_path = DO_ROOT / "web/www/horas/English/Tempora/Nat2-0.txt"
    lat_sections = import_do.parse_do_file(lat_path)
    eng_sections = import_do.parse_do_file(eng_path) if eng_path.exists() else {}
    entry = {}
    skip = {"Officium", "Rank", "Rule", "Name"}
    for sec in lat_sections:
        if sec in skip:
            continue
        lat_text = import_do.process_section_text(
            lat_sections[sec], lat_path, import_do.DO_HORAS_LATIN, lat_sections,
            english=False, section_name=sec)
        eng_text = ""
        if sec in eng_sections:
            eng_text = import_do.process_section_text(
                eng_sections[sec], eng_path, import_do.DO_HORAS_ENGLISH, eng_sections,
                english=True, section_name=sec)
        if not lat_text:
            continue
        field_key = sec.lower().replace(" ", "_")
        entry[field_key] = {
            "type": import_do._infer_part_type(field_key),
            "variationKey": field_key,
            "lat": lat_text,
            "eng": eng_text or "",
        }
    assert "oratio" in entry, "Holy Name office import failed"
    sp["01-00"] = entry
    print(f"  Holy Name (01-00): Mass copied from 01-03n; office imported "
          f"({len(entry)} parts)")


C2A_SUSPECTS = [
    ("tempora", "quadp1-0", "Tempora/Quadp1-0"),
    ("sanctoral", "01-01", "Sancti/01-01"),
    ("sanctoral", "01-19o", "Sancti/01-19o"),
    ("sanctoral", "04-13", "Sancti/04-13"),
    ("sanctoral", "04-24", "Sancti/04-24"),
    ("sanctoral", "04-28n", "Sancti/04-28n"),
    ("sanctoral", "04-28o", "Sancti/04-28o"),
    ("sanctoral", "05-14", "Sancti/05-14"),
    ("sanctoral", "05-16n", "Sancti/05-16n"),
    ("sanctoral", "07-25cc", "Sancti/07-25cc"),
    ("sanctoral", "07-27", "Sancti/07-27"),
    ("sanctoral", "09-08cc", "Sancti/09-08cc"),
    ("sanctoral", "09-28", "Sancti/09-28"),
    ("sanctoral", "11-11cc", "Sancti/11-11cc"),
]


def fix_c2a(mt: dict, ms: dict) -> None:
    fixed = 0
    for section_name, field in (("Secreta", "secreta"), ("Postcommunio", "postcommunio")):
        c2a_lat = section_text(COMMUNE_LAT / "C2a.txt", COMMUNE_LAT.parent, section_name)
        c2a_eng = section_text(COMMUNE_ENG / "C2a.txt", COMMUNE_ENG.parent, section_name)
        if not c2a_lat:
            print(f"  WARNING: could not resolve Commune/C2a [{section_name}]")
            continue
        for corpus_name, key, do_rel in C2A_SUSPECTS:
            corpus = mt if corpus_name == "tempora" else ms
            entry = corpus.get(key)
            if not entry or field not in entry:
                continue
            do_file = MISSA_LAT / f"{do_rel}.txt"
            sections = parse(do_file)
            body = [l.strip() for l in sections.get(section_name, []) if l.strip()]
            # Only rewrite when DO's own source is exactly the C2a reference.
            if body == ["@Commune/C2a"] or body == [f"@Commune/C2a:{section_name}"]:
                if entry[field].get("lat") != c2a_lat:
                    entry[field]["lat"] = c2a_lat
                    if c2a_eng:
                        entry[field]["eng"] = c2a_eng
                    fixed += 1
    print(f"  C2a orations re-resolved: {fixed} field(s)")


def add_sequences(mt: dict, ms: dict) -> None:
    def seq(rel: str):
        lat = section_text(MISSA_LAT / f"{rel}.txt", MISSA_LAT, "Sequentia")
        eng = section_text(MISSA_ENG / f"{rel}.txt", MISSA_ENG, "Sequentia")
        return {"lat": lat, "eng": eng or ""} if lat else None

    added = 0
    victimae = seq("Tempora/Pasc0-0")
    if victimae:
        for day in range(0, 7):
            key = f"pasc0-{day}"
            if key in mt and "sequentia" not in mt[key]:
                mt[key]["sequentia"] = dict(victimae)
                added += 1
    stabat = seq("Sancti/09-15")
    if stabat:
        for corpus, key in ((ms, "09-15"), (mt, "quad5-5")):
            if key in corpus and "sequentia" not in corpus[key]:
                corpus[key]["sequentia"] = dict(stabat)
                added += 1
    # Dies irae: DO injects it into the Requiem Masses from the C9 commune.
    dies = None
    for candidate in (COMMUNE_LAT / "C9.txt", MISSA_LAT / "Sancti/11-02m1.txt"):
        lat = section_text(candidate, candidate.parent.parent, "Sequentia")
        if lat:
            eng_candidate = Path(str(candidate).replace("/Latin/", "/English/"))
            eng = section_text(eng_candidate, eng_candidate.parent.parent, "Sequentia")
            dies = {"lat": lat, "eng": eng or ""}
            break
    if dies:
        for key in ("11-02m1", "11-02m2", "11-02m3"):
            if key in ms and "sequentia" not in ms[key]:
                ms[key]["sequentia"] = dict(dies)
                added += 1
    else:
        print("  WARNING: Dies irae source not found")
    print(f"  sequences added: {added} entries")


GLORIA_LAT = ("Glória Patri, et Fílio, et Spirítui Sancto. Sicut erat in "
              "princípio, et nunc, et semper, et in sǽcula sæculórum. Amen.")
GLORIA_ENG = ("Glory be to the Father, and to the Son, and to the Holy Ghost. "
              "As it was in the beginning, is now, and ever shall be, world "
              "without end. Amen.")


def expand_macros(data: dict) -> int:
    lat_macros = dict(import_do.MACROS)
    eng_macros = dict(import_do.MACROS_ENG)
    lat_macros["$Per eumdem"] = lat_macros["$Per eundem"]
    eng_macros["$Per eumdem"] = eng_macros["$Per eundem"]
    lat_macros["$per Dominum"] = lat_macros["$Per Dominum"]
    eng_macros["$per Dominum"] = eng_macros.get("$Per Dominum", "")

    fixed = 0
    for entry in data.values():
        if not isinstance(entry, dict):
            continue
        for field in entry.values():
            if not isinstance(field, dict):
                continue
            for lang, macros, gloria in (("lat", lat_macros, GLORIA_LAT),
                                         ("eng", eng_macros, GLORIA_ENG)):
                text = field.get(lang)
                if not isinstance(text, str) or not text:
                    continue
                new = text
                for macro, expansion in sorted(macros.items(), key=lambda kv: -len(kv[0])):
                    if macro in new and expansion:
                        new = new.replace(macro, expansion)
                new = re.sub(r"&Gloria\b|&Gl\b", gloria, new)
                if lang == "eng":
                    new = re.sub(r"(^|\n)v\.\s+", r"\1V. ", new)
                if new != text:
                    field[lang] = new
                    fixed += 1
    return fixed


def fix_easter_gradual(mt: dict) -> None:
    g = mt["pasc0-0"].get("graduale")
    if g:
        for lang, spur in (("lat", "Allelúja, allelúja."), ("eng", "Alleluia, alleluia.")):
            t = g.get(lang)
            if isinstance(t, str) and t.startswith(spur):
                g[lang] = t[len(spur):].lstrip("\n ")
    print("  Easter gradual leading alleluia trimmed")


def main():
    mt = json.loads((RESOURCES / "missal_tempora.json").read_text())
    ms = json.loads((RESOURCES / "missal_sanctoral.json").read_text())
    sp = json.loads((RESOURCES / "sanctoral_propers.json").read_text())

    fix_trinity_and_christmas(mt, ms)
    fix_january_redirects(mt)
    add_holy_name(ms, sp)
    fix_c2a(mt, ms)
    add_sequences(mt, ms)
    fix_easter_gradual(mt)
    n = expand_macros(mt) + expand_macros(ms)
    print(f"  macros expanded in {n} field(s)")

    write_both("missal_tempora.json", mt)
    write_both("missal_sanctoral.json", ms)
    write_both("sanctoral_propers.json", sp)

    # QA
    mt2 = json.loads((RESOURCES / "missal_tempora.json").read_text())
    ms2 = json.loads((RESOURCES / "missal_sanctoral.json").read_text())
    assert mt2["pent01-0"]["introitus"]["lat"].startswith("Benedícta sit")
    assert "graduale" in ms2["12-25"]
    assert "01-00" in ms2 and ms2["01-00"]["officium"].startswith("Sanctissimi")
    assert "sequentia" in mt2["pasc0-0"] and "sequentia" in ms2["11-02m1"]
    blob = json.dumps(mt2) + json.dumps(ms2)
    assert "$Per Dominum" not in blob and "$Per eundem" not in blob \
        and "$Per eumdem" not in blob and "&Gloria" not in blob
    print("QA: missal content assertions passed.")


if __name__ == "__main__":
    main()
