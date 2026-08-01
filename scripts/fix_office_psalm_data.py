#!/usr/bin/env python3
"""
The three deep Office data repairs (register items 1-3), all data-only:

A. FERIAL MATINS PSALTER — psalter_weekly's Matins psalms matched no
   edition (Wednesday held Pss 38,39,43... instead of 44i,44ii,45,47,48i,
   48ii,49i,49ii,50). Rebuilt per weekday from DO's authoritative table
   (Psalterium/Psalmi/Psalmi matutinum.txt [DayN]): nine psalms with their
   own antiphons, divisi sliced verse-exactly out of psalter.json (whose
   lines preserve DO's verse labels 1:1), and the three nocturn versicles.

B. PROPER PSALM ASSIGNMENTS — DO antiphon sections carry ";;psalm"
   numbers the import dropped, so feasts sang proper antiphons over wrong
   psalms. For every temporal/sanctoral/commune entry whose DO source has
   a fully-numbered [Ant Matutinum]/[Ant Vespera (3)]/[Ant Laudes], emit
   explicit psalm-slot override parts (matutinum.psalmN / vesperae.psalmN
   / laudes.psalm1-3+canticle1+psalm4) with the antiphon attached and the
   verses inlined. Proper ONE-NOCTURN offices (Easter, Pentecost: three
   psalms) suppress the unused slots via "suppressed" parts; the
   assemblers trust pre-normalized entries (ant_1/2/3 kept verbatim).

C. COMMUNE/PROPER RESPONSORIES — office responsories sourced from
   "@File:Section:s/x/y/" references were skipped at import, leaving bare
   labels on commune-driven feasts (Apostles, Dedication, All Souls...).
   Re-resolved with sed-substitution support, both languages.

Requires the DO checkout. Idempotent; writes both platforms' assets.
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
HORAS_LAT = DO_ROOT / "web/www/horas/Latin"
HORAS_ENG = DO_ROOT / "web/www/horas/English"

PSALTER = json.loads((RESOURCES / "psalter.json").read_text())


# ── DO parsing ────────────────────────────────────────────────────────────────

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
    return sections


def apply_subs(text: str, subs: str) -> str:
    for m in re.finditer(r"s/((?:[^/\\]|\\.)*)/((?:[^/\\]|\\.)*)/([gi]*)", subs):
        pat, repl, flags = m.group(1), m.group(2), m.group(3)
        try:
            text = re.sub(pat, repl.replace("$1", r"\1"), text,
                          count=0 if "g" in flags else 1,
                          flags=re.IGNORECASE if "i" in flags else 0)
        except re.error:
            pass
    return text


def resolve_section(lang_root: Path, file_rel: str, section: str, depth: int = 0) -> str | None:
    """Section text with one-level @File:Section[:s/…/] resolution."""
    if depth > 3:
        return None
    sections = parse_sections(lang_root / f"{file_rel}.txt")
    if section not in sections:
        return None
    out = []
    for line in sections[section]:
        s = line.strip()
        m = re.match(r"^@([A-Za-z0-9/-]*):([^:]+?)(:(.*))?$", s)
        if m:
            target = m.group(1) or file_rel
            resolved = resolve_section(lang_root, target, m.group(2).strip(), depth + 1)
            if resolved is None:
                return None
            if m.group(4):
                resolved = apply_subs(resolved, m.group(4))
            out.append(resolved)
        elif s.startswith("!") or s.startswith("#"):
            continue
        else:
            out.append(line)
    text = "\n".join(out).strip()
    return re.sub(r"\{:[^}]*:\}", "", text).strip() or None


# ── psalm slicing ─────────────────────────────────────────────────────────────

REF_RE = re.compile(r"^(\d+)(?:\(('?[\w]+'?)-('?[\w]+'?)\))?\s*$")


def slice_psalm(num: int, start: str | None, end: str | None):
    """(lat_verses, eng_verses) for psalm `num`, optionally from verse label
    `start` to `end` inclusive. psalter.json lines carry 'N:label text'."""
    entry = PSALTER.get(f"psalm{num}")
    if not entry:
        return None
    lat, eng = entry.get("lat") or [], entry.get("eng") or []
    if start is None:
        return lat, eng
    s = start.strip("'")
    e = end.strip("'")
    idx_s = idx_e = None
    for i, line in enumerate(lat):
        m = re.match(rf"^{num}:(\S+)\s", line)
        if not m:
            continue
        if m.group(1) == s and idx_s is None:
            idx_s = i
        if m.group(1) == e:
            idx_e = i
    if idx_s is None or idx_e is None or idx_e < idx_s:
        return None
    return lat[idx_s:idx_e + 1], eng[idx_s:idx_e + 1] if eng else []


def psalm_part(vk: str, num: int, start, end, ant_lat: str | None, ant_eng: str | None):
    sliced = slice_psalm(num, start, end)
    if sliced is None:
        return None
    lat_v, eng_v = sliced
    label = f"Psalmus {num}" if start is None \
        else f"Psalmus {num} ({start.strip(chr(39))}-{end.strip(chr(39))})"
    kind = "canticle" if num > 150 else "psalm"
    if num > 150:
        label = f"Canticum ({num})"
    part = {
        "type": kind, "label": label, "ref": f"Ps {num}" if num <= 150 else None,
        "variationKey": vk,
        "verses": [{"lat": l, "eng": eng_v[i] if i < len(eng_v) else ""}
                   for i, l in enumerate(lat_v)],
    }
    if part["ref"] is None:
        del part["ref"]
    if ant_lat:
        part["antiphonLat"] = ant_lat
        part["antiphonEng"] = ant_eng or ""
    return part


def ant_part(vk: str, lat: str, eng: str | None):
    return {"type": "antiphon", "label": "Antíphona", "lat": lat,
            "eng": eng or "", "variationKey": vk}


SUPPRESSED = {"type": "suppressed"}


def parse_ant_lines(lines: list):
    """Antiphon;;ref lines + interleaved V./R. pairs from a DO section."""
    ants, versicles = [], []
    pending_v = None
    for raw in lines:
        s = re.sub(r"\{:[^}]*:\}", "", raw).strip()
        if not s or s.startswith("!") or s.startswith("#") or s.startswith("("):
            continue
        if s.startswith("V. "):
            pending_v = s[3:]
            continue
        if s.startswith("R. "):
            versicles.append((pending_v or "", s[3:]))
            pending_v = None
            continue
        if ";;" in s:
            text, _, ref = s.rpartition(";;")
            m = REF_RE.match(ref.strip())
            if not m:
                return None, None  # unparseable ref: bail on the section
            ants.append((text.strip(), int(m.group(1)), m.group(2), m.group(3)))
        else:
            return None, None      # antiphon without a psalm ref: not usable
    return ants, versicles


# ── A. ferial Matins psalter ─────────────────────────────────────────────────

MATINS_SLOTS = [f"matutinum.psalm{i}" for i in range(2, 11)]
WEEKDAYS = {1: "monday", 2: "tuesday", 3: "wednesday",
            4: "thursday", 5: "friday", 6: "saturday"}


def rebuild_ferial_matins(pw: dict) -> None:
    lat_tab = parse_sections(HORAS_LAT / "Psalterium/Psalmi/Psalmi matutinum.txt")
    eng_tab = parse_sections(HORAS_ENG / "Psalterium/Psalmi/Psalmi matutinum.txt")
    for n, day in WEEKDAYS.items():
        ants, versicles = parse_ant_lines(lat_tab[f"Day{n}"])
        eng_ants, eng_versicles = parse_ant_lines(eng_tab.get(f"Day{n}", []))
        assert ants and len(ants) == 9, f"Day{n}: expected 9 psalms, got {ants and len(ants)}"
        assert len(versicles) == 3, f"Day{n}: expected 3 versicles"
        entry = pw[day]
        for i, (text, num, s, e) in enumerate(ants):
            eng_text = eng_ants[i][0] if eng_ants and i < len(eng_ants) else ""
            part = psalm_part(MATINS_SLOTS[i], num, s, e, text, eng_text)
            assert part, f"Day{n} psalm {num}({s}-{e}) failed to slice"
            entry[MATINS_SLOTS[i]] = part
        # Nocturn-opening antiphons = antiphons of psalms 1, 4, 7.
        for slot, idx in (("ant_1", 0), ("ant_2", 3), ("ant_3", 6)):
            eng_text = eng_ants[idx][0] if eng_ants and idx < len(eng_ants) else ""
            entry[slot] = ant_part(slot, ants[idx][0], eng_text)
        for i, (v, r) in enumerate(versicles):
            ev, er = (eng_versicles[i] if eng_versicles and i < len(eng_versicles)
                      else ("", ""))
            entry[f"nocturn_{i + 1}_versum"] = {
                "type": "vr", "label": f"Versicle after Nocturn {'I' * (i + 1)}",
                "lat": f"℣. {v}", "latR": f"℟. {r}",
                "eng": f"℣. {ev}" if ev else "", "engR": f"℟. {er}" if er else "",
                "variationKey": f"nocturn_{i + 1}_versum",
            }
    print("  A: ferial Matins psalter rebuilt for 6 weekdays")


# ── B. proper psalm slots ────────────────────────────────────────────────────

def do_file_for(corpus: str, key: str):
    if corpus == "commune":
        return f"Commune/{key}"
    if corpus == "sanctoral":
        for cand in (key, key.upper(), key.replace("du", "DU")):
            if (HORAS_LAT / f"Sancti/{cand}.txt").exists():
                return f"Sancti/{cand}"
        return None
    stem = key[0].upper() + key[1:]
    return f"Tempora/{stem}" if (HORAS_LAT / f"Tempora/{stem}.txt").exists() else None


def section_lines(lang_root: Path, rel: str, section: str, depth: int = 0):
    """Raw lines of [section], following whole-line @File[:Section] refs
    (a bare @File pulls the SAME-named section from the target file)."""
    if depth > 3:
        return None
    sections = parse_sections(lang_root / f"{rel}.txt")
    if section not in sections:
        return None
    out = []
    for line in sections[section]:
        s = line.strip()
        m = re.match(r"^@([A-Za-z0-9/-]*)(?::([^:]+?))?(:s/.*)?$", s)
        if m and s.startswith("@"):
            target = m.group(1) or rel
            target_section = (m.group(2) or section).strip()
            resolved = section_lines(lang_root, target, target_section, depth + 1)
            if resolved is None:
                return None
            if m.group(3):
                resolved = [apply_subs(l, m.group(3)) for l in resolved]
            out.extend(resolved)
        else:
            out.append(line)
    return out


def proper_slots_for_entry(rel: str):
    """Dict of new slot parts for one DO file, or {}."""
    lat = {s: section_lines(HORAS_LAT, rel, s)
           for s in ("Ant Matutinum", "Ant Vespera 3", "Ant Vespera", "Ant Laudes")
           if section_lines(HORAS_LAT, rel, s) is not None}
    out = {}

    def eng_ants_for(section):
        lines = section_lines(HORAS_ENG, rel, section)
        if lines is None:
            return []
        a, _ = parse_ant_lines(lines)
        return a or []

    # Matins
    if "Ant Matutinum" in lat:
        ants, versicles = parse_ant_lines(lat["Ant Matutinum"])
        if ants and len(ants) in (3, 9):
            e = eng_ants_for("Ant Matutinum")
            parts = {}
            ok = True
            for i, (text, num, s, en) in enumerate(ants):
                p = psalm_part(MATINS_SLOTS[i], num, s, en, text,
                               e[i][0] if i < len(e) else "")
                if not p:
                    ok = False
                    break
                parts[MATINS_SLOTS[i]] = p
            if ok:
                if len(ants) == 3:
                    for slot in MATINS_SLOTS[3:]:
                        parts[slot] = dict(SUPPRESSED, variationKey=slot)
                    # Nocturn antiphon slots under PREFIXED keys: the plain
                    # ant_1/2/3 keys hold the CANTICLE antiphons in DO-sourced
                    # entries and must not be clobbered.
                    parts["matutinum.ant_1"] = ant_part("ant_1", ants[0][0],
                                                        e[0][0] if e else "")
                    parts["matutinum.ant_2"] = dict(SUPPRESSED, variationKey="ant_2")
                    parts["matutinum.ant_3"] = dict(SUPPRESSED, variationKey="ant_3")
                    if versicles:
                        v, r = versicles[0]
                        parts["nocturn_1_versum"] = {
                            "type": "vr", "label": "Versicle",
                            "lat": f"℣. {v}", "latR": f"℟. {r}",
                            "eng": "", "engR": "",
                            "variationKey": "nocturn_1_versum",
                        }
                else:
                    for slot, idx in (("ant_1", 0), ("ant_2", 3), ("ant_3", 6)):
                        parts[f"matutinum.{slot}"] = ant_part(
                            slot, ants[idx][0],
                            e[idx][0] if idx < len(e) else "")
                out.update(parts)
                out["__drop_ant_matutinum"] = True

    # Vespers (prefer the 2nd-Vespers set)
    for section in ("Ant Vespera 3", "Ant Vespera"):
        if section in lat:
            ants, _ = parse_ant_lines(lat[section])
            if ants and len(ants) == 5:
                e = eng_ants_for(section)
                parts = {}
                ok = True
                for i, (text, num, s, en) in enumerate(ants):
                    p = psalm_part(f"vesperae.psalm{i + 1}", num, s, en, text,
                                   e[i][0] if i < len(e) else "")
                    if not p:
                        ok = False
                        break
                    parts[f"vesperae.psalm{i + 1}"] = p
                if ok:
                    out.update(parts)
            break

    # Lauds: positions 1,2,3 psalms; 4 = canticle slot; 5 = psalm4.
    if "Ant Laudes" in lat:
        ants, _ = parse_ant_lines(lat["Ant Laudes"])
        if ants and len(ants) == 5:
            e = eng_ants_for("Ant Laudes")
            slots = ["laudes.psalm1", "laudes.psalm2", "laudes.psalm3",
                     "laudes.canticle1", "laudes.psalm4"]
            parts = {}
            ok = True
            for i, (text, num, s, en) in enumerate(ants):
                p = psalm_part(slots[i], num, s, en, text,
                               e[i][0] if i < len(e) else "")
                if not p:
                    ok = False
                    break
                parts[slots[i]] = p
            if ok:
                out.update(parts)
    return out


def add_proper_slots(corpora: dict) -> None:
    added = entries = 0
    for corpus_name, data in corpora.items():
        for key, entry in data.items():
            if not isinstance(entry, dict):
                continue
            rel = do_file_for(corpus_name, key)
            if not rel:
                continue
            slots = proper_slots_for_entry(rel)
            if not slots:
                continue
            if slots.pop("__drop_ant_matutinum", None):
                entry.pop("ant_matutinum", None)
            entry.update(slots)
            entries += 1
            added += len(slots)
    print(f"  B: proper psalm slots added to {entries} entries ({added} parts)")


# ── C. responsories ──────────────────────────────────────────────────────────

def fill_responsories(corpora: dict) -> None:
    filled = 0
    for corpus_name, data in corpora.items():
        for key, entry in data.items():
            if not isinstance(entry, dict):
                continue
            rel = do_file_for(corpus_name, key)
            if not rel:
                continue
            sections = parse_sections(HORAS_LAT / f"{rel}.txt")
            for n in range(1, 10):
                sec = f"Responsory{n}"
                field = f"responsory{n}"
                if sec not in sections:
                    continue
                current = entry.get(field)
                if current and (current.get("lat") or "").strip():
                    continue
                lat = resolve_section(HORAS_LAT, rel, sec)
                if not lat:
                    continue
                eng = resolve_section(HORAS_ENG, rel, sec) or ""
                entry[field] = {
                    "type": "responsory", "label": "Responsorium",
                    "lat": lat, "eng": eng, "variationKey": field,
                }
                filled += 1
    print(f"  C: {filled} responsories resolved")


# ── main ─────────────────────────────────────────────────────────────────────

def write_both(name: str, data) -> None:
    text = json.dumps(data, ensure_ascii=False, indent=2) + "\n"
    for root in (RESOURCES, ANDROID):
        (root / name).write_text(text, encoding="utf-8")


def main():
    pw = json.loads((RESOURCES / "psalter_weekly.json").read_text())
    tp = json.loads((RESOURCES / "temporal_propers.json").read_text())
    sp = json.loads((RESOURCES / "sanctoral_propers.json").read_text())
    co = json.loads((RESOURCES / "commune_office.json").read_text())

    rebuild_ferial_matins(pw)
    corpora = {"temporal": tp, "sanctoral": sp, "commune": co}
    add_proper_slots(corpora)
    fill_responsories(corpora)

    write_both("psalter_weekly.json", pw)
    write_both("temporal_propers.json", tp)
    write_both("sanctoral_propers.json", sp)
    write_both("commune_office.json", co)

    # ── QA ──
    wed = pw["wednesday"]["matutinum.psalm2"]
    assert wed["label"].startswith("Psalmus 44"), wed["label"]
    assert wed["antiphonLat"].startswith("Speciósus forma"), wed["antiphonLat"]
    assert pw["saturday"]["matutinum.psalm2"]["label"].startswith("Psalmus 104")
    assert sp["08-15"]["matutinum.psalm2"]["label"].startswith("Psalmus 8")
    assert sp["08-15"]["vesperae.psalm3"]["label"].startswith("Psalmus 121")
    assert tp["pasc0-0"]["matutinum.psalm5"]["type"] == "suppressed"
    assert (co["C1"]["responsory4"]["lat"] or "").strip()
    print("QA: psalm-data assertions passed.")


if __name__ == "__main__":
    main()
