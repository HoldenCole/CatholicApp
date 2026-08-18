#!/usr/bin/env python3
"""Import Spanish Mass propers from the Divinum Officium Espanol tree.

Tranche-based by design: a WHITELIST of temporal and sanctoral keys imports
only when the Spanish source passes a per-formulary completeness gate — a
day either gets its full set of orations and antiphons in Spanish or stays
entirely English. Three sources compose: DO's Espanol day files, our own
supplements (propers_supplements_es.json), and the commune line table
(propers_commune_es.json) which translates shared Latin lines once and
fans them out wherever the same Latin recurs.
Scripture ([Lectio]/[Evangelium]) is deliberately NOT imported: the DO
Spanish readings are in a modern register of uncertain provenance; they wait
for a public-domain source decision (Torres Amat).

Output: spanish-translation/missal_propers_es.json
    { "<missal_tempora key>": { "<field>": "<es text>" } }
where <field> ∈ introitus, oratio, graduale, offertorium, secreta,
communio, postcommunio (eng-side replacements only; lat and ref untouched).

Run:  python3 scripts/import_spanish_propers.py [--do <path-to-DO-clone>]
      python3 scripts/sync_spanish_assets.py
"""
import json
import re
import sys
import unicodedata
from pathlib import Path


def nfc(s):
    return unicodedata.normalize("NFC", s)

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_DO = Path("/tmp/claude-0/-home-user-CatholicApp/"
                  "71906fbb-67e9-553f-b996-d8565178e126/scratchpad/do_repo")
DO = Path(sys.argv[sys.argv.index("--do") + 1]) if "--do" in sys.argv else DEFAULT_DO
MISSA_ES = DO / "web" / "www" / "missa" / "Espanol"
OUT = ROOT / "spanish-translation" / "missal_propers_es.json"

# Tranche 1: Advent through Time after Epiphany.
# Tranche 2: Septuagesima (quadp) through Lent and Holy Week (quad).
# Tranche 3: Eastertide (pasc) and the season after Pentecost (pent).
# Tranche 5: the sanctoral cycle (MM-DD keys, DO Sancti tree).
TRANCHE = re.compile(r"^(adv|nat|epi|quad|pasc|pent|\d\d\d?-|C\d)")

# Our own tier-2 supplements: fields the DO Espanol files omit, translated
# from the Latin in spanish-translation/propers_supplements_es.json (built
# incrementally, tranche by tranche — single missing orations first, then
# whole formularies for days DO leaves as stubs, e.g. Easter Sunday and the
# rest of Eastertide). Applied BEFORE the completeness gate.
SUPPLEMENTS_PATH = ROOT / "spanish-translation" / "propers_supplements_es.json"
SUPPLEMENTS = (json.load(open(SUPPLEMENTS_PATH, encoding="utf-8"))
               if SUPPLEMENTS_PATH.exists() else {})

# Latin-line -> Spanish-line table for the shared commune texts (our own
# tier-2 translations; see spanish-translation/propers_commune_es.json).
# Keys are alleluia-normalized lines; compose_from_lines() re-attaches the
# stripped "(Allelúja…)" / sentence-final "Allelúja…" markers in Spanish.
COMMUNE_PATH = ROOT / "spanish-translation" / "propers_commune_es.json"
COMMUNE = ({nfc(k): v for k, v in
            json.load(open(COMMUNE_PATH, encoding="utf-8")).items()}
           if COMMUNE_PATH.exists() else {})

GLORIA_ES = ("Gloria al Padre, y al Hijo, y al Espíritu Santo. Como era en "
             "el principio, ahora y siempre, por los siglos de los siglos. "
             "Amén.")
_PER_DOM_ES = ("Por nuestro Señor Jesucristo, tu Hijo, que vive y reina "
               "contigo en la unidad del Espíritu Santo, Dios, por todos "
               "los siglos de los siglos. Amén.")
