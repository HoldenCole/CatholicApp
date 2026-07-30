#!/usr/bin/env python3
"""
Fix the structural defects in the Office data (v1.2.4 Office repair).

What this does (shared JSON, written byte-identically to iOS + Android):

1. hours.json
   - Remove the "responsorium breve" slot from Vespers: the Roman secular
     office has NO short responsory at Vespers (or Lauds) in any of the
     three supported rites — it is a monastic-office feature that was
     imported by mistake.
   - Give Prime's and Compline's collects their own variationKeys
     (oratio_prima / oratio_completorium): those collects are INVARIABLE
     (Domine Deus omnipotens / Visita quaesumus) and must never be
     replaced by the collect of the day, which the shared "oratio" key
     allowed on any day that supplies one.
   - Compline order: the hymn (Te lucis) belongs AFTER the psalms and
     before the capitulum in the Roman office (the template had the
     Liturgia-Horarum order), and the versicle "Custodi nos, Domine, ut
     pupillam oculi" precedes the Nunc dimittis.

2. psalter_weekly.json  (monday..saturday; sunday is baked into hours.json)
   - Drop the monastic Vespers short responsory entries.
   - Normalize every part's embedded variationKey to equal its dict key.
     Six part families carried a DIFFERENT embedded key (e.g. dict key
     "capitulum_laudes" but variationKey "laudes.capitulum"): after the
     assembler substituted them, later feast/commune overrides could no
     longer address the slot, which is one reason feast propers never
     rendered.
   - Import the missing ferial material from DivinumOfficium
     (web/www/horas/{Latin,English}/Psalterium/Special/Major Special.txt):
       hymnus_laudes    Mon Splendor paternae gloriae … Sat Aurora jam spargit
       hymnus_vespera   Mon Immense caeli Conditor  … Sat Jam sol recedit
       ant_laudes       ferial Benedictus antiphons (Feria2..Feria7 Ant 2)
       ant_vespera      ferial Magnificat antiphons (Feria2..Feria7 Ant 3)
       versum_1         ferial Lauds versicle (Repleti sumus mane)
       versum_2         Saturday-only Vespers versicle (Vespertina oratio);
                        Mon-Fri use the template's Dirigatur, as on Sunday.

3. hymns_seasonal.json
   - Normalize embedded variationKeys to dict keys (same rewrite bug).

Requires a DivinumOfficium checkout; pass its path or default below.
Idempotent: running twice yields the same output.
"""

import copy
import hashlib
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

MAJOR_LAT = DO_ROOT / "web/www/horas/Latin/Psalterium/Special/Major Special.txt"
MAJOR_ENG = DO_ROOT / "web/www/horas/English/Psalterium/Special/Major Special.txt"

# DayN (DO hymn sections) / FeriaN (DO antiphon sections) -> weekday name
WEEKDAYS = {
    1: "monday", 2: "tuesday", 3: "wednesday",
    4: "thursday", 5: "friday", 6: "saturday",
}


# ── DO section parsing ────────────────────────────────────────────────────────

def parse_sections(path: Path) -> dict:
    """[Name] -> list of body lines. Headers with a (condition) are skipped
    (we want the base 1962/Urban-VIII text, not monastic/OP/tridentine
    variants). Inside a body, an inline '(sed rubrica …)' line starts an
    alternative reading — the base text is everything before it."""
    sections = {}
    current = None
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


def base_text_lines(lines: list) -> list:
    """Body lines up to the first inline rubric conditional."""
    out = []
    for line in lines:
        if line.strip().startswith("("):
            break
        out.append(line)
    while out and not out[-1].strip():
        out.pop()
    return out


def clean_line(line: str) -> str:
    line = re.sub(r"\{:[^}]*:\}", "", line)      # chant tags {:H-VespFeria:}
    line = re.sub(r"^v\.\s+", "", line)           # hymn first-line marker
    return line.rstrip()


