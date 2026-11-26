#!/usr/bin/env python3
"""Spanish for the Divinum Officium office assets (office_psalterium,
office_commune, office_propers_<rite>), gathered from the Spanish the app
already carries for the same Latin texts (the hours, the weekly psalter,
the commons, the temporal and sanctoral propers, the seasonal hymns, the
prayers and the Marian antiphons).

Writes spanish-translation/office_texts_es.json: { normalised Latin ->
Spanish }. Both apps apply it to every Latin text of the DO assets (parts'
lat/latR/antiphonLat, antiphon lists' ant/v/r) when the vernacular is
Spanish; a Latin text without an entry keeps its English.

  python3 scripts/build_office_spanish.py [--report]

With --lang fr the same builder writes french-translation/office_texts_fr.json.
French has no overlays of its own to gather from yet, so its only source is
Divinum Officium's French column (--do-es DIR, dumped with DO_LANG2=Francais);
--do-en DIR (the same dumps with the English column) lets it tell DO's French
from the English DO falls back to where it has none.
"""
import json, os, re, sys, unicodedata
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / "android" / "app" / "src" / "main" / "assets"
LANG = sys.argv[sys.argv.index("--lang") + 1] if "--lang" in sys.argv else "es"
ES = ROOT / {"es": "spanish-translation", "fr": "french-translation"}[LANG]
DO_NAME = {"es": "Espanol", "fr": "Francais"}[LANG]
ALLELUIA = {"es": "Aleluya", "fr": "Alléluia"}[LANG]


def norm(t):
    """The key both apps compute: NFC, <br>/~ as spaces, whitespace collapsed."""
    t = unicodedata.normalize("NFC", t or "")
    t = re.sub(r"\{:[^}]*:\}", "", t)  # DO's hymn/section tags
    t = re.sub(r"<br\s*/?>", " ", t)
    t = t.replace("~", " ").replace(" ", " ")
    return re.sub(r"\s+", " ", t).strip()


def load(p):
    return json.load(open(p, encoding="utf-8"))


def vload(name):
    """An overlay of this language (prayers -> prayers_es.json); empty when it has none yet."""
    p = ES / f"{name}_{LANG}.json"
    return load(p) if p.exists() else {}


ENGLISH_WORDS = re.compile(r"\b(the|and|of|thy|thee|thou|unto|who|with|that|his|our|which|shall|hath|lord|is|for)\b", re.I)


MARK_RE = re.compile(r"^(℟\.br\.|℟\.|℣\.|R\.br\.|R\.|V\.|v\.|r\.|Ant\.)\s*")


def fold(t):
    """A fuzzy key for matching the same Latin across editions: no marks,
    accents, punctuation, asterisks or case."""
    t = norm(t)
    t = MARK_RE.sub("", t)
    t = re.sub(r"^\d?\s?[A-Z][a-z]+\.?\s+\d+:\d+(-\d+)?\s*", "", t)  # a scripture reference line
    t = unicodedata.normalize("NFD", t)
    t = "".join(c for c in t if unicodedata.category(c) != "Mn")
    t = t.lower().replace("æ", "ae").replace("œ", "oe").replace("j", "i").replace("v", "u").replace("qu", "c")
    t = t.replace("ii", "i")  # proícias / projícias
    t = re.sub(r"[^a-z0-9 ]+", " ", t)
    return re.sub(r"\s+", " ", t).strip()


ALLELUIA_TAIL = re.compile(r"(?:,?\s*\*?\s*[Aa]llel[úu][ij]a\.?)+\s*$")


def strip_alleluia(t):
    """The text without its Paschal alleluias; (text, count, had_star)."""
    m = ALLELUIA_TAIL.search(t)
    if not m or len(m.group(0)) == len(t.strip()):
        return t, 0, False
    tail = m.group(0)
    n = len(re.findall(r"[Aa]llel", tail))
    return t[:m.start()].rstrip(" ,:;"), n, "*" in tail


def render_line(l):
    """A DO line as the apps show it: the prose markers "v."/"r." dropped,
    "V."/"R." as ℣./℟."""
    l = l.strip()
    l = re.sub(r"^(v\.|r\.)\s*", "", l)
    l = re.sub(r"^R\.br\.\s*", "℟.br. ", l)
    l = re.sub(r"^V\.\s*", "℣. ", l)
    l = re.sub(r"^R\.\s*", "℟. ", l)
    return l


def es_text(t):
    if not isinstance(t, str):
        return None
    t = unicodedata.normalize("NFC", t)
    t = re.sub(r"\{:[^}]*:\}", "", t)
    t = re.sub(r"<br\s*/?>", "\n", t)
    t = "\n".join(render_line(l) if l.strip() else "" for l in t.split("\n"))
    t = re.sub(r"[ \t]{2,}", " ", t).strip()
    return t or None


AMEN = {"es": ". Amén.", "fr": ". Ainsi soit-il."}[LANG]


