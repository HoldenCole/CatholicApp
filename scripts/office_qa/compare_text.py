#!/usr/bin/env python3
"""Line-level comparison of the app's assembled hours against Divinum
Officium's rendered text — the whole sequence of what a user reads, not the
structural features compare.py checks.

The app side is the SpanishAuditDump / OfficeJsonDump JSON (parts); it is
flattened the way the hour views render each part type (antiphon before and
after its psalms, hymn stanzas, ℣./℟. pairs, ...). The DO side is the
do_extract.py sections. Both are reduced to normalised line signatures and
aligned with difflib; the lines only one side has are classified and
counted over the whole corpus, so systematic omissions (a Glória Patri, an
Amen, an Orémus, the invitatory woven into the Venite) stand out from
one-off text variants.

    python3 scripts/office_qa/compare_text.py --app DIR --do DIR --rites 1962,1955,pre1955 [--step 3] [--hours laudes,prima]
"""
import argparse, collections, difflib, glob, json, os, re, sys
sys.path.insert(0, os.path.dirname(__file__))
from compare import norm, strip_num  # noqa: E402

PSALM_TYPES = ("psalm", "canticle")
MARK = re.compile(r"^(?:℣\.|℟\.|V\.|R\.|R\.br\.|Ant\.|Absolutio\.|Benedictio\.)\s*")

def sig(line):
    """Normalised signature of a line: markers and verse numbers dropped, first 7 words."""
    l = MARK.sub("", strip_num(line.strip()))
    l = re.sub(r"\s*\*\s*", " ", l).replace("‡", "").replace("†", "")
    l = re.sub(r"\((?:genuflectitur|fit reverentia)\)", "", l)
    return " ".join(norm(l).split()[:7])

# ---------------- DO side ----------------
RUBRIC_RE = re.compile(r"^(Psalmus \d|Canticum .*\[\d+\]$|Canticum [A-Z][a-zæ]+$|Ad Nocturnum|In [IV]+\.? Noct|Hymnus$|Reliqua omittuntur|Pater Noster dicitur|Dicitur|secreto$|Deinde,|Si Matutinum|Secus absolute|[A-Z][a-z]+\.? \d+:\d+(-\d+)?$|[A-Z][a-z]+ \d+:\d+-\d+:\d+$|Luc\. |Isa |Nunc dimittis$)")

def do_lines(sections):
    out = []
    for sec in sections:
        for l in sec["lines"]:
            l = l.strip()
            if not l or RUBRIC_RE.match(l):
                continue
            out.append(l)
    return out

# ---------------- app side ----------------
def split_lines(s):
    return [x.strip() for x in re.split(r"<br\s*/?>|\n", s or "") if x.strip()]

def whole(a):
    return re.sub(r"\s*\*\s*", " ", a).strip()

def app_lines(parts):
    out = []
    # antiphon runs (AntiphonPlacement.runs)
    repeats = {}
    head = -1; lat = None
    for i, p in enumerate(parts):
        nxt = parts[i + 1] if i + 1 < len(parts) else None
        t = p.get("type")
        if t == "antiphon":
            head = -1; lat = None
            opens = nxt is not None and nxt.get("type") in PSALM_TYPES and not nxt.get("ant")
            if opens and p.get("vk") != "invit" and (p.get("lat") or "").strip():
                head = i; lat = p["lat"]
        elif t in PSALM_TYPES:
            if p.get("ant"): head = i; lat = p["ant"]
            if lat:
                cont = nxt is not None and nxt.get("type") in PSALM_TYPES and not nxt.get("ant")
                if not cont:
                    literal = nxt is not None and nxt.get("type") == "antiphon" and sig(nxt.get("lat") or "") == sig(lat)
                    if not literal: repeats[i] = lat
                    head = -1; lat = None
        else:
            head = -1; lat = None
    for i, p in enumerate(parts):
        t = p.get("type")
        if t == "vr":
            if p.get("lat"): out += split_lines(p["lat"])
            if p.get("latR"): out += split_lines(p["latR"])
        elif t in ("hymn", "pater", "confiteor", "antiphon", "collect", "closing", "capitulum", "reading", "lectio", "responsory_breve", "preces", "marian", "invitatory"):
            if t == "marian" and p.get("title"): pass
            if p.get("lat"): out += ["Ant. " + p["lat"]] if t == "antiphon" else split_lines(p["lat"])
            if p.get("verses"):
                out += [v["lat"] if isinstance(v, dict) else v for v in p["verses"]]
        elif t in PSALM_TYPES:
            if p.get("ant"): out.append("Ant. " + p["ant"])
            for v in p.get("verses") or []:
                out.append(v["lat"] if isinstance(v, dict) else v)
            if i in repeats: out.append("Ant. " + whole(repeats[i]))
        elif t == "responsory":
            if p.get("v1Lat"):
                for k in ("v1Lat", "r1Lat", "v2Lat", "r2Lat"):
                    if p.get(k): out.append(p[k])
            elif p.get("lat"):
                out += split_lines(p["lat"])
        elif t == "heading":
            if p.get("label"): out.append(p["label"])
        # doxology / suppressed: nothing rendered
    return [l for l in out if l.strip()]