CONCL_ES = {
    ("Per Dóminum nostrum Jesum Christum, Fílium tuum: qui tecum vivit et "
     "regnat in unitáte Spíritus Sancti, Deus, per ómnia sǽcula sæculórum. "
     "Amen."): _PER_DOM_ES,
    ("Per Dóminum nostrum Jesum Christum, Fílium tuum: qui tecum vivit et "
     "regnat in unitáte Spíritus Sancti, Deus, per ómnia sǽcula sæculórum. "
     "Amen.."): _PER_DOM_ES,
    ("Per Dóminum nostrum Jesum Christum Fílium tuum, qui tecum vivit et "
     "regnat in unitáte Spíritus Sancti, Deus, per ómnia sǽcula sæculórum. "
     "Amen."): _PER_DOM_ES,
    ("Per eúndem Dóminum nostrum Jesum Christum Fílium tuum, qui tecum "
     "vivit et regnat in unitáte Spíritus Sancti, Deus, per ómnia sǽcula "
     "sæculórum. Amen."):
        "Por el mismo Jesucristo nuestro Señor, tu Hijo, que vive y reina "
        "contigo en la unidad del Espíritu Santo, Dios, por todos los "
        "siglos de los siglos. Amén.",
    ("Per Dóminum nostrum Jesum Christum Fílium tuum, qui tecum vivit et "
     "regnat in unitáte ejúsdem Spíritus Sancti, Deus, per ómnia sǽcula "
     "sæculórum. Amen."):
        "Por nuestro Señor Jesucristo, tu Hijo, que vive y reina contigo "
        "en la unidad del mismo Espíritu Santo, Dios, por todos los siglos "
        "de los siglos. Amén.",
    ("Qui tecum vivit et regnat in unitáte Spíritus Sancti, Deus, per "
     "ómnia sǽcula sæculórum. Amen."):
        "Que contigo vive y reina en la unidad del Espíritu Santo, Dios, "
        "por todos los siglos de los siglos. Amén.",
    ("Qui vivis et regnas cum Deo Patre, in unitáte Spíritus Sancti, Deus, "
     "per ómnia sǽcula sæculórum. Amen."):
        "Tú que vives y reinas con Dios Padre en la unidad del Espíritu "
        "Santo, y eres Dios por todos los siglos de los siglos. Amén.",
    ("Qui vivis et regnas cum Deo Patre in unitáte Spíritus Sancti, Deus, "
     "per ómnia sǽcula sæculórum. Amen."):
        "Tú que vives y reinas con Dios Padre en la unidad del Espíritu "
        "Santo, y eres Dios por todos los siglos de los siglos. Amén.",
    # a data artifact: "eiusdem" tag appended after the response — render
    # the ejúsdem (same-Spirit) form it flags
    ("Per Dóminum nostrum Jesum Christum, Fílium tuum: qui tecum vivit et "
     "regnat in unitáte Spíritus Sancti, Deus, per ómnia sǽcula sæculórum. "
     "Amen. eiusdem"):
        "Por nuestro Señor Jesucristo, tu Hijo, que vive y reina contigo "
        "en la unidad del mismo Espíritu Santo, Dios, por todos los siglos "
        "de los siglos. Amén.",
}

# Name-parameterized commune oration templates (see
# spanish-translation/propers_templates_es.json): the sanctoral instantiates
# a small set of commune orations with each saint's name; a template pairs
# the Latin shape ({N} = name slot) with our Spanish, and `names` maps every
# captured Latin name phrase to its traditional Spanish form. An unmapped
# name refuses to compose — no guessing.
TEMPLATES_PATH = ROOT / "spanish-translation" / "propers_templates_es.json"
if TEMPLATES_PATH.exists():
    _t = json.load(open(TEMPLATES_PATH, encoding="utf-8"))
    TEMPLATE_NAMES = {nfc(k): v for k, v in _t["names"].items()}
    TEMPLATES = [(re.compile(re.escape(nfc(e["lat"]))
                             .replace(r"\{N\}", "(.+?)")
                             .replace(r"\{N}", "(.+?)")), e["es"])
                 for e in sorted(_t["templates"],
                                 key=lambda e: -len(e["lat"]))]
else:
    TEMPLATE_NAMES, TEMPLATES = {}, []


def template_line(line):
    for regex, es_tmpl in TEMPLATES:
        m = regex.fullmatch(line)
        if m:
            name_es = TEMPLATE_NAMES.get(nfc(m.group(1).strip()))
            if name_es:
                return es_tmpl.replace("{N}", name_es)
    return None


ALLE_SUFFIX = re.compile(
    r"(\s*\((?:Allelúja|Allelúia|Alleluia|Alleluja)[^)]*\)\.?"
    r"|\s+(?:Allelúja|Allelúia|Alleluia|Alleluja)"
    r"(?:,\s*(?:allelúja|allelúia|alleluia|alleluja))*\.?)$")


