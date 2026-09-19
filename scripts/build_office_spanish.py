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
"""
import json, os, re, sys, unicodedata
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / "android" / "app" / "src" / "main" / "assets"
ES = ROOT / "spanish-translation"


def norm(t):
    """The key both apps compute: NFC, <br>/~ as spaces, whitespace collapsed."""
    t = unicodedata.normalize("NFC", t or "")
    t = re.sub(r"\{:[^}]*:\}", "", t)  # DO's hymn/section tags
    t = re.sub(r"<br\s*/?>", " ", t)
    t = t.replace("~", " ").replace(" ", " ")
    return re.sub(r"\s+", " ", t).strip()


def load(p):
    return json.load(open(p, encoding="utf-8"))


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
        if src in ("pater-split", "credo-split", "paschal"):
            always.add(k)
        if k in corpus and corpus[k] != e:
            conflicts[src] += 1
            return  # first source wins (the hours and psalter come first)
        corpus.setdefault(k, e)

    # 1. The hours' fixed parts.
    hours = {h["slug"]: h for h in load(ASSETS / "hours.json")}
    for slug, idx in load(ES / "hours_parts_es.json").items():
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
    for day, m in load(ES / "psalter_weekly_parts_es.json").items():
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
    for sname, ename in (("commune_office.json", "commune_office_es.json"),
                         ("temporal_propers.json", "temporal_propers_es.json"),
                         ("sanctoral_propers.json", "sanctoral_propers_es.json"),
                         ("hymns_seasonal.json", "hymns_seasonal_es.json")):
        src = load(ASSETS / sname)
        for code, entry in load(ES / ename).items():
            for fk, o in entry.items():
                p = (src.get(code) or {}).get(fk)
                if not isinstance(p, dict) or not isinstance(o, dict):
                    continue
                for lf, ef in PAIRS:
                    if p.get(lf) and o.get(ef):
                        add(p[lf], o[ef], sname)
    # 4. Supplements keyed "commune:C12:responsory3:eng".
    co = load(ASSETS / "commune_office.json")
    for key, es in load(ES / "hours_supplements_es.json").items():
        m = re.match(r"^commune:([^:]+):([^:]+):(eng|engR|antiphonEng)$", key)
        if not m or not isinstance(es, str):
            continue
        p = (co.get(m.group(1)) or {}).get(m.group(2)) or {}
        lf = {"eng": "lat", "engR": "latR", "antiphonEng": "antiphonLat"}[m.group(3)]
        if p.get(lf):
            add(p[lf], es, "supplements")
    # 5. Prayers and the Marian antiphons.
    pr_es = load(ES / "prayers_es.json")
    for pr in load(ASSETS / "prayers.json"):
        o = pr_es.get(pr["slug"])
        if not o:
            continue
        lines = pr.get("lines") or []
        es_lines = o.get("lines_es") or []
        for l, e in zip(lines, es_lines):
            if isinstance(l, dict) and l.get("lat") and e:
                add(l["lat"], e, "prayers")
    ma_es = load(ES / "marian_antiphons_es.json")
    for m in load(ASSETS / "marian_antiphons.json"):
        o = ma_es.get(m["slug"])
        if o and o.get("body_es") and m.get("lat"):
            add(m["lat"], o["body_es"], "marian")

    # 6. Divinum Officium's own Spanish column (dodump.pl with DO_LANG2=Espanol):
    #    the Psalterium, the Commons and the propers, section by section.
    do_es = Path(sys.argv[sys.argv.index("--do-es") + 1]) if "--do-es" in sys.argv else None
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
                if norm(lt) == norm(et):
                    continue
                add(lt, et, src)  # the whole section
                ll, el = lines_of(lt), lines_of(et)

                def pair_lines(ll, el):
                    for l, e in zip(ll, el):
                        if l and e and not l.startswith(("$", "&", "#", "(", "@")):
                            # psalm-list lines "antiphon;;psalms": pair the antiphon
                            la, ea = l.split(";;")[0], e.split(";;")[0]
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
        for name in ("psalt.json", "psalt_sat.json"):
            if (do_es / name).exists():
                d = load(do_es / name)
                for k, secs in d.items():
                    if not k.startswith("Latin/"):
                        continue
                    es_secs = d.get("Espanol/" + k[len("Latin/"):]) or {}
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
    ps_es = load(ES / "psalter_es.json")
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
            m = re.search(r"^(.*?)[;,.]?\s*(y no nos dejes caer en la tentaci[oó]n)[;,.]?\s*(mas l[ií]branos del mal)\.?\s*(Am[eé]n\.?)?$", e, re.S | re.I)
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
            m = re.search(r"^(.*?el perd[oó]n de los pecados)[,.]?\s*(la resurrecci[oó]n de la carne)[,.]?\s*(y la vida eterna)\.?\s*(Am[eé]n\.?)?$", e, re.S | re.I)
            if ml and m:
                add(render_line(ml.group(1)) + ".", render_line(m.group(1)).rstrip(" ,;") + ".", "credo-split")
                add(ml.group(2)[:1].upper() + ml.group(2)[1:] + ".", m.group(2)[:1].upper() + m.group(2)[1:] + ".", "credo-split")
                add("V. " + ml.group(2)[:1].upper() + ml.group(2)[1:] + ".", "℣. " + m.group(2)[:1].upper() + m.group(2)[1:] + ".", "credo-split")
                add(ml.group(3)[:1].upper() + ml.group(3)[1:] + ". Amen.", m.group(3)[:1].upper() + m.group(3)[1:] + ". Amén.", "credo-split")
                add("R. " + ml.group(3)[:1].upper() + ml.group(3)[1:] + ". Amen.", "℟. " + m.group(3)[:1].upper() + m.group(3)[1:] + ". Amén.", "credo-split")
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
            add(paschal(k) + "Allelúja, allelúja.", paschal(e) + "Aleluya, aleluya.", "paschal")
            add("℟. " + paschal(k)[6:] + "Allelúja, allelúja.", "℟. " + paschal(e)[6:] + "Aleluya, aleluya.", "paschal")

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
        return e + (" * " if star else ", ") + ", ".join(["Aleluya"] * n).replace("Aleluya, Aleluya", "Aleluya, aleluya") + "."

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

    for k in always:
        used.setdefault(k, corpus[k])

    if os.environ.get("OFFICE_ES_DEBUG"):
        t = "℟.br. Christe, Fili Dei vivi, miserére nobis, * Allelúja, allelúja."
        print("DEBUG always", len(always), "paschal keys", sum(1 for k in always if "llelúja" in k), "target in corpus", t in corpus, "in always", t in always, [k for k in corpus if k.startswith("℟.br. Christe, Fili Dei vivi, mis")][:3])
    # Hand corrections to texts that only Divinum Officium's column supplies
    # (spanish-translation/office_texts_fixes_es.json: exact key -> Spanish).
    fixes = ES / "office_texts_fixes_es.json"
    if fixes.exists():
        for k, e in load(fixes).items():
            used[k] = e
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
    for k in list(used):
        e = used[k]
        if any(l.strip().startswith(("&", "$", "!", "%", "@")) for l in e.split("\n")) or k.startswith(("&", "$")):
            del used[k]
            continue
        used[k] = e.replace("Descansed en paz", "Descansen en paz")
    out = ES / "office_texts_es.json"
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