# ---------------- classification ----------------
def classify(line):
    n = norm(MARK.sub("", strip_num(line)))
    rules = [
        ("gloria patri", "Glória Patri / Sicut erat"), ("sicut erat", "Glória Patri / Sicut erat"),
        ("amen", "Amen"), ("oremus", "Orémus"), ("deo gratias", "Deo grátias"),
        ("domine exaudi", "Dómine, exáudi / Et clamor"), ("et clamor", "Dómine, exáudi / Et clamor"),
        ("dominus uobiscum", "Dóminus vobíscum"), ("et cum spiritu", "Dóminus vobíscum"),
        ("pater noster", "Pater noster"), ("aue maria", "Ave María"), ("credo in deum", "Credo"),
        ("et ne nos inducas", "Et ne nos indúcas / Sed líbera"), ("sed libera nos", "Et ne nos indúcas / Sed líbera"),
        ("alleluia", "Allelúja"), ("iube domne", "Jube, domne / Benedíctio"), ("iube domine", "Jube, domne / Benedíctio"),
        ("tu autem", "Tu autem"), ("kyrie", "Kýrie"), ("christe eleison", "Kýrie"),
        ("benedicamus domino", "Benedicámus / Fidélium"), ("fidelium animae", "Benedicámus / Fidélium"),
        ("deus in adiutorium", "Deus in adjutórium"), ("domine ad adiuuandum", "Deus in adjutórium"),
        ("uenite adoremus", "Invitatory (Veníte adorémus)"), ("regem", "Ant. (other)"),
        ("requiem aeternam", "Réquiem ætérnam"), ("et lux perpetua", "Réquiem ætérnam"),
        ("diuinum auxilium", "Divínum auxílium"), ("benedicat et custodiat", "Benedícat / Noctem quiétam"), ("noctem quietam", "Benedícat / Noctem quiétam"),
        ("conuerte nos", "Convérte nos"), ("et auerte iram", "Convérte nos"),
        ("sancta maria", "Marian antiphon ℣/℟"),
    ]
    if line.startswith("Ant."): return "Ant. (other)"
    if MARK.match(line) and MARK.match(line).group(0).startswith(("℣", "V")): kind = "℣ "
    elif MARK.match(line) and MARK.match(line).group(0).startswith(("℟", "R")): kind = "℟ "
    else: kind = ""
    for pre, lab in rules:
        if n.startswith(pre): return lab
    return "other: " + kind + " ".join(n.split()[:4])

