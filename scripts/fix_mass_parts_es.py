#!/usr/bin/env python3
"""The Spanish of the Mass parts that fix_mass_parts.py put right, from the
app's own Spanish.

- Readings (Lectio, Evangelium; missal_readings_es.json, Torres Amat): a
  corrected reading takes the Spanish of another Mass whose Latin reading
  is the same (the Commons' readings recur), so the Torres Amat text is
  never retyped.
- Chants (Introit, Gradual and its Paschal and Lenten forms, Offertory,
  Communion, Sequence; missal_propers_es.json): line by line, from the
  Spanish the Missal already gives the same Latin line, the Paschal
  alleluias taken off and put back in Spanish ("(Allelúja, allelúja.)" ->
  "(Aleluya, aleluya.)", "… Allelúja." -> "… Aleluya.").

A part whose Spanish cannot be found entire loses its Spanish (it shows
the English) and is listed: a translation of the old, wrong text is never
left beside the corrected Latin.

Run after fix_mass_parts.py:
  python3 scripts/fix_mass_parts_es.py --before-sanctoral <old> --before-tempora <old> [--dry-run]
  python3 scripts/sync_spanish_assets.py
"""
import json
import re
import sys
import unicodedata
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / "android/app/src/main/assets"
PROPERS = ROOT / "spanish-translation/missal_propers_es.json"
READINGS = ROOT / "spanish-translation/missal_readings_es.json"
CHANTS = ("introitus", "graduale", "gradualeP", "tractus", "offertorium", "communio", "sequentia")
READS = ("lectio", "evangelium")
DO_NAME = {"introitus": "Introitus", "graduale": "Graduale", "gradualeP": "GradualeP", "tractus": "Tractus",
           "offertorium": "Offertorium", "communio": "Communio", "sequentia": "Sequentia"}
GLORIA_ES = ("Gloria al Padre, y al Hijo, y al Espíritu Santo. Como era en el principio, ahora y siempre, "
             "por los siglos de los siglos. Amén.")

# Chants no Spanish source has: hand translations from the Latin, in the
# Missal's own wording. (key, part) -> Spanish.
FIELD_HAND = {
    "04-14/tractus": "No me he preciado de saber otra cosa entre vosotros, sino a Jesucristo, y este crucificado.\n"
                     "V. Predicamos la sabiduría de Dios en el misterio, la cual estaba encubierta, la cual predestinó Dios antes de los siglos para gloria nuestra.\n"
                     "V. Sabiduría que ninguno de los príncipes de este siglo ha conocido; porque si la hubiesen conocido, nunca habrían crucificado al Señor de la gloria.",
    "09-09n/introitus": "Sació el Señor al alma hambrienta: a los que yacían en tinieblas y sombra de muerte, aprisionados en la miseria y en los hierros.\n"
                        "V. Alaben al Señor por sus misericordias, y por sus maravillas en favor de los hijos de los hombres.\n"
                        + GLORIA_ES + "\n"
                        "Sació el Señor al alma hambrienta: a los que yacían en tinieblas y sombra de muerte, aprisionados en la miseria y en los hierros.",
    "12-07/communio": "Una vez juré por mi santidad: su descendencia permanecerá eternamente, y su trono será como el sol en mi presencia, "
                      "y como la luna llena para siempre, testigo fiel en el cielo. (Aleluya.)",
    "12-06/communio": "Una vez juré por mi santidad: su descendencia permanecerá eternamente, y su trono será como el sol en mi presencia, "
                      "y como la luna llena para siempre, testigo fiel en el cielo. (Aleluya.)",
    "03-24/gradualeP": "Aleluya, aleluya.\n"
                       "V. El que hace a sus Ángeles espíritus, y a sus ministros llama de fuego.\n"
                       "V. Dios te salve, María, llena de gracia; el Señor es contigo: bendita tú entre las mujeres. Aleluya.",
    "05-31/gradualeP": "Aleluya, aleluya.\n"
                       "V. Bienaventurada eres, Virgen María, que permaneciste al pie de la Cruz del Señor. Aleluya.\n"
                       "V. Ahora reinas con Él para siempre. Aleluya.",
    "06-05/gradualeP": "Aleluya.\n"
                       "Alegraos con Jerusalén, y regocijaos en ella todos los que amáis al Señor. Aleluya.\n"
                       "V. Lo veréis, y se alegrará vuestro corazón: y se dará a conocer la mano del Señor a favor de sus siervos. Aleluya.",
    "06-15/offertorium": "Admirable es Dios en sus Santos: el Dios de Israel, Él dará virtud y fortaleza a su pueblo: bendito sea Dios, aleluya.",
    "pent23-0tt/graduale": "Nos libraste, Señor, de los que nos afligían, y confundiste a los que nos aborrecían.\n"
                           "V. En Dios nos gloriaremos todo el día, y alabaremos tu nombre por los siglos. Aleluya, aleluya.\n"
                           "Desde lo profundo clamé a ti, Señor: Señor, oye mi oración. Aleluya.",
}

