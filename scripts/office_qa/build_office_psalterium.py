#!/usr/bin/env python3
"""Build the Office psalter-season data and the per-rite office rules from
Divinum Officium, resolved through DO's own setupstring (dodump.pl).

  perl scripts/office_qa/dodump.pl "Rubrics 1960 - 1960" psalt  > /tmp/dopsalt_1962.json
  perl scripts/office_qa/dodump.pl "Rubrics 1960 - 1960" rules  > /tmp/dorules_1962.json
  perl scripts/office_qa/dodump.pl "Reduced - 1955" rules       > /tmp/dorules_1955.json
  perl scripts/office_qa/dodump.pl "Divino Afflatu - 1954" rules > /tmp/dorules_pre1955.json
  python3 scripts/office_qa/build_office_psalterium.py --psalt /tmp/dopsalt_1962.json \
      --rules 1962=/tmp/dorules_1962.json 1955=/tmp/dorules_1955.json pre1955=/tmp/dorules_pre1955.json

Outputs (iOS + Android copies):
  office_psalterium.json  { "parts": {DO section: Hour.Part},
                            "psalmi": {DO section: [{ant, antEng, psalms} | {v, r, vEng, rEng}]} }
  office_rules.json       { rite: { key: {rankName, rank, communeType, commune, rule} } }

The section keys are DO's own (e.g. "Adv Laudes", "Versum Feria Tertia",
"Day1 Laudes2", "Adv 1 Versum") so the rubric code reads like DO's.
"""
import argparse, json, re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUTS = [ROOT / "Introibo" / "Resources", ROOT / "android" / "app" / "src" / "main" / "assets"]

GLORIA_LAT = "Glória Patri, et Fílio, et Spirítui Sancto."
GLORIA_ENG = "Glory be to the Father, and to the Son, and to the Holy Ghost."


def clean(s):
    s = re.sub(r"\{:[^}]*:\}", "", s or "")
    s = s.replace("\r", "")
    # DO's "~" joins a line with the next (long antiphons).
    s = re.sub(r"\s*~\s*\n\s*", " ", s)
    return s.rstrip()


# ---------------------------------------------------------------- DO section references

REF_RE = re.compile(r"^@([^:\n]*)(?::([^:\n]*))?(?::(.*))?$")


def _perl_sub(text, mod):
    """Apply a DO 's/pat/rep/flags' modifier (or a 'n-m' line range)."""
    if not mod:
        return text
    m = re.match(r"^(\d+)(?:-(\d+))?$", mod.strip())
    if m:
        ls = text.split("\n")
        lo = int(m.group(1)); hi = int(m.group(2) or m.group(1))
        return "\n".join(ls[lo - 1:hi])
    m = re.match(r"^s/((?:\\/|[^/])*)/((?:\\/|[^/])*)/(\w*)$", mod.strip())
    if not m:
        return text
    pat, rep_, flags = m.group(1), m.group(2), m.group(3)
    fl = 0
    if "i" in flags: fl |= re.I
    if "s" in flags: fl |= re.S
    if "m" in flags: fl |= re.M
    rep_ = re.sub(r"\$(\d)", r"\\\1", rep_)
    try:
        return re.sub(pat, rep_, text, count=0 if "g" in flags else 1, flags=fl)
    except re.error:
        return text


def expand_refs(files, lookup, depth=0):
    """Resolve '@File:Section[:modifier]' lines inside every section of every
    file (DO getrefs), from the raw dumps: files = {path: {sec: {lat, eng}}};
    lookup(path) -> that file's raw sections (any dump)."""
    if depth > 4:
        return
    for path, secs in files.items():
        for sec, lv in secs.items():
            for lang in ("lat", "eng"):
                text = lv.get(lang) or ""
                if "@" not in text:
                    continue
                out = []
                changed = False
                for line in text.split("\n"):
                    m = REF_RE.match(line.strip())
                    if not m:
                        out.append(line)
                        continue
                    rpath, rsec, mod = m.group(1), m.group(2), m.group(3)
                    # DO getrefs builds a whole commemoration (antiphon,
                    # versicle, collect) from "@File:Oratio": keep the reference.
                    if sec.startswith("Commemoratio") and re.search(r"oratio|octava", rsec or "", re.I):
                        out.append(line)
                        continue
                    src = secs if not rpath else lookup(rpath)
                    rsec = rsec or sec
                    ref = (src or {}).get(rsec) or {}
                    rt = ref.get(lang) or (ref.get("lat") if lang == "eng" else "") or ""
                    if rt:
                        out.append(_perl_sub(rt, mod))
                        changed = True
                    else:
                        out.append(line if not src else "")
                if changed:
                    lv[lang] = "\n".join(out)
    # nested references
    if any("@" in (lv.get("lat") or "") for secs in files.values() for lv in secs.values()):
        expand_refs(files, lookup, depth + 1)