def align(do_l, app_l):
    ds = [sig(l) for l in do_l]; as_ = [sig(l) for l in app_l]
    sm = difflib.SequenceMatcher(None, ds, as_, autojunk=False)
    do_only, app_only, changed = [], [], []
    for tag, i1, i2, j1, j2 in sm.get_opcodes():
        if tag == "equal": continue
        if tag == "delete": do_only += do_l[i1:i2]
        elif tag == "insert": app_only += app_l[j1:j2]
        else:
            # pair up inside a replace block by similarity
            dl = do_l[i1:i2]; al = app_l[j1:j2]
            used = set()
            for d in dl:
                best, bi = 0.0, -1
                for k, a in enumerate(al):
                    if k in used: continue
                    r = difflib.SequenceMatcher(None, sig(d), sig(a)).ratio()
                    if r > best: best, bi = r, k
                if best >= 0.6:
                    used.add(bi); changed.append((d, al[bi]))
                else:
                    do_only.append(d)
            app_only += [a for k, a in enumerate(al) if k not in used]
    return do_only, app_only, changed

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--app", required=True); ap.add_argument("--do", required=True)
    ap.add_argument("--rites", default="1962,1955,pre1955"); ap.add_argument("--step", type=int, default=1)
    ap.add_argument("--hours", default="matutinum,laudes,prima,tertia,sexta,nona,vesperae,completorium")
    ap.add_argument("--top", type=int, default=45); ap.add_argument("--show", default=None, help="rite:date:hour — print the diff of one hour")
    a = ap.parse_args()
    hours = a.hours.split(",")
    if a.show:
        rite, date, hour = a.show.split(":")
        appd = json.load(open(f"{a.app}/{rite}/{date}.json"))
        hp = appd["hours"][hour]; hp = hp["parts"] if isinstance(hp, dict) else hp
        dod = json.load(open(f"{a.do}/{rite}/{date}/{hour}.json"))
        d, ap_, ch = align(do_lines(dod["sections"]), app_lines(hp))
        print("--- DO only"); [print("  ", l[:120]) for l in d]
        print("--- APP only"); [print("  ", l[:120]) for l in ap_]
        print("--- changed"); [print("  DO :", x[:100], "\n  APP:", y[:100]) for x, y in ch]
        return
    for rite in a.rites.split(","):
        files = sorted(glob.glob(f"{a.app}/{rite}/*.json"))[::a.step]
        do_only = collections.defaultdict(collections.Counter); app_only = collections.defaultdict(collections.Counter)
        ex = {}; n = 0; changed_c = collections.Counter(); chex = {}
        for f in files:
            date = os.path.basename(f)[:-5]
            appd = json.load(open(f))
            for hour in hours:
                dp = f"{a.do}/{rite}/{date}/{hour}.json"
                if hour not in appd["hours"] or not os.path.exists(dp): continue
                hp = appd["hours"][hour]; hp = hp["parts"] if isinstance(hp, dict) else hp
                dod = json.load(open(dp))
                d, ap_, ch = align(do_lines(dod["sections"]), app_lines(hp)); n += 1
                for l in d:
                    c = classify(l); do_only[hour][c] += 1; ex.setdefault(("do", hour, c), (date, l[:90]))
                for l in ap_:
                    c = classify(l); app_only[hour][c] += 1; ex.setdefault(("app", hour, c), (date, l[:90]))
                for x, y in ch:
                    k = (hour, sig(x)[:40]); changed_c[k] += 1; chex.setdefault(k, (date, x[:80], y[:80]))
        print(f"\n######## {rite}: {n} hours compared ({len(files)} days)")
        for hour in hours:
            tot = sum(1 for f in files)
            print(f"\n== {hour} — DO lines the app lacks (count over {tot} days)")
            for c, k in do_only[hour].most_common(a.top):
                print(f"  {k:5d}  {c:45s} e.g. {ex[('do', hour, c)][0]} | {ex[('do', hour, c)][1]}")
            print(f"== {hour} — app lines DO lacks")
            for c, k in app_only[hour].most_common(a.top):
                print(f"  {k:5d}  {c:45s} e.g. {ex[('app', hour, c)][0]} | {ex[('app', hour, c)][1]}")
        print(f"\n== {rite} most frequent changed lines (text differs, same place)")
        for k, c in changed_c.most_common(a.top):
            print(f"  {c:5d} {k[0]:12s} {chex[k][0]} | DO: {chex[k][1]} || APP: {chex[k][2]}")

if __name__ == "__main__":
    main()
