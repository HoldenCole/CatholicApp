#!/usr/bin/env python3
"""Import Spanish Mass propers from the Divinum Officium Espanol tree.

Tranche-based by design: a WHITELIST of temporal keys imports only when the
Spanish source passes a per-formulary completeness gate — a day either gets
its full set of orations and antiphons in Spanish or stays entirely English.
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
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_DO = Path("/tmp/claude-0/-home-user-CatholicApp/"
                  "71906fbb-67e9-553f-b996-d8565178e126/scratchpad/do_repo")
DO = Path(sys.argv[sys.argv.index("--do") + 1]) if "--do" in sys.argv else DEFAULT_DO
MISSA_ES = DO / "web" / "www" / "missa" / "Espanol"
OUT = ROOT / "spanish-translation" / "missal_propers_es.json"

# Tranche 1: Advent through Time after Epiphany.
# Tranche 2: Septuagesima (quadp) through Lent and Holy Week (quad).
# Tranche 3: Eastertide (pasc) and the season after Pentecost (pent).
TRANCHE = re.compile(r"^(adv|nat|epi|quad|pasc|pent)")

# Our own tier-2 supplements: single fields the DO Espanol files omit,
# translated here from the Latin so a whole Sunday isn't blocked by one
# missing oration. Applied BEFORE the completeness gate.
PER_DOMINUM_ES = ("Por nuestro Señor Jesucristo, tu Hijo, que vive y reina "
                  "contigo en la unidad del Espíritu Santo, Dios, por todos "
                  "los siglos de los siglos. Amén.")
MUNERIBUS_ES = ("Recibidos, Señor, nuestros dones y súplicas, te rogamos que "
                "nos purifiques con estos celestiales misterios y nos "
                "escuches con clemencia.\n" + PER_DOMINUM_ES)
SUPPLEMENTS = {
    # Septuagesima Sunday and Advent Ember Friday share the Muneribus
    # nostris secret (as does Jan 1, outside this temporal tranche).
    "quadp1-0": {"secreta": MUNERIBUS_ES},
    "adv3-5": {"secreta": MUNERIBUS_ES},
    # Lent III Sunday — Justitiæ Dómini (Ps 18:9-12).
    "quad3-0": {"offertorium": (
        "Los preceptos del Señor son rectos y alegran los corazones; sus "
        "juicios, más dulces que la miel y el panal; por eso tu siervo los "
        "guarda.")},
    # Passion Friday (Seven Sorrows) — Recordáre, Virgo Mater.
    "quad5-5": {"offertorium": (
        "Acuérdate, Virgen Madre, de hablar en favor nuestro ante Dios, "
        "para que aparte de nosotros su indignación.")},
    # Easter Sunday: DO's Espanol Eastertide is name-only stubs, and the
    # queen of feasts should not fall back to English. Full formulary
    # translated here from the Latin, line-mirrored to the English entry.
    "pasc0-0": {
        "introitus": (
            "Resucité, y aún estoy contigo, aleluya: pusiste sobre mí tu "
            "mano, aleluya: tu sabiduría se ha mostrado admirable, aleluya, "
            "aleluya.\n"
            "Señor, tú me has probado y me has conocido: tú conociste mi "
            "descanso y mi resurrección.\n"
            "Gloria al Padre, y al Hijo, y al Espíritu Santo. Como era en el "
            "principio, ahora y siempre, por los siglos de los siglos. Amén.\n"
            "Resucité, y aún estoy contigo, aleluya: pusiste sobre mí tu "
            "mano, aleluya: tu sabiduría se ha mostrado admirable, aleluya, "
            "aleluya."),
        "oratio": (
            "Oh Dios, que en este día, vencida la muerte, nos abriste por tu "
            "Unigénito las puertas de la eternidad: acompaña con tu ayuda "
            "los deseos que tú mismo nos inspiras y previenes con tu "
            "gracia.\n"
            "Por el mismo Jesucristo nuestro Señor, tu Hijo, que vive y "
            "reina contigo en la unidad del Espíritu Santo, Dios, por todos "
            "los siglos de los siglos. Amén."),
        "graduale": (
            "Éste es el día que hizo el Señor: regocijémonos y alegrémonos "
            "en él.\n"
            "V. Alabad al Señor, porque es bueno: porque es eterna su "
            "misericordia. Aleluya, aleluya.\n"
            "V. Cristo, nuestra Pascua, ha sido inmolado."),
        "offertorium": (
            "Tembló la tierra y quedó en calma, cuando se levantó Dios para "
            "el juicio, aleluya."),
        "secreta": (
            "Recibe, Señor, te suplicamos, las preces de tu pueblo junto con "
            "la oblación de estas hostias: para que, estrenadas en los "
            "misterios pascuales, nos aprovechen, por tu obra, como remedio "
            "de eternidad.\n" + PER_DOMINUM_ES),
        "communio": (
            "Cristo, nuestra Pascua, ha sido inmolado, aleluya: celebremos, "
            "pues, el banquete con los ázimos de la sinceridad y de la "
            "verdad, aleluya, aleluya, aleluya."),
        "postcommunio": (
            "Infúndenos, Señor, el Espíritu de tu caridad: para que, "
            "saciados con los sacramentos pascuales, vivamos concordes por "
            "tu piedad.\n"
            "Por nuestro Señor Jesucristo, tu Hijo, que vive y reina contigo "
            "en la unidad del mismo Espíritu Santo, Dios, por todos los "
            "siglos de los siglos. Amén."),
    },
}

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
            if CONCLUSIONS and macro in CONCLUSIONS:
                lines_out.append(CONCLUSIONS[macro] + " Amén.")
                continue
            # "$Per Dominum" style may appear with trailing text variants
            base = macro.rstrip(".")
            if CONCLUSIONS and base in CONCLUSIONS:
                lines_out.append(CONCLUSIONS[base] + " Amén.")
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
    keys = sorted(k for k in tempora if TRANCHE.match(k))

    out, skipped = {}, []
    for key in keys:
        rel = "Tempora/" + key[0].upper() + key[1:]
        sections = load_formulary(rel)
        if sections is None:
            skipped.append((key, "no Spanish file"))
            continue
        entry = {}
        for field, section in FIELDS.items():
            if tempora[key].get(field) is None:
                continue                 # English side has no such field
            if section not in sections or not sections[section].strip():
                continue
            rendered = render_section(section, sections[section])
            if rendered:
                entry[field] = rendered
        for field, text in SUPPLEMENTS.get(key, {}).items():
            entry.setdefault(field, text)
        missing = [f for f in REQUIRED
                   if tempora[key].get(f) is not None and f not in entry]
        if missing:
            skipped.append((key, f"gate: missing {','.join(missing)}"))
            continue
        if not entry:
            # A feria with no proper fields of its own inherits the Sunday's
            # formulary at render time — nothing to overlay.
            continue
        out[key] = entry

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
        assert key in tempora, key
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