def lines_of(text):
    return [l.rstrip() for l in clean(text).split("\n") if l.strip() != ""]


# ---------------------------------------------------------------- converters

def conv_capitulum(lat, eng):
    ll, el = lines_of(lat), lines_of(eng)
    ref = None
    if ll and ll[0].startswith("!"):
        ref = ll[0][1:].strip()
        ll = ll[1:]
    if el and el[0].startswith("!"):
        el = el[1:]
    ll = [re.sub(r"^v\.\s*", "", l) for l in ll if not l.startswith("$")]
    el = [re.sub(r"^v\.\s*", "", l) for l in el if not l.startswith("$")]
    p = {"type": "capitulum", "label": "Capitulum", "lat": "\n".join(ll)}
    if ref:
        p["ref"] = ref
    if el:
        p["eng"] = "\n".join(el)
    return p


def conv_hymn(lat, eng):
    def stanzas(text):
        out, cur = [], []
        for l in lines_of(text):
            if l.strip() == "_":
                if cur:
                    out.append(cur)
                cur = []
            elif l.startswith("/:") or l.startswith("(") and l.endswith(")"):
                continue  # rubric line ("Prima stropha ... flexis genibus")
            else:
                cur.append(re.sub(r"^(?:v\.|r\.)\s*", "", l).replace("*", "").strip())
        if cur:
            out.append(cur)
        return out
    ls, es = stanzas(lat), stanzas(eng)
    if not ls:
        return None
    title = re.sub(r"[,.;:]+$", "", ls[0][0]).strip()
    p = {"type": "hymn", "label": "Hymn", "title": title,
         "lat": "\n\n".join("\n".join(s) for s in ls)}
    if es:
        p["eng"] = "\n\n".join("\n".join(s) for s in es)
    return p


def vr_pair(text):
    v = r = None
    for l in lines_of(text):
        if l.startswith("V. "):
            v = l[3:].strip()
        elif l.startswith("R. "):
            r = l[3:].strip()
    return v, r


def conv_versicle(lat, eng):
    v, r = vr_pair(lat)
    ve, re_ = vr_pair(eng)
    if not v:
        return None
    p = {"type": "vr", "label": "Versicle", "lat": "℣. " + v, "latR": "℟. " + (r or "")}
    if ve:
        p["eng"] = "℣. " + ve
        p["engR"] = "℟. " + (re_ or "")
    return p


def conv_responsory(lat, eng):
    """DO: R.br. A * B / R. A * B / V. C / R. B / &Gloria / R. A * B
       app: ℟.br. A * B / ℣. C / ℟. B / Gloria / ℟. A * B"""
    def conv(text, gloria):
        out = []
        ls = lines_of(text)
        if not ls:
            return None
        seen_rbr = False
        for l in ls:
            if l.startswith("R.br. "):
                out.append("℟.br. " + l[6:].strip())
                seen_rbr = True
            elif l.startswith("R. ") and seen_rbr and len(out) == 1:
                continue  # the repeat of the responsory
            elif l.startswith("V. "):
                out.append("℣. " + l[3:].strip())
            elif l.startswith("R. "):
                out.append("℟. " + l[3:].strip())
            elif l.startswith("&Gloria"):
                out.append(gloria)
            elif l.startswith("$") or l.startswith("_"):
                continue
            else:
                out.append(l.strip())
        return "\n".join(out)
    la = conv(lat, GLORIA_LAT)
    if not la:
        return None
    p = {"type": "responsory", "label": "Responsorium Breve", "lat": la}
    en = conv(eng, GLORIA_ENG)
    if en:
        p["eng"] = en
    return p


def conv_antiphon(lat, eng, label="Antiphon"):
    ll, el = lines_of(lat), lines_of(eng)
    if not ll:
        return None
    p = {"type": "antiphon", "label": label, "lat": ll[0].strip()}
    if el:
        p["eng"] = el[0].strip()
    return p


def psalm_ref(tok):
    """DO "44('2a'-'10b')" / "17(2-'16b')" / "9(2-11)" / "50" -> "44:2a-10b" etc."""
    tok = tok.strip().replace("'", "")
    m = re.match(r"^(\d+)(?:\((\d+[ab]?)-(\d+[ab]?)\))?$", tok)
    if not m:
        return tok
    if m.group(2):
        return "%s:%s-%s" % (m.group(1), m.group(2), m.group(3))
    return m.group(1)