def compose_from_lines(lat):
    """Line-by-line Spanish for a field whose every line is covered by the
    commune table (plus Gloria Patri and the standard conclusions).
    Returns None unless ALL lines resolve — the gate stays honest."""
    out = []
    for raw in lat.split("\n"):
        line = nfc(raw.strip())   # source data mixes NFC/NFD accents
        if not line:
            continue
        if line.startswith("Glória Patri, et Fílio"):
            out.append(GLORIA_ES)
            continue
        if line in CONCL_ES:
            out.append(CONCL_ES[line])
            continue
        # one conclusion line in the source is mojibake-damaged ("ó" became
        # two replacement chars); repair and retry before giving up on it
        repaired = line.replace("��", "ó")
        if repaired in CONCL_ES:
            out.append(CONCL_ES[repaired])
            continue
        if line == "&Glória":     # a raw DO macro leaked into the data
            out.append(GLORIA_ES)
            continue
        suffix, base = "", line
        m = ALLE_SUFFIX.search(line)
        if m and m.start() > 0:
            base = line[:m.start()]
            suffix = re.sub(r"[Aa]llel[úu][ji]a",
                            lambda x: "Aleluya" if x.group(0)[0] == "A"
                            else "aleluya", m.group(1))
        es = COMMUNE.get(base)
        if es is None:
            es = template_line(base)
        if es is None:
            return None
        if es == "":
            continue   # mapped to nothing (junk line the English drops too)
        out.append(es + suffix)
    return "\n".join(out) if out else None


FIELDS = {
    "introitus": "Introitus",
    "oratio": "Oratio",
    "graduale": "Graduale",
    "offertorium": "Offertorium",
    "secreta": "Secreta",
    "communio": "Communio",
    "postcommunio": "Postcommunio",
}
# The gate: a formulary imports only if ALL of these resolved in Spanish.
# (graduale is exempt — a handful of days legitimately lack one.)
REQUIRED = ["introitus", "oratio", "offertorium", "secreta", "communio",
            "postcommunio"]


def has_field(src_entry, field):
    """A field counts only if it carries text — a few days have an entry
    whose lat AND eng are both blank (a data artifact); the gate must not
    demand Spanish for nothing."""
    v = src_entry.get(field)
    if v is None:
        return False
    return bool((v.get("lat") or "").strip() or (v.get("eng") or "").strip())


def parse_sections(text):
    sections, current, lines = {}, None, []
    for line in text.split("\n"):
        line = line.rstrip()
        if line.startswith("[") and line.endswith("]"):
            if current is not None:
                sections[current] = "\n".join(lines).strip()
            current, lines = line[1:-1], []
        else:
            lines.append(line)
    if current is not None:
        sections[current] = "\n".join(lines).strip()
    return sections


def read_file(rel):
    p = MISSA_ES / f"{rel}.txt"
    if not p.exists():
        return None
    return p.read_text(encoding="utf-8", errors="replace")


def load_formulary(rel, depth=0):
    """Sections of a Spanish formulary, following whole-file @redirects."""
    if depth > 3:
        return None
    text = read_file(rel)
    if text is None:
        return None
    first = text.strip().split("\n")[0].strip()
    if first.startswith("@"):
        target = first[1:].split(":")[0].strip()
        base = load_formulary(target, depth + 1) or {}
        base.update({k: v for k, v in parse_sections(text).items() if v.strip()})
        return base
    return parse_sections(text)


# Conclusion formulas ($Per Dominum …) from the Spanish Ordo/Prayers.txt.
def load_conclusions():
    text = read_file("Ordo/Prayers")
    out = {}
    for name, body in parse_sections(text).items():
        lines = []
        for line in body.split("\n"):
            line = line.strip()
            if not line:
                continue
            if line.startswith(("r. ", "v. ")):
                line = line[3:]
            elif line.startswith(("R. ", "V. ")):
                line = line[3:]
            lines.append(line)
        if lines:
            out[name] = " ".join(lines)
    return out


CONCLUSIONS = None
GLORIA_PATRI = None


