#!/usr/bin/env python3
"""Order-of-Mass ordinary data repairs (final-QA pass).

a) Split the blessing out of the `placeat` section into its own `benedictio`
   section, so Requiem Masses can keep the Placeat while omitting the
   blessing (the walk now references both slugs separately).
b) Complete the five proper Communicantes variants: the stored texts ended
   mid-sentence at "…Jesu Christi:" although the renderer substitutes the
   ENTIRE canon line, which silently deleted "sed et beatórum Apostolórum …
   Amen." on Christmas, Epiphany, Easter, Ascension and Pentecost.
c) Christmas/Epiphany Communicantes: "Genetrícis ejúsdem Dei" (the day-clause
   names the Savior / the Only-begotten, so the Missal reads "Mother of the
   SAME God"); English gains "the same" to match.
d) Orthography: Genitrícis -> Genetrícis in all variants (Missale spelling,
   matching the canon body).
e) Canon body: "Commúnicántes" (doubly-accented) -> "Communicántes".
f) Sacred Heart preface: "pater et salútis refúgium" -> "páteret salútis
   refúgium" (pateret, from patere — "a refuge of salvation might lie open";
   the English already translates the verb).
g) Easter preface: "in hoc potíssimum die" -> "in hac potíssimum die"
   (Missale text for the day form; dies is feminine here). Also align the
   English to the Latin ("verus est Agnus" = "the true Lamb") and to house
   style (Thee/Thy).
h) ite-alleluia rubric: the doubled-Alleluia dismissal belongs to the Easter
   Octave only, not Pentecost.
i) confiteor-communion: add the Ecce Agnus Dei and the people's threefold
   Dómine, non sum dignus; retitle the section Commúnio Fidélium since it
   now carries the whole communion-of-the-faithful dialogue.

Idempotent; writes byte-identical JSON to both asset directories.
"""

import copy
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ASSET_DIRS = [
    ROOT / "Introibo" / "Resources",
    ROOT / "android" / "app" / "src" / "main" / "assets",
]


def load(name):
    with open(ASSET_DIRS[0] / name, encoding="utf-8") as f:
        return json.load(f)


def save(name, data):
    text = json.dumps(data, ensure_ascii=False, indent=2) + "\n"
    for d in ASSET_DIRS:
        (d / name).write_text(text, encoding="utf-8")


def fix_missal(missal):
    by = {s["slug"]: s for s in missal}
    changed = []

    # (a) placeat -> placeat + benedictio
    if "benedictio" not in by:
        placeat = by["placeat"]
        bless_idx = [i for i, ln in enumerate(placeat["body"])
                     if (ln.get("lat") or "").startswith("℣. Benedícat")]
        assert len(bless_idx) == 1, "expected one blessing line inside placeat"
        bless = placeat["body"].pop(bless_idx[0])
        benedictio = {
            "slug": "benedictio",
            "label": "Conclúsio",
            "title": "Benedíctio",
            "english": "The Blessing",
            "body": [bless],
        }
        missal.insert(missal.index(placeat) + 1, benedictio)
        by["benedictio"] = benedictio
        changed.append("a: benedictio split out of placeat")

    # (e) canon orthography
    canon = by["canon"]
    for ln in canon["body"]:
        if ln["lat"].startswith("Commúnicántes"):
            ln["lat"] = ln["lat"].replace("Commúnicántes", "Communicántes", 1)
            changed.append("e: canon Communicántes accent")

    # (f) Sacred Heart preface
    sh = by["preface-sacred-heart"]
    for ln in sh["body"]:
        if "pater et salútis refúgium" in ln["lat"]:
            ln["lat"] = ln["lat"].replace(
                "pœniténtibus pater et salútis refúgium",
                "pœniténtibus páteret salútis refúgium")
            changed.append("f: sacred-heart pateret")

    # (g) Easter preface
    pe = by["preface-easter"]
    for ln in pe["body"]:
        if "in hoc potíssimum die" in ln["lat"]:
            ln["lat"] = ln["lat"].replace("in hoc potíssimum die",
                                          "in hac potíssimum die")
            changed.append("g: easter preface in hac die")
        if "to praise You, O Lord" in ln["eng"]:
            ln["eng"] = (ln["eng"]
                         .replace("to praise You, O Lord", "to praise Thee, O Lord")
                         .replace("the hymn of Your glory", "the hymn of Thy glory")
                         .replace("For He is the Lamb of God, that taketh away the sins of the world.",
                                  "For He is the true Lamb, Who hath taken away the sins of the world."))
            changed.append("g: easter preface english alignment")

    # (h) ite-alleluia rubric scope
    ia = by["ite-alleluia"]
    first = ia["body"][0]
    if first.get("rubric") and "Pentecost" in first["rubric"]:
        first["rubric"] = ("During the Easter Octave, the dismissal "
                           "adds a double Alleluia:")
        changed.append("h: ite-alleluia rubric Easter-only")

    # (i) communion of the faithful
    cc = by["confiteor-communion"]
    if not any("Ecce Agnus Dei" in (ln.get("lat") or "") for ln in cc["body"]):
        cc["body"].append({
            "rubric": "The priest, holding a Host above the ciborium, turns to the people and says:",
            "lat": "℣. Ecce Agnus Dei, ecce qui tollit peccáta mundi.",
            "eng": "℣. Behold the Lamb of God, behold Him Who taketh away the sins of the world.",
        })
        cc["body"].append({
            "rubric": "The people respond three times, striking their breast:",
            "lat": "℟. Dómine, non sum dignus, ut intres sub tectum meum: sed tantum dic verbo, et sanábitur ánima mea.",
            "eng": "℟. Lord, I am not worthy that Thou shouldst enter under my roof; say but the word, and my soul shall be healed.",
        })
        cc["title"] = "Commúnio Fidélium"
        cc["english"] = "Communion of the Faithful"
        changed.append("i: Ecce Agnus Dei + people's Domine non sum dignus")

    return changed