def conv_psalmi(lat, eng):
    """Antiphon;;psalm lines and V./R. pairs, English aligned by index."""
    ll = [l for l in clean(lat).split("\n")]
    el = [l for l in clean(eng).split("\n")]
    # drop trailing blank lines but keep internal structure
    while ll and ll[-1].strip() == "":
        ll.pop()
    while el and el[-1].strip() == "":
        el.pop()
    out = []
    i = 0
    while i < len(ll):
        l = ll[i]
        e = el[i] if i < len(el) else ""
        if l.startswith("V. "):
            r = ll[i + 1] if i + 1 < len(ll) else ""
            er = el[i + 1] if i + 1 < len(el) else ""
            ent = {"v": l[3:].strip(), "r": r[3:].strip() if r.startswith("R. ") else r.strip()}
            if e.startswith("V. "):
                ent["vEng"] = e[3:].strip()
                ent["rEng"] = er[3:].strip() if er.startswith("R. ") else er.strip()
            out.append(ent)
            i += 2
            continue
        ant, _, ps = l.partition(";;")
        ant = re.sub(r"^\d+\s*=\s*", "", ant).strip()
        ent = {"ant": ant}
        if ps.strip():
            ent["psalms"] = [psalm_ref(t) for t in re.split(r"[;,]", ps) if t.strip()]
        if e and not e.startswith("V. "):
            eant = e.partition(";;")[0]
            eant = re.sub(r"^\d+\s*=\s*", "", eant).strip()
            if eant:
                ent["antEng"] = eant
        out.append(ent)
        i += 1
    return out


def conv_named_lines(lat, eng):
    """'Dominica = text' lines -> ordered list of {name, ant, antEng}."""
    out = []
    el = {}
    for l in lines_of(eng):
        if "=" in l:
            k, _, v = l.partition("=")
            el[k.strip()] = v.strip()
    for l in lines_of(lat):
        if "=" not in l:
            continue
        k, _, v = l.partition("=")
        ent = {"name": k.strip(), "ant": v.strip()}
        if k.strip() in el and el[k.strip()]:
            ent["antEng"] = el[k.strip()]
        out.append(ent)
    return out


# ---------------------------------------------------------------- build

def is_roman_key(k):
    if re.search(r"\((?:rubrica|feria)", k):
        return False
    if re.search(r"(?:^|\s)(?:HymnusM|Hymnus1M)\b", k) or k.endswith("M") or "OP" in k or "Cist" in k or k.endswith("_") or k.endswith("_C") or "Monastic" in k or "Cistercian" in k or "Trid" in k or "Tridentinum" in k:
        return False
    return True