def hymn_text(lines: list) -> str:
    """Join hymn lines; '_' separates stanzas -> blank line."""
    out = []
    for line in base_text_lines(lines):
        line = clean_line(line)
        if line.strip() == "_":
            out.append("")
        else:
            out.append(line)
    return "\n".join(out).strip()


def single_text(lines: list) -> str:
    return " ".join(clean_line(l) for l in base_text_lines(lines) if l.strip()).strip()


def versicle(lines: list):
    """('V. …', 'R. …') -> (lat, latR) without the V./R. prefixes."""
    v = r = None
    for line in base_text_lines(lines):
        line = clean_line(line).strip()
        if line.startswith("V. "):
            v = line[3:]
        elif line.startswith("R. "):
            r = line[3:]
    return v, r


# ── Build the new ferial parts ────────────────────────────────────────────────

def resolve_ref(lang_root: Path, lines: list, depth: int = 0):
    """DO cross-references: a section body of '@File:Section' (optionally with
    trailing sed-style substitutions we ignore) pulls the target section from
    another file in the same language tree. '@:Section' is same-file (the
    caller handles that case before calling us)."""
    body = base_text_lines(lines)
    first = next((l.strip() for l in body if l.strip()), "")
    if not first.startswith("@") or depth > 3:
        return lines
    m = re.match(r"^@([^:]+):([^:]+?)(?::s/.*)?$", first)
    if not m:
        return lines
    target = lang_root / (m.group(1) + ".txt")
    name = m.group(2).strip()
    table = parse_sections(target)
    if name not in table:
        raise SystemExit(f"ref target missing: {first} in {target}")
    return resolve_ref(lang_root, table[name], depth + 1)


def build_ferial_parts():
    lat_root = DO_ROOT / "web/www/horas/Latin"
    eng_root = DO_ROOT / "web/www/horas/English"
    lat = parse_sections(MAJOR_LAT)
    eng = parse_sections(MAJOR_ENG)

    def sect(lang: str, name: str):
        table, root = (lat, lat_root) if lang == "lat" else (eng, eng_root)
        if name in table:
            return resolve_ref(root, table[name])
        # English Major Special omits some sections that are pure references
        # in Latin (e.g. Hymnus Day6 Vespera -> Tempora/Pent01-0): resolve
        # the Latin reference against the English tree.
        if lang == "eng" and name in lat:
            body = base_text_lines(lat[name])
            first = next((l.strip() for l in body if l.strip()), "")
            if first.startswith("@"):
                return resolve_ref(eng_root, lat[name])
        raise SystemExit(f"DO section missing: [{name}]")

    parts = {day: {} for day in WEEKDAYS.values()}

    for n, day in WEEKDAYS.items():
        feria = n + 1  # liturgical numbering: Monday = feria 2
        for hour, do_hour, vk in (("laudes", "Laudes", "hymnus_laudes"),
                                  ("vesperae", "Vespera", "hymnus_vespera")):
            l = hymn_text(sect("lat", f"Hymnus Day{n} {do_hour}"))
            e = hymn_text(sect("eng", f"Hymnus Day{n} {do_hour}"))
            title = l.splitlines()[0].rstrip(",;.:")
            parts[day][vk] = {
                "type": "hymn", "label": "Hymn", "title": title,
                "lat": l, "eng": e, "variationKey": vk,
            }
        for ant_n, vk, label in ((2, "ant_laudes", "Antiphon ad Benedictus"),
                                 (3, "ant_vespera", "Antiphon ad Magnificat")):
            l = single_text(sect("lat", f"Feria{feria} Ant {ant_n}"))
            e = single_text(sect("eng", f"Feria{feria} Ant {ant_n}"))
            parts[day][vk] = {
                "type": "antiphon", "label": label,
                "lat": l, "eng": e, "variationKey": vk,
            }
        # Ferial Lauds versicle (Repleti sumus mane) — differs from the
        # template's Sunday versicle (Dominus regnavit).
        v_lat, r_lat = versicle(sect("lat", "Feria Versum 2_"))
        v_eng, r_eng = versicle(sect("eng", "Feria Versum 2_"))
        parts[day]["versum_1"] = {
            "type": "vr", "label": "Versicle",
            "lat": v_lat, "eng": v_eng, "latR": r_lat, "engR": r_eng,
            "variationKey": "versum_1",
        }

    # Saturday Vespers versicle: Vespertina oratio ascendat (feria 7 variant).
    def feria7_versum3(table):
        for raw_name in table:
            pass
        return None
    # The variant lives under a conditioned header "[Feria Versum 3] (feria 7)"
    # which parse_sections skips — read it directly.
    def read_conditioned(path, header):
        lines = path.read_text(encoding="utf-8").splitlines()
        out, taking = [], False
        for line in lines:
            if line.strip() == header:
                taking = True
                continue
            if taking and line.startswith("["):
                break
            if taking:
                out.append(line)
        while out and not out[-1].strip():
            out.pop()
        return out

    sat_lat = versicle(read_conditioned(MAJOR_LAT, "[Feria Versum 3] (feria 7)"))
    sat_eng = versicle(read_conditioned(MAJOR_ENG, "[Feria Versum 3] (feria 7)"))
    if sat_lat[0]:
        parts["saturday"]["versum_2"] = {
            "type": "vr", "label": "Versicle",
            "lat": sat_lat[0], "eng": sat_eng[0] or "",
            "latR": sat_lat[1] or "", "engR": sat_eng[1] or "",
            "variationKey": "versum_2",
        }
    return parts