def main():
    report = "--report" in sys.argv
    corpus = {}
    conflicts = Counter()
    always = set()  # derived pieces the apps render but the assets never spell out

    def add(lat, es, src):
        k = norm(lat)
        e = es_text(es)
        if not k or not e or len(k) < 4:
            return
        # an overlay field left in Latin, or a DO marker, is no translation
        if norm(e) == k or e.startswith(("$", "&", "!", "%", "@")):
            return
        if src in ("pater-split", "credo-split", "paschal", "asterisk"):
            always.add(k)
        if k in corpus and corpus[k] != e:
            conflicts[src] += 1
            return  # first source wins (the hours and psalter come first)
        corpus.setdefault(k, e)

    # 1. The hours' fixed parts.
    hours = {h["slug"]: h for h in load(ASSETS / "hours.json")}
    for slug, idx in vload("hours_parts").items():
        parts = hours.get(slug, {}).get("parts", [])
        for i, o in idx.items():
            if not i.isdigit() or int(i) >= len(parts):
                continue
            p = parts[int(i)]
            for lf, ef in (("lat", "eng"), ("latR", "engR"), ("antiphonLat", "antiphonEng"),
                           ("v1Lat", "v1Eng"), ("r1Lat", "r1Eng"), ("v2Lat", "v2Eng"), ("r2Lat", "r2Eng")):
                if p.get(lf) and o.get(ef):
                    add(p[lf], o[ef], "hours")
    # 2. The weekly psalter's parts (antiphons, capitula, versicles, hymns).
    pw = load(ASSETS / "psalter_weekly.json")
    for day, m in vload("psalter_weekly_parts").items():
        for key, es in m.items():
            p = (pw.get(day) or {}).get(key)
            if isinstance(p, dict):
                lat = p.get("antiphonLat") if isinstance(es, str) and p.get("antiphonLat") and not p.get("lat") else p.get("lat")
                if isinstance(es, str) and lat:
                    add(lat, es, "psalter_weekly")
                elif isinstance(es, dict):
                    for lf, ef in (("lat", "eng"), ("latR", "engR"), ("antiphonLat", "antiphonEng")):
                        if p.get(lf) and es.get(ef):
                            add(p[lf], es[ef], "psalter_weekly")
    # 3. The Office commons, propers and seasonal hymns.
    PAIRS = (("lat", "eng"), ("latR", "engR"), ("antiphonLat", "antiphonEng"),
             ("v1Lat", "v1Eng"), ("r1Lat", "r1Eng"), ("v2Lat", "v2Eng"), ("r2Lat", "r2Eng"))
    for sname, ename in (("commune_office.json", "commune_office"),
                         ("temporal_propers.json", "temporal_propers"),
                         ("sanctoral_propers.json", "sanctoral_propers"),
                         ("hymns_seasonal.json", "hymns_seasonal")):
        src = load(ASSETS / sname)
        for code, entry in vload(ename).items():
            for fk, o in entry.items():
                p = (src.get(code) or {}).get(fk)
                if not isinstance(p, dict) or not isinstance(o, dict):
                    continue
                for lf, ef in PAIRS:
                    if p.get(lf) and o.get(ef):
                        add(p[lf], o[ef], sname)
    # 4. Supplements keyed "commune:C12:responsory3:eng".
    co = load(ASSETS / "commune_office.json")
    for key, es in vload("hours_supplements").items():
        m = re.match(r"^commune:([^:]+):([^:]+):(eng|engR|antiphonEng)$", key)
        if not m or not isinstance(es, str):
            continue
        p = (co.get(m.group(1)) or {}).get(m.group(2)) or {}
        lf = {"eng": "lat", "engR": "latR", "antiphonEng": "antiphonLat"}[m.group(3)]
        if p.get(lf):
            add(p[lf], es, "supplements")
    # 5. Prayers and the Marian antiphons.
    pr_es = vload("prayers")
    for pr in load(ASSETS / "prayers.json"):
        o = pr_es.get(pr["slug"])
        if not o:
            continue
        lines = pr.get("lines") or []
        es_lines = o.get(f"lines_{LANG}") or []
        for l, e in zip(lines, es_lines):
            if isinstance(l, dict) and l.get("lat") and e:
                add(l["lat"], e, "prayers")
    ma_es = vload("marian_antiphons")
    for m in load(ASSETS / "marian_antiphons.json"):
        o = ma_es.get(m["slug"])
        if o and o.get(f"body_{LANG}") and m.get("lat"):
            add(m["lat"], o[f"body_{LANG}"], "marian")

    # 6. Divinum Officium's own Spanish column (dodump.pl with DO_LANG2=Espanol):
    #    the Psalterium, the Commons and the propers, section by section.
    do_es = Path(sys.argv[sys.argv.index("--do-es") + 1]) if "--do-es" in sys.argv else None
    do_en = Path(sys.argv[sys.argv.index("--do-en") + 1]) if "--do-en" in sys.argv else None
    # The English DO shows where it has no text in the language: every
    # English section and line of the same dumps, to be left out.
    en_secs, en_lines = set(), set()
    if do_en:
        def english(v):
            return v.get("eng") if isinstance(v, dict) else v
        for name in ("psalt.json", "psalt_sat.json", "commune.json", "propers_1962.json", "propers_1955.json", "propers_pre1955.json"):
            if not (do_en / name).exists():
                continue
            for k, secs in load(do_en / name).items():
                if name.startswith("psalt") and not k.startswith("English/"):
                    continue
                for sec, v in secs.items():
                    t = english(v)
                    if isinstance(t, str) and t.strip():
                        en_secs.add(norm(t))
                        for l in t.split("\n"):
                            l = norm(re.sub(r"\{:[^}]*:\}", "", l)).split(";;")[0]
                            if len(l) >= 25 or (len(l) >= 6 and ENGLISH_WORDS.search(l)):
                                en_lines.add(l)

    def is_english(t):
        return norm(t) in en_secs or norm(t).split(";;")[0] in en_lines

    if do_es:
        def lines_of(t):
            raw = [re.sub(r"\{:[^}]*:\}", "", l).strip() for l in (t or "").split("\n")]
            out = []
            for l in raw:
                # "Orémus pro Papa nostro~" + "r. N." is rendered as one line
                if out and out[-1].endswith("~") and re.match(r"^r\.\s*N\.", l):
                    out[-1] = out[-1][:-1].rstrip() + " " + re.sub(r"^r\.\s*", "", l)
                else:
                    out.append(l)
            return out
        def pair_sections(lat_secs, es_secs, src):
            for sec, lt in lat_secs.items():
                et = es_secs.get(sec)
                if isinstance(lt, dict):
                    lt, et = lt.get("lat"), (lt.get("eng") if et is None else et)
                if not isinstance(lt, str) or not isinstance(et, str) or not lt.strip() or not et.strip():
                    continue
                if norm(lt) == norm(et) or norm(et) in en_secs:
                    continue
                if not any(is_english(l) for l in et.split("\n") if l.strip()):
                    add(lt, et, src)  # the whole section
                ll, el = lines_of(lt), lines_of(et)

                def pair_lines(ll, el):
                    for l, e in zip(ll, el):
                        if l and e and not l.startswith(("$", "&", "#", "(", "@")) and not is_english(e):
                            # psalm-list lines "antiphon;;psalms": pair the antiphon
                            la, ea = l.split(";;")[0], e.split(";;")[0]
                            # "Dominica = antiphon" (the little hours' psalm tables)
                            ml, me = re.match(r"^([A-Z0-9][\w ]*?)\s*=\s*(.*)$", la), re.match(r"^([A-Z0-9][\w ]*?)\s*=\s*(.*)$", ea)
                            if ml and me and ml.group(1) == me.group(1):
                                la, ea = ml.group(2), me.group(2)
                            add(la, ea, src)
                if len(ll) == len(el):
                    pair_lines(ll, el)
                    continue
                # stanza by stanza (hymns: "_" separates stanzas), then the
                # marked lines only (responsories: ℟./℣. lines), dropping blanks
                def blocks(lines):
                    out, cur = [], []
                    for l in lines:
                        if l in ("", "_"):
                            if cur:
                                out.append(cur)
                            cur = []
                        else:
                            cur.append(l)
                    if cur:
                        out.append(cur)
                    return out
                bl, be = blocks(ll), blocks(el)
                if len(bl) > 1 and len(be) > 1 and abs(len(bl) - len(be)) <= 1:
                    # a translation may drop or merge the doxology stanza
                    for b1, b2 in zip(bl, be):
                        add("\n".join(b1), "\n".join(b2), src)
                        if len(b1) == len(b2):
                            pair_lines(b1, b2)
                    continue
                nl, ne = [l for l in ll if l and l != "_"], [l for l in el if l and l != "_"]
                if len(nl) == len(ne):
                    pair_lines(nl, ne)
                    continue
                # the translation carries extra lines at the end (a versicle
                # after the responsory): pair while the markers agree
                def marker(l):
                    m = re.match(r"^(℟\.br\.|℟\.|℣\.|R\.br\.|R\.|V\.|v\.|r\.|Ant\.|&\S+|\$\S+)", l)
                    return (m.group(1).replace("℟", "R").replace("℣", "V") if m else "")
                pre_l, pre_e = [], []
                for l, e in zip(nl, ne):
                    if marker(l) != marker(e):
                        break
                    pre_l.append(l)
                    pre_e.append(e)
                if len(pre_l) >= 2:
                    pair_lines(pre_l, pre_e)
        # psalt.json, psalt_sat.json (Saturday's forms) and, where dumped, the
        # other rubrics' (psalt_pre1955.json: "Jube, domne" for "Jube, Dómine")
        for name in sorted(p.name for p in do_es.glob("psalt*.json")):
            if (do_es / name).exists():
                d = load(do_es / name)
                for k, secs in d.items():
                    if not k.startswith("Latin/"):
                        continue
                    es_secs = d.get(DO_NAME + "/" + k[len("Latin/"):]) or {}
                    pair_sections(secs, es_secs, "do-es-psalt")
        if (do_es / "commune.json").exists():
            for f, secs in load(do_es / "commune.json").items():
                pair_sections(secs, {}, "do-es-commune")
        for rite in ("1962", "1955", "pre1955"):
            if (do_es / f"propers_{rite}.json").exists():
                for f, secs in load(do_es / f"propers_{rite}.json").items():
                    pair_sections(secs, {}, "do-es-propers")

    # 7. The psalter's lines (the preces' Miserére and De profúndis are
    #    assembled at render time with their own punctuation).
    ps_lat = load(ASSETS / "psalter.json")
    ps_es = vload("psalter")
    for key in ("psalm50", "psalm129"):
        for l, e in zip(ps_lat.get(key, {}).get("lat", []), (ps_es.get(key) or {}).get("lines") or []):
            m = re.match(r"^\(?\d+[a-z]?:\d+[a-z]?\)?\s+(.*)$", l)
            me = re.match(r"^\(?\d+[a-z]?:\d+[a-z]?\)?\s+(.*)$", e or "")
            if m and me:
                add(m.group(1), me.group(1).strip(), "psalter-preces")
                always.add(norm(m.group(1)))

    # The Pater noster said in parts (the hours' "Et ne nos indúcas" /
    # "Sed líbera nos a malo" split): pieces of the same sourced Spanish.
    for k in list(corpus):
        if fold(k).startswith("pater noster ci es in caelis") and "tentati" in fold(k):
            e = corpus[k]
            m = re.search({"es": r"^(.*?)[;,.]?\s*(y no nos dejes caer en la tentaci[oó]n)[;,.]?\s*(mas l[ií]branos del mal)\.?\s*(Am[eé]n\.?)?$",
                           "fr": r"^(.*?)[;,.]?\s*(et ne nous (?:laissez|induisez) [^.,;]*? tentation)[;,.]?\s*(mais d[eé]livrez-nous du mal)\.?\s*(Ainsi soit-il\.?|Amen\.?)?$"}[LANG], e, re.S | re.I)
            ml = re.search(r"^(.*?)[:;,.]?\s*(et ne nos ind[uú]cas in tentati[oó]nem)[:;,.]?\s*(sed l[ií]bera nos a malo)\.?\s*(Amen\.?)?$", k, re.S | re.I)
            if m and ml:
                add(render_line(ml.group(1)) + ":", render_line(m.group(1)).rstrip(" ,;") + ";", "pater-split")
                add(render_line(ml.group(1)) + ".", render_line(m.group(1)).rstrip(" ,;") + ".", "pater-split")
                v_es = m.group(2)[:1].upper() + m.group(2)[1:] + "."
                r_es = m.group(3)[:1].upper() + m.group(3)[1:] + "."
                add("V. " + ml.group(2) + ":", "℣. " + v_es, "pater-split")
                add("R. " + ml.group(3) + ".", "℟. " + r_es, "pater-split")
                add(ml.group(2)[:1].upper() + ml.group(2)[1:] + ":", v_es, "pater-split")
                add(ml.group(3)[:1].upper() + ml.group(3)[1:] + ".", r_es, "pater-split")
            break
    # The Apostles' Creed said in parts at Prime and Compline ("Carnis
    # resurrectiónem" / "Vitam ætérnam" as versicle and response).
    for k in list(corpus):
        if fold(k).startswith("credo in deum patrem omnipotentem") and "carnis" in fold(k):
            e = corpus[k]
            ml = re.search(r"^(.*?remissi[oó]nem peccat[oó]rum)[,.]?\s*(carnis resurrecti[oó]nem)[,.]?\s*(vitam (?:æ|ae)t[eé]rnam)\.?\s*(Amen\.?)?$", k, re.S | re.I)
            m = re.search({"es": r"^(.*?el perd[oó]n de los pecados)[,.]?\s*(la resurrecci[oó]n de la carne)[,.]?\s*(y la vida eterna)\.?\s*(Am[eé]n\.?)?$",
                           "fr": r"^(.*?la r[eé]mission des p[eé]ch[eé]s)[,.]?\s*(la r[eé]surrection de la chair)[,.]?\s*((?:et )?la vie [eé]ternelle)\.?\s*(Ainsi soit-il\.?|Amen\.?)?$"}[LANG], e, re.S | re.I)
            if ml and m:
                add(render_line(ml.group(1)) + ".", render_line(m.group(1)).rstrip(" ,;") + ".", "credo-split")
                add(ml.group(2)[:1].upper() + ml.group(2)[1:] + ".", m.group(2)[:1].upper() + m.group(2)[1:] + ".", "credo-split")
                add("V. " + ml.group(2)[:1].upper() + ml.group(2)[1:] + ".", "℣. " + m.group(2)[:1].upper() + m.group(2)[1:] + ".", "credo-split")
                add(ml.group(3)[:1].upper() + ml.group(3)[1:] + ". Amen.", m.group(3)[:1].upper() + m.group(3)[1:] + AMEN, "credo-split")
                add("R. " + ml.group(3)[:1].upper() + ml.group(3)[1:] + ". Amen.", "℟. " + m.group(3)[:1].upper() + m.group(3)[1:] + AMEN, "credo-split")
            break
    # Paschaltide brief responsories: "X, * Y." is said "X, y, * Allelúja, allelúja."
    for k0 in list(corpus):
        k = render_line(k0)
        if k.startswith("℟.br. ") and "*" in k and "llelú" not in k.lower():
            e = corpus[k0]
            if "\n" in e:
                continue
            if not e.startswith("℟.br. "):
                e = "℟.br. " + MARK_RE.sub("", e)
            def paschal(t):
                if "*" not in t:
                    return t.rstrip(" .,;:") + ", * "
                a, b2 = t.split("*", 1)
                b2 = b2.strip()
                b2 = b2[:1].lower() + b2[1:] if not b2[:2].isupper() else b2
                return a.rstrip(" ,.;:") + ", " + b2.rstrip(" .") + ", * "
            add(paschal(k) + "Allelúja, allelúja.", paschal(e) + f"{ALLELUIA}, {ALLELUIA.lower()}.", "paschal")
            add("℟. " + paschal(k)[6:] + "Allelúja, allelúja.", "℟. " + paschal(e)[6:] + f"{ALLELUIA}, {ALLELUIA.lower()}.", "paschal")

    if LANG != "es":
        PAREN = re.compile(r"\s*\((?:[Aa]ll[eé]l[uú][ij]a[.,]?\s*)+\)\s*$")
        for k, e in list(corpus.items()):
            # "… fílium. (Allelúja.)": the text as said outside Paschaltide
            if PAREN.search(k) and "\n" not in k:
                corpus.setdefault(PAREN.sub("", k), PAREN.sub("", e))
            # a ℣./℟. pair the apps print on one line ("Tu autem, Dómine, miserére nobis. Deo grátias.")
            kl, el = k.split("\n") if "\n" in k else re.split(r"\s+(?=R\.\s)", k), e.split("\n")
            if len(kl) == 2 and len(el) == 2 and re.match(r"^(V\.|℣\.)", kl[0]) and re.match(r"^(R\.|℟\.)", kl[1]):
                corpus.setdefault(MARK_RE.sub("", kl[0]) + " " + MARK_RE.sub("", kl[1]),
                                  MARK_RE.sub("", el[0]) + " " + MARK_RE.sub("", el[1]))

    if "--dump-corpus" in sys.argv:   # every Latin text gathered, for looking a missing one up by hand
        json.dump(corpus, open(sys.argv[sys.argv.index("--dump-corpus") + 1], "w", encoding="utf-8"), ensure_ascii=False, indent=0)

    # A looser index: without the ℣./℟. marks, the antiphon asterisk and
    # the final punctuation, case-folded (the legacy assets keep versicles
    # bare and place the asterisk differently).
    def loose(k):
        return fold(k)
    loose_ix = {}
    for k, e in corpus.items():
        loose_ix.setdefault(loose(k), e)

    # Apply to the DO assets: whole text, else line by line.
    def with_alleluia(e, n, star):
        e = re.sub(r"\s*\*\s*", " ", e).rstrip(" .,;:")
        return e + (" * " if star else ", ") + ", ".join([ALLELUIA] * n).replace(f"{ALLELUIA}, {ALLELUIA}", f"{ALLELUIA}, {ALLELUIA.lower()}") + "."

    # A blessing as the apps print it: without DO's "Benedictio." label, or
    # closed with the Amen that DO leaves to the answer.
    LABEL = re.compile(r"^(?:Bened[ií]ctio|Bénédiction|Bendición)\.\s*", re.I)
    AMEN = re.compile(r"\s*(?:℟\.\s*|R\.\s*)?(?:Amen|Amén|Ainsi soit-il)\.?\s*$")
    LABEL_V = {"es": "Bendición. ", "fr": "Bénédiction. "}[LANG]
    AMEN_V = {"es": " Amén.", "fr": " Ainsi soit-il."}[LANG]

    CONCLUSION = re.compile(r"(?<=[.:;,] )(Per (?:e[uú]ndem )?D[oó]minum nostrum|Per Christum D[oó]minum|Qui vivis et regnas|Qui tecum vivit|Qui cum Patre)")

    def core(t):
        return AMEN.sub("", LABEL.sub("", MARK_RE.sub("", t.strip())))
    core_ix = {}
    if LANG != "es":
        for k, e in corpus.items():
            if "\n" not in k and "\n" not in e and (LABEL.match(MARK_RE.sub("", k)) or AMEN.search(k)):
                core_ix.setdefault(loose(core(k)), core(e))

    def lookup1(l):
        """One line: exact, fuzzy, then without its Paschal alleluias."""
        k = norm(l)
        if k in corpus:
            return corpus[k]
        if len(loose(k)) >= 8 and loose(k) in loose_ix:
            return loose_ix[loose(k)]
        base, n, star = strip_alleluia(l)
        if n:
            e = lookup1(base)
            if e is not None:
                return with_alleluia(e, n, star)
        bare = MARK_RE.sub("", l.strip())
        c = core(l)
        if c != bare and len(loose(c)) >= 8:
            e = core_ix.get(loose(c)) or loose_ix.get(loose(c)) or corpus.get(norm(c))
            if e is not None:
                e = core(e)
                if e[-1:] not in ".!?»":
                    e += "."
                return (LABEL_V if LABEL.match(bare) else "") + e + (AMEN_V if AMEN.search(bare) else "")
        elif len(loose(c)) >= 8 and loose(c) in core_ix:
            return core_ix[loose(c)]
        # an oration printed with its conclusion on the same line
        m = CONCLUSION.search(l) if LANG != "es" else None
        if m and m.start() > 20:
            head, tail = lookup1(l[:m.start()].rstrip()), lookup1(l[m.start():].strip())
            if head is not None and tail is not None:
                return head.rstrip() + " " + MARK_RE.sub("", tail)
        return None

    def lookup(lat):
        k = norm(lat)
        if k in corpus:
            return corpus[k]
        if loose(k) in loose_ix and len(loose(k)) >= 8:
            return loose_ix[loose(k)]
        e1 = lookup1(lat) if "\n" not in lat else None
        if e1 is not None:
            return e1
        lines = [l for l in re.split(r"\n|<br\s*/?>", lat or "")]
        if len([l for l in lines if l.strip()]) > 1:
            out = []
            for l in lines:
                if not l.strip():
                    out.append("")
                    continue
                if re.match(r"^\d?\s?[A-Z][a-zæ]+\.?\s+\d+:\d+", l.strip()) and len(l.strip()) < 24:
                    out.append(l.strip())  # a scripture reference stays as it is
                    continue
                e = lookup1(l)
                if e is None:
                    return None
                # keep the Latin line's ℟./℣. marker on the Spanish
                m = MARK_RE.match(l.strip())
                if m and not MARK_RE.match(e):
                    e = m.group(1) + " " + e
                out.append(e)
            return "\n".join(out).strip()
        return None

    used = {}
    stats = Counter()
    missing_examples = []

    def try_text(lat, where):
        if not lat or not norm(lat):
            return
        es = lookup(lat)
        if es is None:
            stats[where + ":missing"] += 1
            if len(missing_examples) < 40:
                missing_examples.append((where, norm(lat)[:90]))
            # the apps fall back line by line: keep the lines that do resolve
            for l in re.split(r"\n|<br\s*/?>", lat):
                if l.strip() and not re.match(r"^[#!$&_(@/]", l.strip()):
                    e1 = lookup1(l)
                    if e1 is not None:
                        used.setdefault(norm(render_line(l)), e1)
        else:
            stats[where + ":ok"] += 1
            k = norm(lat)
            if k in corpus:
                used[k] = corpus[k]
            else:
                used[k] = es  # a line-by-line join: store the whole text too
            # The apps key the overlay on the text as rendered (DO's "v."/"r."
            # dropped, "V."/"R." as ℣./℟.; a ℣./℟. pair split into two parts):
            # store those forms too.
            ll = [l for l in re.split(r"\n|<br\s*/?>", lat) if l.strip()]
            el = [l for l in es.split("\n") if l.strip()]
            rk = norm("\n".join(render_line(l) for l in ll))
            if rk and rk != k:
                used.setdefault(rk, es)
            if len(ll) == len(el) and len(ll) > 1:
                for l, e in zip(ll, el):
                    lk = norm(render_line(l))
                    if len(lk) >= 4 and lk not in used:
                        used[lk] = e

    def walk(entry, where):
        for sk, part in (entry.get("parts") or {}).items():
            if not isinstance(part, dict):
                continue
            if sk == "Rule" or part.get("type") in ("script", "commemoration", "rubric"):
                # scripts and commemoration blocks carry DO markup; their
                # pieces are matched line by line at render time
                for l in re.split(r"\n", part.get("lat") or ""):
                    if l and not re.match(r"^[#!$&_(@/]", l):
                        try_text(re.sub(r"^(Ant\.|V\.|R\.|v\.|r\.)\s*", "", l), where + "/script")
                continue
            for f in ("lat", "latR", "antiphonLat"):
                if part.get(f):
                    try_text(part[f], where)
        for name, lines in (entry.get("psalmi") or {}).items():
            for l in lines:
                for f in ("ant", "v", "r"):
                    if l.get(f):
                        try_text(l[f], where + "/psalmi")

    walk(load(ASSETS / "office_psalterium.json"), "psalterium")
    # The Latin the rubrics engine carries in code (the preces, the Pater
    # noster of the hours, the martyrology's close ...).
    for src in (ROOT / "android/app/src/main/java/com/lampstandhq/introibo/data/content/OfficeAssembler.kt",
                ROOT / "android/app/src/main/java/com/lampstandhq/introibo/data/content/OfficeRubrics.kt"):
        for m in re.finditer(r'lat(?:R)?\s*\+?=\s*"((?:[^"\\]|\\.)*)"', src.read_text(encoding="utf-8")):
            lit = m.group(1).replace("\\n", "\n").replace('\\"', '"').replace("\\$", "$")
            if "${" in lit or len(norm(lit)) < 4:
                continue
            try_text(lit, "code")
    for code, entry in load(ASSETS / "office_commune.json").items():
        walk(entry, "commune")
    for rite in ("1962", "1955", "pre1955"):
        for key, entry in load(ASSETS / f"office_propers_{rite}.json").items():
            walk(entry, "propers")

    # Every Latin text the apps render over a year (collect_latin.py on
    # OfficeJsonDump's output): whatever the walks above did not reach.
    if "--targets" in sys.argv:
        for t in load(sys.argv[sys.argv.index("--targets") + 1]):
            try_text(t, "rendered")

    if LANG != "es":
        # A language without overlays of its own for the older assets (the
        # hours' fixed parts, the weekly psalter, the legacy commons and
        # propers, the Marian antiphons): their Latin is looked up too.
        FIELDS = ("lat", "latR", "antiphonLat", "v1Lat", "r1Lat", "v2Lat", "r2Lat", "versicle_lat", "collect_lat")
        def walk_legacy(node, where):
            if isinstance(node, dict):
                for f in FIELDS:
                    if isinstance(node.get(f), str):
                        try_text(node[f], where)
                for v in node.values():
                    walk_legacy(v, where)
            elif isinstance(node, list):
                for v in node:
                    walk_legacy(v, where)
        for name in ("hours.json", "psalter_weekly.json", "commune_office.json", "temporal_propers.json",
                     "sanctoral_propers.json", "hymns_seasonal.json", "marian_antiphons.json"):
            walk_legacy(load(ASSETS / name), name.split(".")[0])

    for k in always:
        used.setdefault(k, corpus[k])

    if os.environ.get("OFFICE_ES_DEBUG"):
        t = "℟.br. Christe, Fili Dei vivi, miserére nobis, * Allelúja, allelúja."
        print("DEBUG always", len(always), "paschal keys", sum(1 for k in always if "llelúja" in k), "target in corpus", t in corpus, "in always", t in always, [k for k in corpus if k.startswith("℟.br. Christe, Fili Dei vivi, mis")][:3])
    # Hand corrections to texts that only Divinum Officium's column supplies
    # (spanish-translation/office_texts_fixes_es.json: exact key -> Spanish).
    fixes = ES / f"office_texts_fixes_{LANG}.json"
    if fixes.exists():
        for k, e in load(fixes).items():
            used[k] = e
    # The antiphon said whole after its psalm (the asterisk dropped) and its
    # second half alone (the invitatory's "Veníte, adorémus" inside the
    # Venite): derived from every antiphon-like text the apps carry.
    def whole(t):
        return re.sub(r"\s+", " ", re.sub(r"\s+([,.;:])", r"\1", re.sub(r"\s*\*\s*", " ", t))).strip()
    for k0, e in list(used.items()):
        if " * " not in k0 or k0[:1].isdigit() or len(k0) > 200 or k0.startswith(("℟", "℣", "V.", "R.")) or "\n" in k0 or "\n" in e:
            continue
        wk, we = whole(k0), whole(e)
        if len(wk) >= 4 and we:
            used.setdefault(wk, we)
        if "*" in e:
            hk = k0.split(" * ", 1)[1].strip()
            he = e.split("*", 1)[1].strip().lstrip(",;: ")
            if hk[:1].isupper() and he and len(hk) >= 4:
                used.setdefault(hk, he[:1].upper() + he[1:])

    # a Spanish line keeping a ℣./℟. mark the Latin key does not carry, or
    # a different mark than the key's (a ℟.br. responsory reused as a ℣.)
    for k in list(used):
        e = used[k]
        if "\n" in e:
            continue
        mk, me = MARK_RE.match(k), MARK_RE.match(e)
        if not mk and me:
            e = MARK_RE.sub("", e, count=1)
        elif mk and me and mk.group(1) != me.group(1):
            e = mk.group(1) + " " + MARK_RE.sub("", e, count=1)
        if "*" not in k and "*" in e and "\n" not in k:
            e = re.sub(r"\s*\*\s*", " ", e)
            e = e[:1] + e[1:2].lower() + e[2:] if False else e
        used[k] = re.sub(r"\s{2,}", " ", e).strip()
    # DO markup that survived as "Spanish", and a verb form Spanish lacks
    # (a rubric line the Latin itself opens with "!" keeps its Spanish)
    for k in list(used):
        e = used[k]
        if (any(l.strip().startswith(("&", "$", "!", "%", "@")) for l in e.split("\n")) and not k.startswith("!")) or k.startswith(("&", "$")):
            del used[k]
            continue
        used[k] = e.replace("Descansed en paz", "Descansen en paz")
    if LANG != "es":
        # The hour templates the apps show as they are (the Office of the Dead,
        # opened from its template, and the search index): a language without
        # a hand-made hours_parts overlay gets one built from the same French,
        # by Latin text, and its psalm verses from the psalter overlay.
        ps_src = load(ASSETS / "psalter.json")
        LABEL = re.compile(r"^\(?\d+[a-z]?:\d+[a-z]?\)?\s+")
        # the Hebrew letters of Ps 118 and inline verse numbers: "(He)", "(3)", "(8a)"
        inline = re.compile(r"\(\s*(?:\d+[a-z]?|[A-Z][a-z]{1,5})\s*\)\s*")
        verse_ix = {}

        def add_runs(halves):
            for i in range(len(halves)):
                for n in range(1, 5):
                    run = halves[i:i + n]
                    if len(run) < n or any(x is None for x, _ in run):
                        break
                    k = " ".join(x for x, _ in run)
                    t = " ".join(y for _, y in run)
                    t = t[:1].upper() + t[1:]
                    verse_ix.setdefault(k, t.rstrip(" ,;:") + ("." if not t.rstrip()[-1:] in ".!?»" else ""))
        # The Invitatory as DO prints it (Psalterium/Invitatorium.txt), its
        # verses cut at DO's marks (+ * = ^ _ and the genuflexion rubric)
        do_root = Path(sys.argv[sys.argv.index("--do-root") + 1]) if "--do-root" in sys.argv else None
        if do_root:
            inv = {}
            for lang_dir in ("Latin", DO_NAME):
                f = do_root / "web/www/horas" / lang_dir / "Psalterium/Invitatorium.txt"
                inv[lang_dir] = [l[2:].strip() for l in f.read_text(encoding="utf-8").split("\n") if l.startswith("v. ")] if f.exists() else []
            cut = re.compile(r"\s*(?:/:[^/]*:/|[+*=^_])\s*")
            halves = []
            for a, b in zip(inv["Latin"], inv[DO_NAME]):
                aa, bb = [x for x in cut.split(a) if x.strip()], [x for x in cut.split(b) if x.strip()]
                if len(aa) == len(bb):
                    halves += [(fold(x), y.strip()) for x, y in zip(aa, bb)]
                else:
                    halves.append((None, None))
            add_runs(halves)
        for key, v in vload("psalter").items():
            # whole verses, and runs of half-verses (the templates divide some
            # psalms differently: the Invitatory, Ps 118's sections)
            halves = []
            for l, e in zip(ps_src.get(key, {}).get("lat", []), v.get("lines") or []):
                lt, et = inline.sub("", LABEL.sub("", l)), inline.sub("", LABEL.sub("", e))
                verse_ix.setdefault(fold(lt), re.sub(r"\s*\*\s*", " ", et).strip())
                ll, ee = lt.split(" * "), et.split(" * ")
                if len(ll) == len(ee):
                    halves += [(fold(x), y.strip()) for x, y in zip(ll, ee)]
                else:
                    halves.append((None, None))
            add_runs(halves)

        # Matins lessons, from the lesson table's own column
        lessons = load(ASSETS / "office_lessons.json")["texts"]
        lp = ASSETS / f"office_lessons_{LANG}.json"
        lesson_ix = {}
        if lp.exists():
            for t, v in zip(lessons, load(lp)):
                if v:
                    lesson_ix.setdefault(fold(t["lat"]), v)
        SENT = re.compile(r"(?<=[.:;!?])\s+(?=[A-ZÆŒÁÉÍÓÚ])")

        def vern(lat):
            e = used.get(norm(lat)) or lookup(lat) or lesson_ix.get(fold(lat))
            if e is None:
                # a versicle and its Gloria Patri, a collect and its conclusion,
                # printed as one paragraph: sentence by sentence, or nothing
                bits = [b for b in SENT.split(lat.strip()) if b]
                if len(bits) > 1:
                    got = [used.get(norm(b)) or lookup(b) or lesson_ix.get(fold(b)) for b in bits]
                    if all(got):
                        e = " ".join(MARK_RE.sub("", g).strip() for g in got)
            if e is None:
                return None
            if "\n" not in e and not MARK_RE.match(lat.strip()) and MARK_RE.match(e):
                e = MARK_RE.sub("", e, count=1)
            return e

        FIELDS = (("lat", "eng"), ("latR", "engR"), ("v1Lat", "v1Eng"), ("r1Lat", "r1Eng"),
                  ("v2Lat", "v2Eng"), ("r2Lat", "r2Eng"), ("antiphonLat", "antiphonEng"))
        parts_out, hstats, hmiss = {}, Counter(), []
        for h in load(ASSETS / "hours.json"):
            m = {}
            for i, p in enumerate(h.get("parts") or []):
                o = {}
                for lf, ef in FIELDS:
                    if p.get(lf) and p.get(ef):
                        e = vern(p[lf])
                        hstats["texts" if e else "texts missing"] += 1
                        if e:
                            o[ef] = e
                        elif len(hmiss) < 60:
                            hmiss.append((h["slug"], i, lf, norm(p[lf])[:90]))
                if p.get("verses"):
                    vs = [verse_ix.get(fold(inline.sub("", v.get("lat") or ""))) or vern(v.get("lat") or "") for v in p["verses"]]
                    hstats["verses"] += sum(1 for x in vs if x)
                    hstats["verses missing"] += sum(1 for x in vs if not x)
                    if any(vs):
                        o["verses"] = vs
                if o:
                    m[str(i)] = o
            if m:
                parts_out[h["slug"]] = m
        with open(ES / f"hours_parts_{LANG}.json", "w", encoding="utf-8") as f:
            json.dump(parts_out, f, ensure_ascii=False, indent=1)
            f.write("\n")
        print(f"hours_parts_{LANG}.json:", dict(hstats))
        if report:
            for x in hmiss:
                print("   missing template", *x, sep=" | ")

    out = ES / f"office_texts_{LANG}.json"
    with open(out, "w", encoding="utf-8") as f:
        json.dump(dict(sorted(used.items())), f, ensure_ascii=False, indent=1)
        f.write("\n")
    print(f"corpus {len(corpus)} Latin texts; {len(used)} used by the DO assets -> {out.relative_to(ROOT)}")
    if conflicts:
        print("conflicting Spanish (first source kept):", dict(conflicts))
    for k in sorted(stats):
        print(f"  {k}: {stats[k]}")
    if report:
        for w, l in missing_examples:
            print("   missing", w, "|", l)


if __name__ == "__main__":
    main()