def build_psalterium(psalt):
    L = lambda f: psalt.get("Latin/" + f, {})
    E = lambda f: psalt.get("English/" + f, {})
    parts, psalmi = {}, {}

    # Major Special: capitula (<T> Laudes/Vespera), hymns, versicles, Ant 2/3
    ML, ME = L("Special/Major Special.txt"), E("Special/Major Special.txt")
    for k, v in ML.items():
        if not is_roman_key(k):
            continue
        e = ME.get(k, "")
        if k.startswith("Hymnus "):
            p = conv_hymn(v, e)
        elif "Versum" in k:
            p = conv_versicle(v, e)
        elif k.startswith("Suffragium") or k.startswith("Preces"):
            p = {"type": "script", "label": k, "lat": clean(v).strip(), "eng": clean(e).strip()}
        elif k.startswith("Responsory ") or k.startswith("Comment"):
            continue
        elif re.search(r" Ant \d", k):
            p = conv_antiphon(v, e)
        elif k.startswith("Adv Ant "):
            p = conv_antiphon(v, e)
        elif re.match(r"^(Dominica|Feria|Adv|Quad|Quad5|Pasch|Nat|Epi|Asc|Pent) (Laudes|Vespera)", k):
            p = conv_capitulum(v, e)
        else:
            continue
        if p:
            parts[k] = p

    # Minor Special: capitula, responsories, versicles, hymns, Compline pieces
    mL, mE = L("Special/Minor Special.txt"), E("Special/Minor Special.txt")
    for k, v in mL.items():
        if not is_roman_key(k):
            continue
        e = mE.get(k, "")
        if k.startswith("Hymnus "):
            p = conv_hymn(v, e)
        elif k.startswith("Responsory breve ") or k == "Responsory Completorium":
            p = conv_responsory(v, e)
        elif k.startswith("Responsory "):
            continue
        elif k.startswith("Versum "):
            p = conv_versicle(v, e)
        elif k.startswith("Ant 4"):
            p = conv_antiphon(v, e)
        elif k.startswith("Preces"):
            p = {"type": "script", "label": k, "lat": clean(v).strip(), "eng": clean(e).strip()}
        elif k == "Lectio Completorium":
            p = conv_capitulum(v, e)
            p["type"] = "reading"
            p["label"] = "Lectio brevis"
        elif re.match(r"^(Dominica|Feria|Adv|Quad|Quad5|Pasch|Asc|Pent) (Tertia|Sexta|Nona)$", k) or k == "Completorium":
            p = conv_capitulum(v, e)
        else:
            continue
        if p:
            parts[k] = p

    # Matutinum Special: invitatories, hymns
    tL, tE = L("Special/Matutinum Special.txt"), E("Special/Matutinum Special.txt")
    for k, v in tL.items():
        if not is_roman_key(k):
            continue
        e = tE.get(k, "")
        if k == "Invit":
            for ent in conv_named_lines(v, e):
                p = {"type": "antiphon", "label": "Invitatory Antiphon", "lat": ent["ant"]}
                if "antEng" in ent:
                    p["eng"] = ent["antEng"]
                parts["Invit " + ent["name"]] = p
        elif k.startswith("Invit "):
            p = conv_antiphon(v, e, "Invitatory Antiphon")
            if p:
                parts[k] = p
        elif "Hymnus" in k:
            p = conv_hymn(v, e)
            if p:
                parts[k] = p
        elif k.startswith("Nocturn "):
            p = conv_versicle(v, e)
            if p:
                parts[k] = p

    # Prima Special: capitula per season, responsory + seasonal ℣ variants
    pL, pE = L("Special/Prima Special.txt"), E("Special/Prima Special.txt")
    for k, v in pL.items():
        if k.startswith("Preces") and is_roman_key(k):
            parts[k] = {"type": "script", "label": k, "lat": clean(v).strip(), "eng": clean(pE.get(k, "")).strip()}
            continue
        if not is_roman_key(k):
            continue
        e = pE.get(k, "")
        if k in ("Dominica", "Feria", "Per Annum", "Adv", "Nat", "Epi", "Asc", "Quad", "Quad5", "Pasch", "Pent"):
            p = conv_capitulum(v, e)
            parts["Prima " + k] = p
        elif k == "Responsory":
            p = conv_responsory(v, e)
            parts["Prima Responsory"] = p
        elif k.startswith("Responsory "):
            p = conv_antiphon(v, e, "Versus")
            if p:
                parts["Prima " + k] = p
        elif k == "Versum":
            p = conv_versicle(v, e)
            parts["Prima Versum"] = p
        elif k.startswith("Hymnus"):
            p = conv_hymn(v, e)
            if p:
                parts["Prima " + k] = p

    # Psalmi major / matutinum
    for f in ("Psalmi/Psalmi major.txt", "Psalmi/Psalmi matutinum.txt"):
        jL, jE = L(f), E(f)
        for k, v in jL.items():
            if not is_roman_key(k) or k.startswith("Daya") or k.startswith("Daym") or k.startswith("Dayc"):
                continue
            if "Versum" in k:
                p = conv_versicle(v, jE.get(k, ""))
                if p:
                    parts[k] = p
                continue
            psalmi[k] = conv_psalmi(v, jE.get(k, ""))

    # Psalmi minor: the hours' weekday antiphons + psalms, and the seasonal sets
    nL, nE = L("Psalmi/Psalmi minor.txt"), E("Psalmi/Psalmi minor.txt")
    for k, v in nL.items():
        if not is_roman_key(k) or k in ("Tridentinum", "Monastic", "Cistercian") or k.endswith("OP"):
            continue
        e = nE.get(k, "")
        if k in ("Prima", "Tertia", "Sexta", "Nona", "Completorium"):
            ll = [l for l in clean(v).split("\n") if l.strip() != ""]
            el = [l for l in clean(e).split("\n") if l.strip() != ""]
            ents = []
            names = {}
            for l in el:
                if "=" in l:
                    a, _, b = l.partition("=")
                    names[a.strip()] = b.strip()
            i = 0
            while i + 1 < len(ll):
                a, _, b = ll[i].partition("=")
                ent = {"name": a.strip(), "ant": b.strip(),
                       "psalms": [psalm_ref(t) for t in ll[i + 1].split(",") if t.strip()]}
                if names.get(a.strip()):
                    ent["antEng"] = names[a.strip()]
                ents.append(ent)
                i += 2
            psalmi["Minor " + k] = ents
        else:
            # seasonal antiphon sets: "1 = ..." lines (index 1..5), or bare lines (Pasch)
            ents = conv_named_lines(v, e)
            if not ents:
                ll, el = lines_of(v), lines_of(e)
                ents = [{"name": str(i + 1), "ant": l, **({"antEng": el[i]} if i < len(el) else {})} for i, l in enumerate(ll)]
            if ents:
                psalmi["Minor " + k] = ents
    # Common prayers (the pieces DO scripts call as $Confiteor, $Pater noster ...)
    pL, pE = L("Common/Prayers.txt"), E("Common/Prayers.txt")
    for k, v in pL.items():
        if not is_roman_key(k) or not clean(v).strip():
            continue
        parts["Prayer " + k] = {"type": "prayer", "label": k, "lat": clean(v).strip(), "eng": clean(pE.get(k, "")).strip()}
    # The Litany of the Saints (Lauds of St Mark and the Rogation days).
    prL, prE = L("Special/Preces.txt"), E("Special/Preces.txt")
    if prL.get("Litania"):
        parts["Litania"] = {"type": "script", "label": "Litaniæ", "lat": clean(prL["Litania"]).strip(), "eng": clean(prE.get("Litania", "")).strip()}
    for k, v in prL.items():
        if not k.startswith("Litania") and clean(v).strip():
            parts["Prayer " + k] = {"type": "prayer", "label": k, "lat": clean(v).strip(), "eng": clean(prE.get(k, "")).strip()}
    return {"parts": parts, "psalmi": psalmi}