def resolve_inline_refs(body, depth=0):
    """Resolve @File[:Section] lines inside a section from the Espanol tree.
    An unresolvable reference fails the section (-> field falls back)."""
    if depth > 3:
        return None
    out = []
    for line in body.split("\n"):
        stripped = line.strip()
        if stripped.startswith("@"):
            ref = stripped[1:]
            sect = None
            if ":" in ref:
                ref, sect = ref.split(":", 1)
                sect = sect.split(":")[0]
            target = load_formulary(ref.strip()) if ref.strip() else None
            if target is None:
                return None
            if sect:
                if sect not in target:
                    return None
                resolved = resolve_inline_refs(target[sect], depth + 1)
                if resolved is None:
                    return None
                out.append(resolved)
            else:
                return None  # whole-file inline ref inside a section: bail
            continue
        out.append(line)
    return "\n".join(out)


def render_section(name, body):
    """DO section markup -> the eng-side conventions of missal_tempora.json:
    newline-joined verse lines, 'V.' markers, &Gloria expanded, $conclusion
    appended on its own line. Returns None if the section can't be rendered
    faithfully (the field then falls back to English)."""
    body = resolve_inline_refs(body)
    if body is None:
        return None
    lines_out = []
    antiphon_so_far = []  # for the introit repeat after &Gloria
    for raw in body.split("\n"):
        line = raw.strip()
        if not line:
            continue
        if line.startswith("!"):        # scripture reference line — ref field
            continue                     # already carries this from English
        if line.startswith("v. "):
            line = line[3:]
        if line.startswith("V. ") or line.startswith("R. "):
            pass
        elif re.match(r"^[VR]\.\S", line):
            line = line[0] + ". " + line[2:]
        if line.startswith("&"):
            macro = line[1:].split(" ")[0]
            if macro in ("Gloria", "GloriaL"):
                if GLORIA_PATRI:
                    lines_out.append(GLORIA_PATRI)
                    antiphon_so_far = None  # repeats follow explicitly
                    continue
                return None
            return None                  # unknown & macro — don't guess
        if line.startswith("$"):
            macro = line[1:].strip()
            base = macro if (CONCLUSIONS and macro in CONCLUSIONS) \
                else macro.rstrip(".")
            if CONCLUSIONS and base in CONCLUSIONS:
                concl = CONCLUSIONS[base]
                if not concl.rstrip().endswith(("Amén.", "Amen.")):
                    concl += " Amén."    # some formulas lack the response
                lines_out.append(concl)
                continue
            return None                  # unknown $ macro — don't guess
        if line.startswith(("_", "//")):
            continue
        if antiphon_so_far is not None:
            antiphon_so_far.append(line)
        lines_out.append(line)
    text = "\n".join(lines_out).strip()
    if not text:
        return None
    if "@" in text or text.startswith("$"):
        return None
    return text


