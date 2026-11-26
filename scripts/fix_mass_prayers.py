#!/usr/bin/env python3
"""Put the saints' Mass collects, secrets and postcommunions right, from
Divinum Officium's own rendering of them.

The sanctoral Missal (missal_sanctoral.json) was imported with three faults
in its orations, found by comparing every one with what DO shows for the
1962 Missal (dodump.pl ... missaprayers, which follows missa/propers.pl:
the feast's text or its Common's, "N." filled from [Name] with the
per-prayer forms "Secreta=…", and the Common of Supreme Pontiffs):

- the saint's name put in the Common's "N." in the wrong case
  ("intercedénte beáto Anacléti Mártyre", "per beátum Hygíni"), or not at
  all ("Sancti N. Pontíficis");
- the secret and postcommunion taken from the wrong Mass of the Common
  (a martyr-bishop's "Statuit" given the "Laetabitur" prayers, a virgin
  given the virgin-martyrs' plural ones);
- a second collect appended where nothing is commemorated (the papal
  "Deus, qui Ecclésiam tuam … in apostólicæ petræ", or the same collect
  again from another Common).

For each prayer that differs, the Latin and English are replaced with DO's
(the conclusion written out as the app writes it elsewhere), a trailing
prayer is kept only where it is a true commemoration (KEEP_TAIL), and the
few names DO itself leaves in the wrong case are corrected (NAME_CASE).
The vernacular overlays are rebuilt afterwards by their own importers.

Run:
  DO_LANG2=English perl scripts/office_qa/dodump.pl "Rubrics 1960 - 1960" missaprayers > /tmp/doen/missaprayers_1962.json
  DO_LANG2=English perl scripts/office_qa/dodump.pl "Rubrics 1960 - 1960" missa > /tmp/doen/missa_1962.json
  python3 scripts/fix_mass_prayers.py --do-en /tmp/doen [--dry-run]
"""
import json
import re
import sys
import unicodedata
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
FILES = [ROOT / "android/app/src/main/assets/missal_sanctoral.json",
         ROOT / "Introibo/Resources/missal_sanctoral.json"]
OFFICE = [ROOT / "android/app/src/main/assets/sanctoral_propers.json",
          ROOT / "Introibo/Resources/sanctoral_propers.json"]
TYPES = {"oratio": "Oratio", "secreta": "Secreta", "postcommunio": "Postcommunio"}

CONC = re.compile(r"^(Per (Dóminum|Dominum|eúndem|eumdem|eundem)|Qui (vivis|tecum|cum)|"
                  r"Through|Who (livest|liveth|with)|Amen\.?$)", re.I)

# Prayers after the first that are a real commemoration, not a leftover.
KEEP_TAIL = {("01-25", "secreta"), ("02-22", "secreta"), ("06-13", "secreta"),
             ("07-23cc", "secreta"), ("07-23cc", "postcommunio")}

# Names DO's [Name] gives in one case where the prayer needs another
# (Latin as DO renders it -> as it must read).
NAME_CASE = {
    "sanctus Antónii Abbas": "sanctus Antónius Abbas",
    "beátus Antónii Abbas": "beátus Antónius Abbas",
    "sanctus Benedícti Abbas": "sanctus Benedíctus Abbas",
    "beátæ Margaríta Vírginis": "beátæ Margarítæ Vírginis",
    "beáti Sabbas Abbátis": "beáti Sabbæ Abbátis",
    "per beátum Anacléti Mártyrem": "per beátum Anaclétum Mártyrem",
    "sanctus Hilariónis Abbas": "sanctus Hilárion Abbas",
    "beátus Hilariónis Abbas": "beátus Hilárion Abbas",
    # DO's typing slips in St Peter Claver's postcommunion
    "Creseat in nobis": "Crescat in nobis", "tuæ pietátis efFéctus": "tuæ pietátis efféctus",
}