def key_for(path):
    d, f = path.split("/", 1)
    base = f[:-4] if f.endswith(".txt") else f
    if d == "Tempora":
        return base.lower()
    if d == "Sancti":
        return base
    return base  # Commune codes as-is


def norm_commune(ref):
    ref = (ref or "").strip()
    if not ref:
        return None
    if ref.startswith("Sancti/"):
        return "sancti:" + ref[7:]
    if ref.startswith("Tempora/"):
        return "tempora:" + ref[8:].lower()
    if re.match(r"^C\d", ref):
        return ref
    return "tempora:" + ref.lower()


def add_saturday_variants(ps, psalt_sat):
    """Sections that DO resolves differently on Saturday ("(feria 7)" scopes):
    the I-Vespers-of-Sunday capitulum, versicle and Magnificat antiphon."""
    sat = build_psalterium(psalt_sat)
    for k, v in sat["parts"].items():
        if k in ps["parts"] and ps["parts"][k] != v:
            ps["parts"][k + " (feria 7)"] = v
    for k, v in sat["psalmi"].items():
        if k in ps["psalmi"] and ps["psalmi"][k] != v:
            ps["psalmi"][k + " (feria 7)"] = v


def build_ants(ants):
    """Antiphon lists (with their psalm numbers) of every proper, temporal
    and commune office file: { key: { DO section: [lines] } }."""
    out = {}
    for path, secs in ants.items():
        d, f = path.split("/", 1)
        base = f[:-4]
        key = {"Sancti": "sancti:" + base, "Tempora": "tempora:" + base.lower()}.get(d, base)
        ent = {}
        for sec, lv in secs.items():
            lines = conv_psalmi(lv.get("lat") or "", lv.get("eng") or "")
            if lines:
                ent[sec] = lines
        if ent:
            out[key] = ent
    return out


def split_embedded_commemoratio(lat, eng):
    """A collect followed by "!Commemoratio ..." blocks (DO getrefs of
    "@File:CommemoratioN" inside an Oratio): the collect, and the blocks."""
    def cut(text):
        m = re.search(r"\n(?=!Commemoratio)", clean(text), re.I)
        if not m:
            return clean(text), ""
        return clean(text)[:m.start()], clean(text)[m.end():]
    l, le = cut(lat)
    e, ee = cut(eng)
    return l, e, ((le.strip(), ee.strip()) if le.strip() else None)