def fix_variants(variants, missal):
    by = {s["slug"]: s for s in missal}
    canon_line = next(ln for ln in by["canon"]["body"]
                      if ln["lat"].startswith(("Communicántes", "Commúnicántes")))
    lat_cont = canon_line["lat"].split("Jesu Christi:", 1)[1]
    eng_cont = canon_line["eng"].split("Jesus Christ:", 1)[1]
    assert lat_cont.lstrip().startswith("sed et beatórum Apostolórum"), lat_cont[:60]
    assert eng_cont.lstrip().startswith("and also of the blessed Apostles"), eng_cont[:60]

    changed = []
    comm = variants["communicantes"]

    for key, v in comm.items():
        # (d) orthography first
        if "Genitrícis" in v["lat"]:
            v["lat"] = v["lat"].replace("Genitrícis", "Genetrícis")
            changed.append(f"d: {key} Genetrícis")
        # (c) "the same God" on Christmas and Epiphany
        if key in ("christmas", "epiphany") and "Genetrícis ejúsdem Dei" not in v["lat"]:
            v["lat"] = v["lat"].replace("Genetrícis Dei et Dómini nostri Jesu Christi",
                                        "Genetrícis ejúsdem Dei et Dómini nostri Jesu Christi")
            v["eng"] = v["eng"].replace("Mother of God and our Lord Jesus Christ",
                                        "Mother of the same God and our Lord Jesus Christ")
            changed.append(f"c: {key} ejúsdem Dei")
        # (b) append the canon continuation
        if "beatórum Apostolórum" not in v["lat"]:
            assert v["lat"].rstrip().endswith("Jesu Christi:"), (key, v["lat"][-40:])
            assert v["eng"].rstrip().endswith("Jesus Christ:"), (key, v["eng"][-40:])
            v["lat"] = v["lat"].rstrip() + lat_cont
            v["eng"] = v["eng"].rstrip() + eng_cont
            changed.append(f"b: {key} continuation")

    return changed


def qa(missal, variants):
    by = {s["slug"]: s for s in missal}

    # (a)
    assert "benedictio" in by
    assert len(by["benedictio"]["body"]) == 1
    assert by["benedictio"]["body"][0]["lat"].startswith("℣. Benedícat vos omnípotens Deus")
    assert len(by["placeat"]["body"]) == 1
    assert by["placeat"]["body"][0]["lat"].startswith("Pláceat tibi")
    # section order: placeat immediately followed by benedictio
    slugs = [s["slug"] for s in missal]
    assert slugs.index("benedictio") == slugs.index("placeat") + 1

    # (e)
    canon_line = next(ln for ln in by["canon"]["body"]
                      if ln["lat"].startswith("Communicántes"))
    assert "Commúnicántes" not in canon_line["lat"]

    # (b)(c)(d)
    comm = variants["communicantes"]
    assert set(comm) == {"christmas", "epiphany", "easter", "ascension", "pentecost"}
    for key, v in comm.items():
        assert "Genitrícis" not in v["lat"], key
        assert "beatórum Apostolórum ac Mártyrum tuórum, Petri et Pauli" in v["lat"], key
        assert v["lat"].rstrip().endswith("Per eúndem Christum, Dóminum nostrum. Amen."), key
        assert "and also of the blessed Apostles and Martyrs, Peter and Paul" in v["eng"], key
        assert v["eng"].rstrip().endswith("Through the same Christ our Lord. Amen."), key
        # exactly one insertion point for the 1962 Joseph clause
        assert v["lat"].count("Jesu Christi: sed et") == 1, key
        assert v["eng"].count(": and also of the blessed Apostles") == 1, key
    for key in ("christmas", "epiphany", "easter", "ascension"):
        assert "Genetrícis ejúsdem Dei" in comm[key]["lat"], key
        assert "Mother of the same God" in comm[key]["eng"], key
    assert "Genetrícis ejúsdem" not in comm["pentecost"]["lat"]

    # (f)
    assert any("páteret salútis refúgium" in ln["lat"]
               for ln in by["preface-sacred-heart"]["body"])
    # (g)
    assert any("in hac potíssimum die" in ln["lat"]
               for ln in by["preface-easter"]["body"])
    assert not any("You" in ln["eng"] or "Your" in ln["eng"]
                   for ln in by["preface-easter"]["body"])
    # (h)
    rub = by["ite-alleluia"]["body"][0]["rubric"]
    assert "Easter" in rub and "Pentecost" not in rub
    # (i)
    cc = by["confiteor-communion"]
    assert any("Ecce Agnus Dei" in ln["lat"] for ln in cc["body"])
    assert any(ln["lat"].startswith("℟. Dómine, non sum dignus") for ln in cc["body"])
    assert cc["title"] == "Commúnio Fidélium"

    # both asset dirs byte-identical
    for name in ("missal.json", "canon_variants.json"):
        a = (ASSET_DIRS[0] / name).read_bytes()
        b = (ASSET_DIRS[1] / name).read_bytes()
        assert a == b, name


def main():
    missal = load("missal.json")
    variants = load("canon_variants.json")

    changed = fix_missal(missal)
    changed += fix_variants(variants, missal)

    save("missal.json", missal)
    save("canon_variants.json", variants)

    qa(load("missal.json"), load("canon_variants.json"))

    if changed:
        print(f"{len(changed)} changes:")
        for c in changed:
            print("  -", c)
    else:
        print("no changes needed (already applied)")
    print("QA OK")


if __name__ == "__main__":
    main()