# Prayers whose "N." DO leaves unfilled (no [Name] in its file) or fills in
# the wrong case: (key, field) -> [(Latin old, new), …], [(English old, new), …].
FILL = {
    ("03-23n", "postcommunio"): ([("beáto N. Confessóre", "beáto Toríbio Confessóre")],
                                 [("blessed N., Your", "blessed Turibius, Your")]),
    ("05-05", "postcommunio"): ([("beáto N. Confessóre", "beáto Pio Confessóre")],
                                [("blessed N., Your", "blessed Pius, Your")]),
    ("05-16n", "postcommunio"): ([("beáto N. Mártyre", "beáto Joánne Mártyre")],
                                 [("blessed N., Your", "blessed John, Your")]),
    ("05-23", "oratio"): ([("beáti N. Confessóris", "beáti Joánnis Baptístæ Confessóris")],
                          [("blessed N., Your", "blessed John Baptist, Your")]),
    ("07-23cc", "secreta"): ([("Sancti N. Confessóris", "Sancti Libórii Confessóris")], []),
    ("07-23cc", "postcommunio"): ([("beáto N. Confessóre", "beáto Libório Confessóre"),
                                   ("beáti N. Confessóris", "beáti Libórii Confessóris")],
                                  [("blessed N., Your", "blessed Liborius, Your")]),
    ("07-24", "secreta"): ([("beáti N. Apóstoli", "beáti Jacóbi Apóstoli")],
                           [("blessed N., thy", "blessed James, thy")]),
    ("07-24", "postcommunio"): ([("Apóstoli tui N.,", "Apóstoli tui Jacóbi,")],
                                [("Apostle, N.,", "Apostle, James,")]),
    ("08-02n", "postcommunio"): ([("beáto N. Confessóre", "beáto Eusébio Confessóre")],
                                 [("blessed N., Your", "blessed Eusebius, Your")]),
    ("10-07t", "oratio"): ([("per beátum N. Summum", "per beátum Marcum Summum")],
                           [("blessed N. thy", "blessed Mark thy")]),
    ("12-20o", "secreta"): ([("beáti N. Apóstoli", "beáti Thomæ Apóstoli")],
                            [("blessed N., thy", "blessed Thomas, thy")]),
    ("12-20o", "postcommunio"): ([("Apóstoli tui N.,", "Apóstoli tui Thomæ,")],
                                 [("Apostle, N.,", "Apostle, Thomas,")]),
    ("02-03", "secreta"): ([("beáto Blásii Mártyre", "beáto Blásio Mártyre")], []),
    ("12-16", "secreta"): ([("beáto Eusébii", "beáto Eusébio")], []),
    ("12-16", "postcommunio"): ([("beáto Eusébii", "beáto Eusébio")], []),
}

# St Praxedes's Gradual (07-21) had been overwritten with three Collects
# of the Commons; this is DO's (missa Sancti/07-21 -> Commune/C7).
GRADUALE_0721 = {
    "lat": "Dilexísti justítiam, et odísti iniquitátem.\n"
           "V. Proptérea unxit te Deus, Deus tuus, óleo lætítiæ. Allelúja, allelúja.\n"
           "V. Spécie tua et pulchritúdine tua inténde, próspere procéde et regna. Allelúja.",
    "eng": "You love justice and hate wickedness.\n"
           "V. Therefore God, your God, has anointed you with the oil of gladness. Alleluia, alleluia.\n"
           "V. In your splendor and your beauty ride on triumphant, and reign. Alleluia.",
    "ref": "Ps 44:8; 44:5",
}


def nfc(s):
    return unicodedata.normalize("NFC", s or "")


def fold(t):
    t = unicodedata.normalize("NFD", nfc(t))
    t = "".join(c for c in t if unicodedata.category(c) != "Mn").lower()
    t = t.replace("æ", "ae").replace("œ", "ae").replace("oe", "ae").replace("j", "i").replace("v", "u")
    t = re.sub(r"ci(?=[aeiou])", "ti", t)
    return re.sub(r"\s+", " ", re.sub(r"[^a-z0-9 ]+", " ", t)).strip()