TITLE = re.compile(r"^(L[eé]ctio|Sequ[eé]ntia|In[ií]tium|Oratio Jerem|Lamentatio)\b")


def nfc(s):
    return unicodedata.normalize("NFC", s or "")


def fold(t):
    t = unicodedata.normalize("NFD", nfc(t))
    t = "".join(c for c in t if unicodedata.category(c) != "Mn").lower()
    t = t.replace("æ", "ae").replace("œ", "ae").replace("oe", "ae").replace("j", "i").replace("v", "u")
    t = re.sub(r"ci(?=[aeiou])", "ti", t)
    return re.sub(r"\s+", " ", re.sub(r"[^a-z0-9 ]+", " ", t)).strip()


def lines(t):
    return [l.strip() for l in nfc(t).split("\n") if l.strip()]


def body(t):
    """A reading's words without its title line."""
    ls = lines(t)
    if ls and TITLE.match(ls[0]):
        ls = ls[1:]
    return fold(" ".join(ls))


BRACKET = re.compile(r"\s*\((All[eé]l[uú][ij]a[^()]*)\)\s*$", re.I)
TAIL = re.compile(r"(?:[,.;:]?\s*All[eé]l[uú][ij]a[.,]?)+\s*$", re.I)
ONLY_ALLELUIA = re.compile(r"(?:All[eé]l[uú][ij]a[,.]?\s*)+", re.I)


def strip_alleluia(l):
    """(the line without its closing alleluias, the Spanish to put back)."""
    m = BRACKET.search(l)
    if m:
        n = len(re.findall(r"All[eé]l", m.group(1), re.I))
        return l[:m.start()].rstrip(), " (" + ", ".join(["Aleluya"] + ["aleluya"] * (n - 1)) + ".)"
    m = TAIL.search(l)
    if m and m.start() > 0:
        n = len(re.findall(r"All[eé]l", m.group(0), re.I))
        return l[:m.start()].rstrip(), None, n
    return l, ""