def main():
    global CONCLUSIONS, GLORIA_PATRI
    if not MISSA_ES.is_dir():
        sys.exit(f"DO Espanol tree not found at {MISSA_ES} — pass --do <clone>")
    CONCLUSIONS = load_conclusions()
    gloria = CONCLUSIONS.get("Gloria")
    GLORIA_PATRI = gloria
    assert GLORIA_PATRI and "Gloria" in GLORIA_PATRI or "Gloria al Padre" in (gloria or ""), \
        f"unexpected Spanish Gloria Patri: {gloria!r}"

    tempora = json.load(open(ROOT / "Introibo" / "Resources" / "missal_tempora.json"))
    sanctoral = json.load(open(ROOT / "Introibo" / "Resources" / "missal_sanctoral.json"))
    sources = {**{k: ("Tempora/" + k[0].upper() + k[1:], v) for k, v in tempora.items()},
               **{k: ("Sancti/" + k, v) for k, v in sanctoral.items()}}
    keys = sorted(k for k in sources if TRANCHE.match(k))

    out, skipped = {}, []
    for key in keys:
        rel, src_entry = sources[key]
        sections = load_formulary(rel)
        if sections is None:
            if key in SUPPLEMENTS:
                sections = {}   # supplement-only day (no upstream file)
            else:
                skipped.append((key, "no Spanish file", {}))
                continue
        entry = {}
        for field, section in FIELDS.items():
            if not has_field(src_entry, field):
                continue                 # English side has no such field
            if section not in sections or not sections[section].strip():
                continue
            rendered = render_section(section, sections[section])
            if rendered:
                entry[field] = rendered
        for field, text in SUPPLEMENTS.get(key, {}).items():
            entry.setdefault(field, text)
        missing = [f for f in REQUIRED
                   if has_field(src_entry, f) and f not in entry]
        if missing:
            # Keep the partial entry: the propagation pass below may finish
            # it via identical-Latin fields from days that did import.
            skipped.append((key, f"gate: missing {','.join(missing)}", entry))
            continue
        if not entry:
            # A feria with no proper fields of its own inherits the Sunday's
            # formulary at render time — nothing to overlay.
            continue
        out[key] = entry

    # Same-Latin propagation: identical Latin gets identical Spanish. This
    # fills the 1955 "t"/"r" variants and the November resumed Sundays from
    # their base formularies, and any shared antiphons, without a second
    # translation that could drift. The completeness gate still applies.
    latin_to_es = {}
    for key, entry in out.items():
        for field, es in entry.items():
            src = sources[key][1].get(field)
            if src and src.get("lat"):
                latin_to_es.setdefault(src["lat"], es)
    promoted = 0
    while True:  # to fixpoint: promoted days feed further Latin matches
        still_skipped, changed = [], False
        for key, why, partial in skipped:
            rel, src_entry = sources[key]
            entry = dict(partial)
            for field in FIELDS:
                v = src_entry.get(field)
                if v is None or field in entry or not has_field(src_entry, field):
                    continue
                lat = v.get("lat") or ""
                es = latin_to_es.get(lat) or compose_from_lines(lat)
                if es:
                    entry[field] = es
            missing = [f for f in REQUIRED
                       if has_field(src_entry, f) and f not in entry]
            if entry and not missing:
                out[key] = entry
                promoted += 1
                changed = True
                for field, es in entry.items():
                    src = src_entry.get(field)
                    if src and src.get("lat"):
                        latin_to_es.setdefault(src["lat"], es)
            else:
                still_skipped.append((key, why, entry))
        skipped = still_skipped
        if not changed:
            break
    # Backfill pass: an imported day may still lack a field the gate exempts
    # (graduale) or one filled late into the tables — compose those too.
    backfilled = 0
    for key, entry in out.items():
        src_entry = sources[key][1]
        for field in FIELDS:
            v = src_entry.get(field)
            if field in entry or v is None or not has_field(src_entry, field):
                continue
            lat = v.get("lat") or ""
            es = latin_to_es.get(lat) or compose_from_lines(lat)
            if es:
                entry[field] = es
                backfilled += 1
    print(f"backfilled {backfilled} exempt fields on imported days")

    if "--report" in sys.argv:  # remaining missing Latin, for tranche planning
        report = {}
        for key, why, entry in skipped:
            src_entry = sources[key][1]
            report[key] = {f: src_entry[f]["lat"] for f in FIELDS
                           if has_field(src_entry, f) and f not in entry}
        Path(sys.argv[sys.argv.index("--report") + 1]).write_text(
            json.dumps(report, ensure_ascii=False, indent=1), encoding="utf-8")
    skipped = [(key, why) for key, why, _ in skipped]
    print(f"same-Latin propagation promoted {promoted} formularies")

    OUT.write_text(json.dumps(out, ensure_ascii=False, indent=2,
                              sort_keys=True) + "\n", encoding="utf-8")

    # ---- QA ----
    assert "adv1-0" in out, "Advent I must import"
    assert out["adv1-0"]["introitus"].startswith("A ti, Señor, levanto mi alma"), \
        out["adv1-0"]["introitus"][:60]
    assert out["adv1-0"]["oratio"].startswith("Despierta, Señor, tu potencia")
    assert "Tú que vives y reinas" in out["adv1-0"]["oratio"], \
        "conclusion must be expanded"
    assert "quadp1-0" in out, "Septuagesima must import (supplemented secreta)"
    assert out["quadp1-0"]["secreta"].startswith("Recibidos, Señor")
    assert "quad3-0" in out and "quad5-5" in out
    for key, entry in out.items():
        assert key in sources, key
        for field, text in entry.items():
            assert text.strip(), f"{key}.{field} empty"
            for bad in ("@", "&", "\n$"):
                assert bad not in text, f"{key}.{field} carries DO markup: {bad}"
            assert not text.startswith("$"), f"{key}.{field} unexpanded macro"
            assert "lectio" != field and "evangelium" != field

    print(f"imported {len(out)} formularies "
          f"({sum(len(e) for e in out.values())} fields); "
          f"skipped {len(skipped)}:")
    for key, why in skipped:
        print(f"  - {key}: {why}")


if __name__ == "__main__":
    main()