# ── File edits ────────────────────────────────────────────────────────────────

CUSTODI_NOS = {
    "type": "vr", "label": "Versicle",
    "lat": "Custódi nos, Dómine, ut pupíllam óculi.",
    "eng": "Keep us, O Lord, as the apple of Thine eye.",
    "latR": "Sub umbra alárum tuárum prótege nos.",
    "engR": "Protect us under the shadow of Thy wings.",
}


def fix_hours(hours: list) -> list:
    hours = copy.deepcopy(hours)
    for h in hours:
        if h["slug"] == "vesperae":
            h["parts"] = [p for p in h["parts"]
                          if p.get("variationKey") != "responsory_vespera_1"]
        if h["slug"] == "prima":
            for p in h["parts"]:
                if p.get("type") == "collect" and p.get("variationKey") == "oratio":
                    p["variationKey"] = "oratio_prima"
        if h["slug"] == "completorium":
            for p in h["parts"]:
                if p.get("type") == "collect" and p.get("variationKey") == "oratio":
                    p["variationKey"] = "oratio_completorium"
            parts = h["parts"]
            # Roman order: psalms -> hymn -> capitulum. The template had the
            # hymn before the antiphon+psalms.
            hymn_i = next((i for i, p in enumerate(parts)
                           if p.get("variationKey") == "completorium.hymn"), None)
            psalm3_i = next((i for i, p in enumerate(parts)
                             if p.get("variationKey") == "completorium.psalm3"), None)
            if hymn_i is not None and psalm3_i is not None and hymn_i < psalm3_i:
                hymn = parts.pop(hymn_i)
                psalm3_i = next(i for i, p in enumerate(parts)
                                if p.get("variationKey") == "completorium.psalm3")
                parts.insert(psalm3_i + 1, hymn)
            # V. Custodi nos before the Nunc dimittis (after the responsory).
            resp_i = next((i for i, p in enumerate(parts)
                           if p.get("variationKey") == "completorium.responsory"), None)
            has_custodi = any("Custódi nos" in (p.get("lat") or "") for p in parts)
            if resp_i is not None and not has_custodi:
                parts.insert(resp_i + 1, dict(CUSTODI_NOS))
    return hours