def convert_office_sections(secs):
    """DO office sections of one file -> {"parts": {...}, "psalmi": {...}}."""
    parts, psalmi = {}, {}
    for sec, lv in secs.items():
        lat = lv.get("lat") or ""
        eng = lv.get("eng") or ""
        if not lat.strip():
            # A blank [Commemoratio N] means: no commemoration at that hour.
            if sec.startswith("Commemoratio"):
                parts[sec] = {"type": "commemoration", "label": "Commemoratio", "lat": "", "eng": ""}
            continue
        if sec in ("Ant Matutinum", "Ant Laudes", "Ant Vespera", "Ant Vespera 3"):
            psalmi[sec] = conv_psalmi(lat, eng)
        elif re.match(r"^Ant (1|2|3|4|41|43)$", sec) or sec == "Invit" or re.match(r"^Ant (Prima|Tertia|Sexta|Nona|Completorium)$", sec):
            p = conv_antiphon(lat, eng)
            if p and re.match(r"^Ant 4", sec) and len(lines_of(lat)) > 1:
                # Compline's canticle antiphon with a second line said after
                # the canticle (Easter week's "Hæc dies").
                p["lat"] = "\n".join(l.strip() for l in lines_of(lat))
                if lines_of(eng):
                    p["eng"] = "\n".join(l.strip() for l in lines_of(eng))
            if p:
                parts[sec] = p
        elif sec.startswith("Hymnus"):
            if re.search(r"HymnusM|Hymnus1M", sec):
                continue
            p = conv_hymn(lat, eng)
            if p:
                parts[sec] = p
        elif sec.startswith("Capitulum") or sec == "Lectio Prima":
            p = conv_capitulum(lat, eng)
            if sec == "Lectio Prima":
                p["type"] = "reading"
                p["label"] = "Lectio brevis"
            parts[sec] = p
        elif sec.startswith("Versum") or sec.startswith("Nocturn"):
            p = conv_versicle(lat, eng)
            if not p:
                # "Ant. Hæc dies" standing in a Versum slot
                p = conv_antiphon(lat, eng)
                if p:
                    p["lat"] = re.sub(r"^Ant\.\s*", "", p["lat"])
                    if p.get("eng"):
                        p["eng"] = re.sub(r"^Ant\.\s*", "", p["eng"])
            if p:
                parts[sec] = p
        elif sec.startswith("Responsory Breve"):
            p = conv_responsory(lat, eng)
            if p:
                parts[sec] = p
        elif sec.startswith("Special ") or sec in ("Initial", "Conclusio") or sec.startswith("Oratio mortuorum"):
            # DO scripts rendering a whole hour (All Souls, the Triduum's
            # Compline, the Easter Vigil's Vespers) or one of their pieces.
            parts[sec] = {"type": "script", "lat": clean(lat).strip(), "eng": clean(eng).strip()}
        elif re.match(r"^Ant Matutinum \d+$", sec):
            p = conv_antiphon(lat, eng)
            if p:
                parts[sec] = p
        elif sec.startswith("Oratio"):
            lat, eng, emb = split_embedded_commemoratio(lat, eng)
            if emb:
                parts[sec + " Commemoratio"] = {"type": "commemoration", "label": "Commemoratio", "lat": emb[0], "eng": emb[1]}
            skip = lambda l: l.startswith("$") or l.startswith("!") or l.startswith("/:") or (l.startswith("&") and not l.startswith("&psalm("))
            ll = [re.sub(r"^v\.\s*", "", l) for l in lines_of(lat) if not skip(l)]
            el = [re.sub(r"^v\.\s*", "", l) for l in lines_of(eng) if not skip(l)]
            # The Triduum: "Christus factus est", the Pater noster said in
            # silence, then the collect.
            if any(l.startswith("$Pater noster") for l in lines_of(lat)):
                i = next(i for i, l in enumerate(lines_of(lat)) if l.startswith("$Pater noster"))
                before = sum(1 for l in lines_of(lat)[:i] if not l.startswith("$") and not l.startswith("!") and not l.startswith("/:"))
                ll.insert(before, "Pater noster (secréto).")
                if len(el) >= before:
                    el.insert(before, "Our Father (in silence).")
            if ll:
                parts[sec] = {"type": "collect", "label": "Oratio", "lat": "\n".join(ll), "eng": "\n".join(el)}
        elif sec.startswith("Commemoratio") or sec.startswith("Octava"):
            # A commemoration carried by the office file itself (DO
            # "add commemorated from winner"): "!title / Ant. / ℣℟ / Oratio".
            parts[sec] = {"type": "commemoration", "label": "Commemoratio", "lat": lat.strip(), "eng": eng.strip()}
        elif sec in ("Rule", "Doxology", "Name"):
            parts[sec] = {"type": "rubric", "lat": lat.strip(), **({"eng": eng.strip()} if sec == "Name" and eng.strip() else {})}
    return {"parts": parts, "psalmi": psalmi}


def build_propers(propers):
    """The Office sections of every Sancti/Tempora file as DO resolves them
    for one rite: { "sancti:01-21" | "tempora:adv1-0": {"parts", "psalmi"} }."""
    out = {}
    for path, secs in propers.items():
        d, f = path.split("/", 1)
        # "Sancti/01-06.txt@01-13": the file as read on another day
        f, _, ctx = f.partition("@")
        base = f[:-4] + ("@" + ctx if ctx else "")
        key = {"Sancti": "sancti:" + base, "Tempora": "tempora:" + base.lower()}.get(d, base)
        ent = convert_office_sections(secs)
        if ent["parts"] or ent["psalmi"]:
            out[key] = ent
    return out


def office_key(path):
    """DO file path -> app office key: Sancti/06-06.txt -> sancti:06-06,
    Tempora/Pent02-0r.txt -> tempora:pent02-0r, Commune/C4.txt -> C4."""
    if not path:
        return None
    p = path.strip()
    if p.endswith(".txt"):
        p = p[:-4]
    d, _, f = p.partition("/")
    if d == "Sancti":
        return "sancti:" + f
    if d == "Tempora":
        return "tempora:" + f.lower()
    if d == "Commune":
        return f
    return p