def fix_lat(key, f, t):
    """The hand corrections of a Latin line (NAME_CASE, FILL, DO's typo)."""
    for wrong, right in NAME_CASE.items():
        t = t.replace(wrong, right)
    for old, new in FILL.get((key, f), ([], []))[0]:
        t = t.replace(old, new)
    return re.sub(r"Dómine, qu(?:æ|ae); sumus:", "Dómine, quǽsumus:", t)


def split(text):
    """(prayer lines, the conclusion macro or None) of a DO rendering."""
    lines, macro = [], None
    for l in nfc(text).split("\n"):
        l = l.strip()
        if not l:
            continue
        if l.startswith("$"):
            macro = macro or l[1:].rstrip(".").strip()
            continue
        if l.startswith(("&", "!")):
            continue
        lines.append(re.sub(r"^v\.\s*", "", l))
    return lines, macro


def app_parts(text):
    """(first prayer lines, conclusion lines, the rest) of an app field."""
    ls = [l for l in nfc(text).split("\n") if l.strip()]
    i = 1
    while i < len(ls) and CONC.match(ls[i]):
        i += 1
    return ls[:1], ls[1:i], ls[i:]


def main():
    do_en = Path(sys.argv[sys.argv.index("--do-en") + 1])
    render = json.load(open(do_en / "missaprayers_1962.json", encoding="utf-8"))
    data = [json.load(open(p, encoding="utf-8")) for p in FILES]
    app = data[0]

    # The app's own conclusion for each DO macro, read off the prayers that
    # already agree with DO.
    conc = defaultdict(Counter)
    for key, e in app.items():
        d = render.get(f"Sancti/{key}.txt", {})
        for f, D in TYPES.items():
            v = e.get(f)
            if not isinstance(v, dict) or D not in d or not d[D].get("lat"):
                continue
            lines, macro = split(d[D]["lat"])
            a, c, _ = app_parts(v.get("lat", ""))
            _, ce, _ = app_parts(v.get("eng", ""))
            if macro and a and lines and fold(a[0]) == fold(lines[0]) and c and ce:
                conc[macro][(c[0], ce[0])] += 1
    conclusion = {m: c.most_common(1)[0][0] for m, c in conc.items()}

    changed, kept_tail, dropped_tail, skipped, multi = [], 0, [], [], []
    for key, e in app.items():
        d = render.get(f"Sancti/{key}.txt", {})
        for f, D in TYPES.items():
            v = e.get(f)
            if not isinstance(v, dict) or not v.get("lat"):
                continue
            a, c, rest = app_parts(v["lat"])
            ae, ce, reste = app_parts(v.get("eng", ""))
            tail_ok = (key, f) in KEEP_TAIL or (rest and rest[0].startswith("Orémus"))
            if tail_ok and rest and len(reste) != len(rest):
                skipped.append((key, f, "the English does not carry the Latin's commemoration"))
                continue
            new_rest, new_reste = (rest, reste) if tail_ok else ([], [])
            if rest and not tail_ok:
                dropped_tail.append((key, f, rest[0][:70]))
            if D not in d or not d[D].get("lat"):
                if rest and not tail_ok:
                    v["lat"] = "\n".join(a + c)
                    v["eng"] = "\n".join(ae + ce)
                continue
            lines, macro = split(d[D]["lat"])
            elines, _ = split(d[D].get("eng") or "")
            if len(lines) != 1:
                # DO's text carries its own commemoration (the Chair of
                # Peter's of St Paul ...): the app's is left as it stands
                multi.append((key, f))
                if rest and not tail_ok:
                    v["lat"] = "\n".join(a + c)
                    v["eng"] = "\n".join(ae + ce)
                continue
            lines = [fix_lat(key, f, l) for l in lines]
            same = [fold(x) for x in a] == [fold(x) for x in lines]
            if same and not (rest and not tail_ok):
                continue
            if not same:
                if not elines or len(elines) != len(lines):
                    skipped.append((key, f, "no English from DO"))
                    if rest and not tail_ok:
                        v["lat"] = "\n".join(a + c)
                        v["eng"] = "\n".join(ae + ce)
                    continue
                if macro and macro in conclusion:
                    c, ce = [conclusion[macro][0]], [conclusion[macro][1]]
                elif macro:
                    skipped.append((key, f, f"conclusion {macro}"))
                    continue
                else:
                    c, ce = [], []
                a, ae = lines, elines
                changed.append((key, f, lines[0][:90]))
            v["lat"] = "\n".join(a + c + new_rest)
            v["eng"] = "\n".join(ae + ce + new_reste)

    for (key, f), (lat, eng) in FILL.items():
        v = app[key][f]
        for old, new in lat:
            v["lat"] = v["lat"].replace(old, new)
        for old, new in eng:
            v["eng"] = v["eng"].replace(old, new)
    if app["07-21"]["graduale"]["lat"].startswith("Commune non Virginum"):
        app["07-21"]["graduale"] = GRADUALE_0721
    # the same slips wherever they stand (a prayer skipped above included)
    for e in app.values():
        for f in TYPES:
            v = e.get(f)
            if isinstance(v, dict) and v.get("lat"):
                for wrong, right in NAME_CASE.items():
                    v["lat"] = v["lat"].replace(wrong, right)
                # DO's "Dómine, quæ; sumus:" for "quǽsumus"
                v["lat"] = re.sub(r"Dómine, qu(?:æ|ae); sumus:", "Dómine, quǽsumus:", v["lat"])
    print(f"left {len(multi)} prayers whose DO text carries a commemoration")
    print(f"replaced {len(changed)} prayers; dropped {len(dropped_tail)} leftover trailing prayers; skipped {len(skipped)}")
    if "--verbose" in sys.argv:
        for x in changed:
            print("  replaced", *x, sep=" | ")
        for x in dropped_tail:
            print("  dropped", *x, sep=" | ")
    for x in skipped:
        print("  skipped", *x, sep=" | ")
    # The Office's collect for the popes had the same faults: the name in
    # the genitive after "per beátum", and the commemoration-only "Deus,
    # qui Ecclésiam tuam … in apostólicæ petræ" (and the plural "Gregem")
    # appended. It takes the Mass's corrected "Gregem tuum" alone.
    office = json.load(open(OFFICE[0], encoding="utf-8"))
    office_fixed = []
    for key, e in office.items():
        v = e.get("oratio")
        if not isinstance(v, dict) or not v.get("lat"):
            continue
        ls, le = v["lat"].split("\n"), v.get("eng", "").split("\n")
        if not (len(ls) > 1 and ls[0].startswith("Gregem tuum") and ls[1].startswith("Deus, qui Ecclésiam tuam, in apostólicæ")):
            continue
        m = app.get(key, {}).get("oratio", {})
        first = (m.get("lat") or "").split("\n")[0]
        if not first.startswith("Gregem tuum"):
            skipped.append((key, "office oratio", "no corrected Mass collect"))
            continue
        v["lat"], v["eng"] = first, le[0]
        office_fixed.append(key)
    print(f"office: {len(office_fixed)} popes' collects put right")
    if "--dry-run" in sys.argv:
        return
    otext = json.dumps(office, ensure_ascii=False, indent=2) + "\n"
    for p in OFFICE:
        p.write_text(otext, encoding="utf-8")
    text = json.dumps(app, ensure_ascii=False, indent=2).replace("sæcul\ufffd\ufffdrum", "sæculórum")
    for p in FILES:
        p.write_text(text, encoding="utf-8")


if __name__ == "__main__":
    main()