def main():
    before = {"missal_sanctoral.json": json.load(open(sys.argv[sys.argv.index("--before-sanctoral") + 1])),
              "missal_tempora.json": json.load(open(sys.argv[sys.argv.index("--before-tempora") + 1]))}
    now = {n: json.load(open(ASSETS / n, encoding="utf-8")) for n in before}
    ptext, rtext = PROPERS.read_text(encoding="utf-8"), READINGS.read_text(encoding="utf-8")
    props, reads = json.loads(ptext), json.loads(rtext)

    def changed(n, k, f):
        a = (now[n].get(k, {}).get(f) or {})
        b = (before[n].get(k, {}).get(f) or {})
        return isinstance(a, dict) and a.get("lat") and a.get("lat") != b.get("lat")

    do_es = json.load(open(sys.argv[sys.argv.index("--do-es") + 1], encoding="utf-8")) if "--do-es" in sys.argv else {}
    todo = [(n, k, f) for n in now for k in now[n] for f in CHANTS + READS if changed(n, k, f)]
    todo_set = set(todo)

    # Spanish readings by their Latin, from the readings left as they were
    # (the Spanish of a part translates the Latin it was made for, so the
    # parts as they were before the correction are pairs too)
    by_reading = {}
    for n in now:
        for src in (now[n], before[n]):
            for k, e in src.items():
                for f in READS:
                    v, s = e.get(f), reads.get(k, {}).get(f)
                    if not isinstance(v, dict) or not v.get("lat") or not s:
                        continue
                    if src is now[n] and (n, k, f) in todo_set:
                        continue
                    if src is before[n] and (n, k, f) not in todo_set:
                        continue
                    by_reading.setdefault((f, body(v["lat"])), s)

    # Spanish readings by their reference (the Torres Amat text is composed
    # from it), from the readings left as they were
    by_ref = {}
    for n in now:
        for k, e in now[n].items():
            for f in READS:
                v, s = e.get(f), reads.get(k, {}).get(f)
                if isinstance(v, dict) and v.get("ref") and s and (n, k, f) not in todo_set:
                    by_ref.setdefault((f, re.sub(r"\s+", " ", v["ref"].strip())), s)

    # Spanish chant lines by their Latin (alleluias off on both sides)
    pairs = defaultdict(Counter)
    ES_TAIL = re.compile(r"\s*\((Aleluya[^()]*)\)\s*$|(?:[,.;:]?\s*Aleluya[.,]?)+\s*$", re.I)
    for n in now:
        for src in (now[n], before[n]):
          for k, e in src.items():
            for f in CHANTS:
                v, s = e.get(f), props.get(k, {}).get(f)
                if not isinstance(v, dict) or not v.get("lat") or not s:
                    continue
                if (src is now[n]) == ((n, k, f) in todo_set):
                    continue
                ll, sl = lines(v["lat"]), lines(s)
                if len(ll) != len(sl):
                    continue
                for a, b in zip(ll, sl):
                    a0 = strip_alleluia(re.sub(r"^V\.\s*", "", a))[0]
                    b0 = ES_TAIL.sub("", re.sub(r"^V\.\s*", "", b)).rstrip()
                    if fold(a0) and b0 and "~" not in b0 and not ONLY_ALLELUIA.fullmatch(a0):
                        pairs[fold(a0)][b0] += 1

    # the Office's Spanish of the same antiphon or verse (office_texts_es:
    # Latin text -> Spanish), the mediant asterisks taken out
    for lat_t, es_t in json.load(open(ROOT / "spanish-translation/office_texts_es.json", encoding="utf-8")).items():
        if "\n" in lat_t or not isinstance(es_t, str) or "\n" in es_t:
            continue
        a0 = strip_alleluia(re.sub(r"\s*\*\s*", " ", lat_t))[0]
        b0 = ES_TAIL.sub("", re.sub(r"\s*\*\s*", " ", es_t)).rstrip()
        if len(fold(a0)) > 12 and b0 and fold(a0) not in pairs:
            pairs[fold(a0)][b0] += 1

    def spanish_line(l, own=None):
        if own and fold(re.sub(r"^V\.\s*", "", l)) in own:
            o = own[fold(re.sub(r"^V\.\s*", "", l))]
            if len(re.findall(r"all[eé]l[uú][ij]a", l, re.I)) == len(re.findall(r"aleluya", o, re.I)):
                return o
        v = l.startswith("V.")
        core = re.sub(r"^V\.\s*", "", l)
        if ONLY_ALLELUIA.fullmatch(core):
            n = len(re.findall(r"All[eé]l", core, re.I))
            return ("V. " if v else "") + ", ".join(["Aleluya"] + ["aleluya"] * (n - 1)) + "."
        r = strip_alleluia(core)
        base = r[0]
        c = pairs.get(fold(base))
        if not c:
            return None
        sp = c.most_common(1)[0][0]
        if len(r) == 3:                       # "… Allelúja." -> "… Aleluya."
            sp = sp.rstrip(" .,;:") + ". " + ", ".join(["Aleluya"] + ["aleluya"] * (r[2] - 1)) + "."
        elif r[1]:
            sp = sp + r[1]
        return ("V. " if v else "") + sp

    done, dropped = Counter(), []
    def words(t):
        return fold(" ".join(re.sub(r"^V\.\s*", "", l) for l in lines(t)))

    for n, k, f in todo:
        lat = now[n][k][f]["lat"]
        old = (before[n].get(k, {}).get(f) or {}).get("lat", "")
        have = (reads if f in READS else props).get(k, {}).get(f)
        if have and old and words(old) == words(lat):
            done["unchanged words"] += 1      # only the line breaks moved
            continue
        if f in READS:
            ref = (now[n][k][f].get("ref") or "").strip()
            old_ref = ((before[n].get(k, {}).get(f) or {}).get("ref") or "").strip()
            s = by_reading.get((f, body(lat)))
            if not s and ref and ref == old_ref and reads.get(k, {}).get(f):
                s = reads[k][f]          # the same pericope: Torres Amat by its reference
            if not s and ref:
                s = by_ref.get((f, re.sub(r"\s+", " ", ref)))
            if s:
                reads.setdefault(k, {})[f] = s
                done[f] += 1
            else:
                if f in reads.get(k, {}):
                    del reads[k][f]
                dropped.append((n, k, f, lines(lat)[1 if TITLE.match(lines(lat)[0]) else 0][:90]))
            continue
        if f"{k}/{f}" in FIELD_HAND and len(lines(FIELD_HAND[f"{k}/{f}"])) == len(lines(lat)):
            props.setdefault(k, {})[f] = FIELD_HAND[f"{k}/{f}"]
            done["by hand"] += 1
            continue
        own = {}
        ol, osp = [l for l in lines(old) if not l.startswith("!")], lines(have or "")
        if have and ol and osp:
            # (where the old Latin carried debris after the text, the
            # Spanish of its opening lines still pairs line for line)
            # the field's own Spanish for its unchanged Latin lines
            own = {fold(re.sub(r"^V\.\s*", "", a)): b for a, b in zip(ol, osp)}
        out = [spanish_line(l, own) for l in lines(lat)]
        if None in out and do_es:
            # DO's Spanish of the same part, where its lines match the Latin's
            d = do_es.get(f"{'Sancti' if n == 'missal_sanctoral.json' else 'Tempora'}/{k}.txt", {}).get(DO_NAME[f], {})
            dl = [re.sub(r"^v\.\s*", "", l.strip()) for l in nfc(d.get("eng") or "").split("\n")
                  if l.strip() and not l.strip().startswith(("!", "&", "$", "@", "#", "_"))]
            dlat = [re.sub(r"^v\.\s*", "", l.strip()) for l in nfc(d.get("lat") or "").split("\n")
                    if l.strip() and not l.strip().startswith(("!", "&", "$", "@", "#", "_"))]
            english = re.compile(r"\b(the|of|and|with|who|which|you|your)\b", re.I)
            alls = lambda t: len(re.findall(r"all[eé]l[uú][ij]a|aleluya", t, re.I))
            if dl and len(dl) == len(dlat) == len(out) and not any(len(english.findall(x)) >= 2 for x in dl) \
                    and all(alls(x) == alls(l) for x, l in zip(dl, lines(lat))) and all(fold(re.sub(r"^V\.\s*", "", a)) == fold(re.sub(r"^V\.\s*", "", b)) for a, b in zip(dlat, lines(lat))):
                out = [o or (("V. " if l.startswith("V.") and not x.startswith("V.") else "") + x)
                       for o, l, x in zip(out, lines(lat), dl)]
                done["from DO's Spanish"] += 1
        if None in out:
            if f in props.get(k, {}):
                del props[k][f]
            miss = next(l for l, o in zip(lines(lat), out) if o is None)
            dropped.append((n, k, f, miss[:90]))
        else:
            props.setdefault(k, {})[f] = "\n".join(out)
            done[f] += 1
    # Spanish of a seasonal Gradual the Missal no longer carries
    for n in now:
        for k, e in now[n].items():
            for f in ("gradualeP", "tractus"):
                if f not in e and f in props.get(k, {}):
                    del props[k][f]
    # the Latin spelling of the alleluia left in some Spanish
    fixed_all = 0
    for k, e in props.items():
        for f, t in e.items():
            if isinstance(t, str) and re.search(r"All[eé]l[uú][ij]a", t, re.I):
                e[f] = re.sub(r"All[eé]l[uú][ij]a", "Aleluya", re.sub(r"all[eé]l[uú][ij]a", "aleluya", t))
                fixed_all += 1
    print(f"spanish alleluia spelling: {fixed_all} fields")
    print(f"spanish parts: {sum(done.values())} rebuilt {dict(done)}, {len(dropped)} left to the English {dict(Counter(x[2] for x in dropped))}")
    for x in dropped:
        print("  english", *x, sep=" | ")
    if "--dry-run" in sys.argv:
        return
    for path, data, text in ((PROPERS, props, ptext), (READINGS, reads, rtext)):
        indent = 2 if text.startswith('{\n  "') else 1
        path.write_text(json.dumps(data, ensure_ascii=False, indent=indent) + ("\n" if text.endswith("\n") else ""), encoding="utf-8")


if __name__ == "__main__":
    main()