def fix_psalter_weekly(pw: dict, ferial: dict) -> dict:
    pw = copy.deepcopy(pw)
    for day, entries in pw.items():
        entries.pop("responsory_vespera_1", None)
        for key, part in entries.items():
            part["variationKey"] = key
        if day in ferial:
            for key, part in ferial[day].items():
                entries[key] = part
    return pw


def fix_hymns_seasonal(hs: dict) -> dict:
    hs = copy.deepcopy(hs)
    for season, entries in hs.items():
        for key, part in entries.items():
            part["variationKey"] = key
    return hs


def write_both(name: str, data) -> None:
    text = json.dumps(data, ensure_ascii=False, indent=2) + "\n"
    for root in (RESOURCES, ANDROID):
        (root / name).write_text(text, encoding="utf-8")
    digest = hashlib.md5(text.encode()).hexdigest()
    print(f"  wrote {name} ({len(text):,} bytes, md5 {digest})")


def strip_junk_doxologies(propers: dict) -> int:
    """A proper doxology override is the hymn's final 'Glória' stanza; an
    entry whose text lacks any 'glori' is an import artefact (e.g. the 09-15
    doxology, which held the feast TITLE) and must fall back to the common
    doxology instead of rendering junk."""
    removed = 0
    for entry in propers.values():
        for key in ("doxology", "doxology_"):
            part = entry.get(key)
            if part and "glori" not in part.get("lat", "").lower().replace("ó", "o"):
                del entry[key]
                removed += 1
    return removed


def main():
    ferial = build_ferial_parts()

    hours = json.loads((RESOURCES / "hours.json").read_text())
    pw = json.loads((RESOURCES / "psalter_weekly.json").read_text())
    hs = json.loads((RESOURCES / "hymns_seasonal.json").read_text())
    sp = json.loads((RESOURCES / "sanctoral_propers.json").read_text())
    tp = json.loads((RESOURCES / "temporal_propers.json").read_text())

    hours = fix_hours(hours)
    pw = fix_psalter_weekly(pw, ferial)
    hs = fix_hymns_seasonal(hs)
    junk = strip_junk_doxologies(sp) + strip_junk_doxologies(tp)
    print(f"  stripped {junk} junk doxology override(s)")

    write_both("hours.json", hours)
    write_both("psalter_weekly.json", pw)
    write_both("hymns_seasonal.json", hs)
    write_both("sanctoral_propers.json", sp)
    write_both("temporal_propers.json", tp)

    # ── QA ────────────────────────────────────────────────────────────────
    vesp = next(h for h in hours if h["slug"] == "vesperae")
    assert not any(p.get("variationKey") == "responsory_vespera_1" for p in vesp["parts"])
    assert not any("responsory_vespera_1" in pw[d] for d in pw)
    for d in WEEKDAYS.values():
        for k in ("hymnus_laudes", "hymnus_vespera", "ant_laudes", "ant_vespera", "versum_1"):
            assert k in pw[d], f"{d} missing {k}"
        for k, p in pw[d].items():
            assert p.get("variationKey") == k, f"{d}.{k} vk mismatch"
    for s, entries in hs.items():
        for k, p in entries.items():
            assert p.get("variationKey") == k, f"{s}.{k} vk mismatch"
    assert "versum_2" in pw["saturday"]
    prima = next(h for h in hours if h["slug"] == "prima")
    comp = next(h for h in hours if h["slug"] == "completorium")
    assert any(p.get("variationKey") == "oratio_prima" for p in prima["parts"])
    assert any(p.get("variationKey") == "oratio_completorium" for p in comp["parts"])
    print("QA: all structural assertions passed.")
    for d in WEEKDAYS.values():
        print(f"  {d}: Vespers hymn = {pw[d]['hymnus_vespera']['title']!r}; "
              f"Magnificat ant = {pw[d]['ant_vespera']['lat'][:48]!r}")


if __name__ == "__main__":
    main()