def build_ordo(ordo):
    """DO's precedence per date: the office of the day (l) and of Vespers (v)."""
    out = {}
    for date, ent in ordo.items():
        rec = {}
        for h, short in (("laudes", "l"), ("vespera", "v")):
            e = ent.get(h) or {}
            if "error" in e or not e.get("winner"):
                continue
            o = {"w": office_key(e["winner"]), "r": e.get("rank", 0), "d": e.get("dayname0") or "",
                 "n": (e.get("dayname1") or "").replace("\t", " ").strip()}
            if e.get("monthday"):
                o["md"] = "tempora:" + e["monthday"].lower()
            if e.get("commune"):
                o["c"] = office_key(e["commune"])
            if e.get("communetype"):
                o["t"] = e["communetype"]
            if e.get("laudes"):
                o["ls"] = int(e["laudes"])
            o["dx"] = int(e.get("duplex") or 3)
            if e.get("hy"):
                o["hy"] = int(e["hy"])
            if e.get("transfervigil"):
                o["tv"] = office_key(e["transfervigil"])
            # The September Ember Saturday: no vigil commemoration (DO vigilia_commemoratio).
            if re.search(r"Quattuor Temporum Sept", e.get("trank0") or ""):
                o["qt"] = True
            if short == "v":
                o["vs"] = int(e.get("vespera") or 3)
                # The concurrent office DO commemorates at Vespers (its
                # $cwinner; empty when the concurrence yields none).
                if e.get("cwinner"):
                    o["cv"] = office_key(e["cwinner"])
                # DO $octvespera: which Vespers an octave's commemoration takes.
                if e.get("octvespera"):
                    o["ov"] = int(e["octvespera"])
                # Tomorrow's commemorations printed at I Vespers (ind 1).
                cm1 = [office_key(c) for c in (e.get("ccommemoentries") or []) if c]
                if cm1:
                    o["cm1"] = cm1
                # "A capitulo de sequenti": the psalms and antiphons of the preceding office.
                ac = e.get("antecapitulum") or ""
                if ac.strip():
                    m5 = re.search(r"Psalm5 VesperaAnte=(\S+)", ac)
                    lines = conv_psalmi("\n".join(l for l in ac.split("\n") if not l.startswith("Psalm5")), "")
                    if lines:
                        o["ac"] = lines
                    if m5:
                        o["ac5"] = m5.group(1)
            # DO $commemoratio: the first commemorated office (governs the suffrage).
            if e.get("commemoratio"):
                o["co"] = office_key(e["commemoratio"])
            # DO's own filtered list for the hour (@commemoentries).
            cm = [office_key(c) for c in (e.get("commemoentries") or []) if c]
            if cm:
                o["cm"] = cm
            rec[short] = o
        for src, short in (("md0", "m0"), ("md1", "m1")):
            if ent.get(src):
                rec[short] = "tempora:" + ent[src].lower()
        if rec:
            out[date] = rec
    return out


def build_commune(commune):
    """Every Commune file resolved by DO (includes expanded), with the
    Office sections converted to app parts: { code: {"parts": {...}, "psalmi": {...}} }.
    Lessons, Matins responsories and the Mass stay in commune_office.json."""
    out = {}
    for fname, secs in commune.items():
        code = fname[:-4]
        parts, psalmi = {}, {}
        for sec, lv in secs.items():
            lat = lv.get("lat") or ""
            eng = lv.get("eng") or ""
            if not lat.strip() and not sec.startswith("Commemoratio"):
                continue
            if sec in ("Ant Matutinum", "Ant Laudes", "Ant Vespera", "Ant Vespera 3"):
                psalmi[sec] = conv_psalmi(lat, eng)
            elif re.match(r"^Ant [123]", sec) or sec == "Invit" or re.match(r"^Ant (Prima|Tertia|Sexta|Nona|Completorium)", sec):
                p = conv_antiphon(lat, eng)
                if p:
                    parts[sec] = p
            elif sec.startswith("Hymnus"):
                if "M " in sec + " " and re.search(r"HymnusM|Hymnus1M", sec):
                    continue
                p = conv_hymn(lat, eng)
                if p:
                    parts[sec] = p
            elif sec.startswith("Capitulum") or sec == "Lectio Prima":
                p = conv_capitulum(lat, eng)
                if sec == "Lectio Prima":
                    p["type"] = "reading"
                    p["label"] = "Lectio brevis"
                parts[sec] = p
            elif sec.startswith("Versum") or sec.startswith("Nocturn"):
                p = conv_versicle(lat, eng)
                if p:
                    parts[sec] = p
            elif sec.startswith("Responsory Breve"):
                p = conv_responsory(lat, eng)
                if p:
                    parts[sec] = p
            elif sec.startswith("Oratio") and re.match(r"^Oratio( [123W])?$", sec):
                lat, eng, emb = split_embedded_commemoratio(lat, eng)
                if emb:
                    parts[sec + " Commemoratio"] = {"type": "commemoration", "label": "Commemoratio", "lat": emb[0], "eng": emb[1]}
                skip = lambda l: l.startswith("$") or l.startswith("!") or l.startswith("/:") or (l.startswith("&") and not l.startswith("&psalm("))
                ll = [re.sub(r"^v\.\s*", "", l) for l in lines_of(lat) if not skip(l)]
                el = [re.sub(r"^v\.\s*", "", l) for l in lines_of(eng) if not skip(l)]
                if ll:
                    parts[sec] = {"type": "collect", "label": "Oratio", "lat": "\n".join(ll), "eng": "\n".join(el)}
            elif sec == "Rule":
                parts[sec] = {"type": "rubric", "lat": lat.strip()}
        out[code] = {"parts": parts, "psalmi": psalmi}
    return out


def build_rules(rules_by_rite):
    out = {}
    for rite, data in rules_by_rite.items():
        m = {}
        for path, ent in data.items():
            rankline = (ent.get("Rank") or "").strip().split("\n")[0]
            parts = rankline.split(";;")
            rec = {}
            if rankline:
                rec["rankLine"] = rankline
            if len(parts) >= 3:
                rec["rankName"] = parts[1].strip()
                try:
                    rec["rank"] = float(parts[2].strip())
                except ValueError:
                    pass
                if len(parts) >= 4:
                    mm = re.match(r"^\s*(ex|vide)\s*(.*)$", parts[3].strip(), re.I)
                    if mm:
                        rec["communeType"] = mm.group(1).lower()
                        rec["commune"] = norm_commune(mm.group(2))
            rule = (ent.get("Rule") or "").strip()
            if rule:
                rec["rule"] = rule
            if rec:
                m[key_for(path)] = rec
        out[rite] = m
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--psalt", required=True)
    ap.add_argument("--psalt-sat", help="the same dump made with DO_DOW=6")
    ap.add_argument("--psalt-variant", nargs="*", default=[], help="rite=path[,satpath]: the psalter as another rite resolves it; differing keys are stored as 'key|rite'")
    ap.add_argument("--ants", help="dodump.pl ... ants output")
    ap.add_argument("--commune", help="dodump.pl ... commune output")
    ap.add_argument("--propers", nargs="*", default=[], help="rite=path ... (dodump.pl ... propers)")
    ap.add_argument("--ordo", nargs="*", default=[], help="rite=path ... (dodump.pl ... ordo)")
    ap.add_argument("--rules", nargs="+", required=True, help="rite=path ...")
    a = ap.parse_args()
    psalt = json.load(open(a.psalt, encoding="utf-8"))
    ps = build_psalterium(psalt)
    if a.psalt_sat:
        add_saturday_variants(ps, json.load(open(a.psalt_sat, encoding="utf-8")))
    for spec in a.psalt_variant:
        rite, _, paths = spec.partition("=")
        vp = paths.split(",")
        vps = build_psalterium(json.load(open(vp[0], encoding="utf-8")))
        if len(vp) > 1:
            add_saturday_variants(vps, json.load(open(vp[1], encoding="utf-8")))
        for k, v in vps["parts"].items():
            if ps["parts"].get(k) != v:
                ps["parts"][k + "|" + rite] = v
        for k, v in vps["psalmi"].items():
            if ps["psalmi"].get(k) != v:
                ps["psalmi"][k + "|" + rite] = v
    ants = build_ants(json.load(open(a.ants, encoding="utf-8"))) if a.ants else None
    commune_raw = json.load(open(a.commune, encoding="utf-8")) if a.commune else {}
    propers_raw = {r.split("=", 1)[0]: json.load(open(r.split("=", 1)[1], encoding="utf-8")) for r in a.propers}

    def lookup_for(rite):
        def lookup(path):
            f = path if path.endswith(".txt") else path + ".txt"
            if f.startswith("Commune/"):
                return commune_raw.get(f[len("Commune/"):]) or commune_raw.get(f)
            return propers_raw.get(rite, {}).get(f)
        return lookup
    expand_refs(commune_raw, lookup_for(a.propers[0].split("=", 1)[0] if a.propers else ""))
    for rite, raw in propers_raw.items():
        expand_refs(raw, lookup_for(rite))
    commune = build_commune(commune_raw) if a.commune else None
    propers = {rite: build_propers(raw) for rite, raw in propers_raw.items()}
    ordos = {r.split("=", 1)[0]: build_ordo(json.load(open(r.split("=", 1)[1], encoding="utf-8"))) for r in a.ordo}
    rules = build_rules({r.split("=", 1)[0]: json.load(open(r.split("=", 1)[1], encoding="utf-8")) for r in a.rules})
    for out in OUTS:
        (out / "office_psalterium.json").write_text(json.dumps(ps, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
        (out / "office_rules.json").write_text(json.dumps(rules, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
        if ants is not None:
            (out / "office_ants.json").write_text(json.dumps(ants, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
        if commune is not None:
            (out / "office_commune.json").write_text(json.dumps(commune, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
        for rite, data in propers.items():
            (out / f"office_propers_{rite}.json").write_text(json.dumps(data, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
        for rite, data in ordos.items():
            (out / f"office_ordo_{rite}.json").write_text(json.dumps(data, ensure_ascii=False, separators=(",", ":")) + "\n", encoding="utf-8")
    print("ants:", len(ants or {}))
    print("parts:", len(ps["parts"]), "psalmi:", len(ps["psalmi"]),
          "rules:", {k: len(v) for k, v in rules.items()})


if __name__ == "__main__":
    main()
