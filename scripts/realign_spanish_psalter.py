#!/usr/bin/env python3
"""Re-cut the Spanish Psalter (Torres Amat) at the Latin breviary's verse
boundaries.

spanish-translation/psalter_es.json was composed verse by verse from a
KJV-versified Torres Amat module; where the module's numbering drifts from
the Vulgate's, or where one Vulgate verse spans several breviary lines, the
Spanish of a line carries the tail of the previous Latin line or the head
of the next, and a few lines are fragments ("76:6 Y").

This tool keeps every Spanish word and only moves the line breaks: for each
psalm it joins the Spanish lines back into the continuous Torres Amat text,
splits that at clause boundaries, and chooses the partition into as many
segments as the psalm has Latin lines that best matches, line by line,
Divinum Officium's own Spanish psalter (a modern translation that IS cut at
the breviary's verses, used here only as an alignment guide, never as text)
and the Latin lines' relative lengths. The mediant (*) and flex (†) are then
re-placed at the clause boundary that best mirrors the guide's halves.

Only psalms whose new cut scores better than the old one are rewritten; the
--report lists what changed. The same Spanish lines are then propagated to
every other overlay that quotes the psalter's Latin (the hours' fixed
psalms, the weekly psalter, the commons and the propers' psalm verses).

  python3 scripts/realign_spanish_psalter.py [--do DIR] [--report] [--dry]
"""
import json, os, re, sys, unicodedata
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / "android" / "app" / "src" / "main" / "assets"
ES = ROOT / "spanish-translation"
DEFAULT_DO = Path("/tmp/claude-0/-home-user-CatholicApp/71906fbb-67e9-553f-b996-d8565178e126/scratchpad/do_repo")

REF_RE = re.compile(r"^(\(?\d+[a-z]?:\d+[a-z]?\)?\s+)")
STOP = set("""a al ante bajo con contra de del desde en entre hacia hasta para por segun sin sobre tras y e o u ni que
el la los las lo un una unos unas su sus mi mis tu tus se le les me te nos os yo tu el ella ellos ellas nosotros vosotros
es son era fue ha han he has hay ser estar este esta estos estas ese esa esos esas aquel aquella como cuando donde mas pero
si no ya oh porque pues asi aun tan muy todo toda todos todas cual cuales quien quienes""".split())


def load(p):
    return json.load(open(p, encoding="utf-8"))


def dump(p, obj):
    txt = open(p, encoding="utf-8").read()
    indent = 2 if txt.startswith('{\n  "') else 1
    with open(p, "w", encoding="utf-8") as f:
        json.dump(obj, f, ensure_ascii=False, indent=indent)
        f.write("\n")


def strip_accents(s):
    s = unicodedata.normalize("NFD", s)
    return "".join(c for c in s if unicodedata.category(c) != "Mn")


def words(s):
    s = strip_accents(s.lower())
    out = []
    for w in re.findall(r"[a-zñ]+", s):
        if w in STOP or len(w) < 3:
            continue
        out.append(w[:5])  # a crude stem: modern and 19th-c. forms share it
    return out


def sim(a, b):
    """Dice coefficient over stemmed content words."""
    wa, wb = words(a), words(b)
    if not wa or not wb:
        return 0.0
    ca, cb = {}, {}
    for w in wa:
        ca[w] = ca.get(w, 0) + 1
    for w in wb:
        cb[w] = cb.get(w, 0) + 1
    inter = sum(min(ca[w], cb.get(w, 0)) for w in ca)
    return 2 * inter / (len(wa) + len(wb))


def split_ref(line):
    m = REF_RE.match(line)
    return (m.group(1), line[m.end():]) if m else ("", line)


def plain(t):
    """The Spanish/Latin text without marks."""
    t = t.replace("†", " ").replace("*", " ").replace("+", " ")
    return re.sub(r"\s+", " ", t).strip()


CLAUSE_RE = re.compile(r"(?<=[,;:.?!])\s+|\s+(?=[¡¿])|(?<=[.?!])\s*(?=[«“])")


def clauses(text):
    text = re.sub(r"([.;:?!])(?=[A-ZÁÉÍÓÚÑ¡¿«“])", r"\1 ", text)  # "él.A ti"
    parts = [p.strip() for p in CLAUSE_RE.split(text) if p and p.strip()]
    return parts


def fold_lat(t):
    t = re.sub(r"\(\d+[a-z]?\)", " ", split_ref(t)[1])
    t = strip_accents(plain(t).lower())
    t = t.replace("æ", "ae").replace("œ", "oe").replace("j", "i").replace("v", "u")
    return re.sub(r"[^a-z0-9 ]+", " ", t).strip()


# ---- the Torres Amat module (theWord .ont: one verse per line, KJV order) ----
KJV_BOOKS = None


def load_module(ont_path, kjv_dir):
    """{(book, chapter): [verse texts]} from the module and the KJV structure."""
    raw = open(ont_path, encoding="utf-8-sig").read()
    lines = [re.sub(r"<[^>]+>", "", l.rstrip("\r")).strip() for l in raw.split("\n")]
    books = json.load(open(Path(kjv_dir) / "Books.json", encoding="utf-8"))
    out = {}
    i = 0
    for b in books:
        d = json.load(open(Path(kjv_dir) / (b.replace(" ", "") + ".json"), encoding="utf-8"))
        for ch in d["chapters"]:
            n = len(ch["verses"])
            out[(b, int(ch["chapter"]))] = lines[i:i + n]
            i += n
    return out


def kjv_psalm_chapters(v):
    """The KJV chapter(s) holding Vulgate psalm v."""
    if v <= 8 or v >= 148:
        return [v]
    if v == 9:
        return [9, 10]
    if v <= 112:
        return [v + 1]
    if v == 113:
        return [114, 115]
    if v in (114, 115):
        return [116]
    if v <= 145:
        return [v + 1]
    return [147]  # 146, 147


CANTICLE_BOOKS = {"Exod.": "Exodus", "Deut": "Deuteronomy", "3 Reg": "1 Samuel", "1 Par.": "1 Chronicles",
                  "Isa": "Isaiah", "Jer": "Jeremiah", "Thren.": "Lamentations", "Ez": "Ezekiel", "Osea": "Hosea",
                  "Hab": "Habakkuk", "Soph": "Zephaniah", "Prov.": "Proverbs", "Luc.": "Luke"}


def source_verses(module, key, title, lat_lines):
    """[(ref, text)] of the Torres Amat verses covering a psalter entry, or
    None when the module (KJV canon) lacks the book."""
    m = re.fullmatch(r"psalm(\d+)(c?)", key)
    if m and int(m.group(1)) <= 150:
        # the module's verse boundaries drift by a line here and there, so
        # take two verses of margin on either side; the alignment skips them
        chs = kjv_psalm_chapters(int(m.group(1)))
        out = []
        if chs[0] > 1:
            out += [(f"{chs[0] - 1}:{i}", t, True) for i, t in enumerate(module[("Psalms", chs[0] - 1)][-2:])]
        for ch in chs:
            out += [(f"{ch}:{i + 1}", t, False) for i, t in enumerate(module[("Psalms", ch)])]
        if chs[-1] < 150:
            out += [(f"{chs[-1] + 1}:{i + 1}", t, True) for i, t in enumerate(module[("Psalms", chs[-1] + 1)][:2])]
        return out
    mt = re.search(r"\*\s*([^*]+?)\s+(\d+):", title or "")
    book = CANTICLE_BOOKS.get(mt.group(1).strip()) if mt else None
    if not book:
        return None
    refs = [split_ref(l)[0].strip() for l in lat_lines if REF_RE.match(l)]
    chapters = sorted({int(r.split(":")[0]) for r in refs})
    out = []
    for ch in chapters:
        verses = module.get((book, ch))
        if not verses:
            return None
        vs = [int(re.sub(r"\D", "", r.split(":")[1])) for r in refs if int(r.split(":")[0]) == ch]
        lo, hi = max(1, min(vs) - 1), min(max(vs) + 1, len(verses))
        for v in range(lo, hi + 1):
            out.append((f"{ch}:{v}", verses[v - 1], v < min(vs) or v > max(vs)))
    return out


def skeleton(w, latin):
    """A consonant skeleton shared by Latin and its Spanish descendants:
    populus/pueblo -> bbl, tenebris/tinieblas -> dnb, lucem/luz -> ls."""
    w = strip_accents(w.lower())
    for a, b in (("ph", "f"), ("qu", "c"), ("ch", "c"), ("ll", "l"), ("ñ", "n"), ("æ", "e"), ("œ", "e")):
        w = w.replace(a, b)
    out = []
    for ch in w:
        ch = {"v": "b", "p": "b", "k": "c", "g": "c", "q": "c", "z": "s", "x": "s", "t": "d",
              "j": "", "h": "", "y": "", "w": "b"}.get(ch, ch)
        if ch and ch not in "aeiou":
            if not out or out[-1] != ch:
                out.append(ch)
    return "".join(out)


def cognate_sim(seg, lat):
    """Latin-Spanish cognate overlap: 4-letter stems plus 3-consonant skeletons."""
    def stems(t, latin):
        t = strip_accents(t.lower()).replace("æ", "e").replace("œ", "e").replace("ae", "e").replace("oe", "e")
        t = t.replace("ph", "f").replace("th", "t").replace("ch", "c").replace("qu", "c").replace("ñ", "n")
        t = t.replace("v", "b").replace("j", "i").replace("y", "i").replace("h", "")
        t = re.sub(r"([a-z])\1", r"\1", t)  # double consonants
        return {w[:4] for w in re.findall(r"[a-z]+", t) if len(w) >= 4 and w not in STOP}

    def skels(t, latin):
        ws = [w for w in re.findall(r"[a-záéíóúñæœ]+", strip_accents(t.lower()) if False else t.lower()) if len(w) >= 3]
        return {skeleton(w, latin)[:3] for w in ws if len(skeleton(w, latin)) >= 3 and strip_accents(w) not in STOP}
    a, b = stems(seg, False), stems(lat, True)
    sa, sb = skels(seg, False), skels(lat, True)
    s1 = 2 * len(a & b) / (len(a) + len(b)) if a and b else 0.0
    s2 = 2 * len(sa & sb) / (len(sa) + len(sb)) if sa and sb else 0.0
    return max(s1, s2)


def best_partition(cl, guide, lat_lens, lat_texts=None, skip_ends=False, margin=None, title_verses=False, neighbours=None):
    """Partition the clauses into K = len(guide) contiguous non-empty
    segments, in order, maximising the summed affinity of each clause for
    its line (Spanish guide similarity + Latin cognates) under a prior on
    the lines' relative lengths. With skip_ends, clauses at either end that
    fit no line (a title, the next psalm's opening) may be left out."""
    K = len(guide)
    n = len(cl)
    if n < K:
        return None
    margin = margin or [False] * n
    total_lat = sum(lat_lens) or 1
    total_es = sum(len(c) for c, m in zip(cl, margin) if not m) or 1
    pre = [0]
    for c, m in zip(cl, margin):
        pre.append(pre[-1] + (0 if m else len(c) + 1))
    BASE = 0.10   # a clause must earn this much affinity to be worth including
    MARGIN = 1.0  # ... a neighbouring psalm's verse much more
    SKIP = 0.04   # ... else skipping it at an end is cheaper
    # affinity prefix sums per line
    aff = []
    for k in range(K):
        row = [0.0]
        for c in cl:
            a = 0.0
            if guide[k]:
                a += 2.0 * sim(c, guide[k])
            if lat_texts:
                a += 2.0 * cognate_sim(c, lat_texts[k])
            row.append(a)
        aff.append(row)
    # a margin clause that belongs to a nearby line is not margin (the
    # module's verse boundaries drift by a line here and there): it fits
    # this psalm's first/last line better than the neighbouring psalm's
    # last/first line (when that neighbour is known), else clearly enough
    for c in range(n):
        if margin[c]:
            before = c < n // 2
            near = range(0, min(2, K)) if before else range(max(0, K - 2), K)
            mine = max(aff[k][c + 1] for k in near)
            other = None
            if neighbours:
                g_o, l_o = neighbours[0] if before else neighbours[1]
                if g_o or l_o:
                    other = (2 * sim(cl[c], g_o) if g_o else 0.0) + (2 * cognate_sim(cl[c], l_o) if l_o else 0.0)
            if (other is not None and mine > other and mine >= 0.3) or (other is None and mine >= 1.2):
                margin[c] = False
    total_es = sum(len(c) for c, m in zip(cl, margin) if not m) or 1
    pre = [0]
    for c, m in zip(cl, margin):
        pre.append(pre[-1] + (0 if m else len(c) + 1))
    for k in range(K):
        row = [0.0]
        for c in range(n):
            row.append(row[-1] + aff[k][c + 1] - (MARGIN if margin[c] else BASE))
        aff[k] = row

    # cutting after a comma (or no punctuation) is dispreferred
    cutpen = [0.0 if re.search(r"[.;:?!»”)]\s*$", c) else 0.3 for c in cl]

    def score(k, i, j):
        ratio_es = (pre[j] - pre[i]) / total_es
        ratio_lat = lat_lens[k] / total_lat
        return aff[k][j] - aff[k][i] - 0.3 * K * abs(ratio_es - ratio_lat) - cutpen[j - 1]

    NEG = -1e9
    dp = [[NEG] * (n + 1) for _ in range(K + 1)]
    back = [[-1] * (n + 1) for _ in range(K + 1)]
    dp[0][0] = 0.0
    TITLE_RE = re.compile(r"^(Salmo|Cántico|Canción|Himno|Oración|Alabanza|Instrucción|Inscripción|Para |Al |A los hijos|De David|Del mismo|Súplica|Alfabeto|Poema|Meditación|Salmodia|Cuando|En memoria|Sobre |Con ocasión|Con motivo|Después que|Al tiempo|Título)")
    # The breviary omits the psalm's title verses; the module keeps their
    # text at the head of the first verse. When the first Latin ref is not
    # verse 1 and the module's first clause reads like a title, that
    # sentence (and following title-like sentences) may be skipped.
    skippable, in_title, at_start, sentence_end = [], False, True, False
    for ci, (c, m) in enumerate(zip(cl, margin)):
        if m:
            skippable.append(True)
            continue
        if at_start:
            at_start = False
            in_title = title_verses and bool(TITLE_RE.match(c))
        elif not in_title and title_verses and sentence_end and TITLE_RE.match(c):
            in_title = True
        skippable.append(in_title)
        sentence_end = bool(re.search(r"[.?!]\s*$", c))
        if in_title and sentence_end:
            in_title = False
    if skip_ends:
        # only margin (or title) clauses may be left out, at either end
        for j in range(1, n):
            if not all(skippable[:j]):
                break
            dp[0][j] = -SKIP * j
    for k in range(1, K + 1):
        for j in range(k, n + 1):
            best, bi = NEG, -1
            for i in range(max(k - 1, j - 14), j):
                if dp[k - 1][i] == NEG:
                    continue
                v = dp[k - 1][i] + score(k - 1, i, j)
                if v > best:
                    best, bi = v, i
            dp[k][j] = best
            back[k][j] = bi
    end = n
    if skip_ends:
        first_trailing = n
        while first_trailing > 0 and margin[first_trailing - 1]:
            first_trailing -= 1
        end = max(range(max(K, first_trailing), n + 1), key=lambda j: dp[K][j] - SKIP * (n - j))
    if dp[K][end] == NEG:
        return None
    cuts = []
    j = end
    for k in range(K, 0, -1):
        i = back[k][j]
        cuts.append((i, j))
        j = i
    cuts.reverse()
    return [" ".join(cl[i:j]) for i, j in cuts], dp[K][end], cuts


def place_marks(seg, guide_line, lat_line):
    """Put the mediant (and flex) into a Spanish segment mirroring the guide
    line's halves, else the Latin's proportions."""
    lat_body = split_ref(lat_line)[1].replace("‡", "†")
    has_flex = "†" in lat_body
    if "*" not in lat_body:
        return seg
    cl = clauses(seg)
    if len(cl) < 2:
        # a single clause: split at the word boundary nearest the Latin ratio
        ws = seg.split()
        if len(ws) < 6:
            return seg
        star = lat_body.index("*") / max(len(lat_body), 1)
        cut = max(1, min(len(ws) - 1, round(len(ws) * star)))
        BOUND = {"y", "e", "o", "ni", "que", "para", "porque", "mas", "pero", "cuando", "como", "según", "segun", "al", "a", "en", "de", "con", "por", "sobre", "entre", "hasta", "desde", "sin", "mientras", "pues", "sino", "aunque", "si"}
        near = [i for i in range(2, len(ws) - 1) if strip_accents(ws[i].lower().strip("¡¿,;:")) in BOUND and abs(i - cut) <= max(2, len(ws) // 4)]
        if near:
            cut = min(near, key=lambda i: abs(i - cut))
        return " ".join(ws[:cut]) + " * " + " ".join(ws[cut:])
    g_halves = [h.strip() for h in guide_line.split("*")] if guide_line and "*" in guide_line else None
    best, bi = -1e9, 1
    star = lat_body.index("*") / max(len(lat_body), 1)
    total = sum(len(c) + 1 for c in cl)
    acc = 0
    for i in range(1, len(cl)):
        acc += len(cl[i - 1]) + 1
        ratio = acc / total
        v = -abs(ratio - star) * 2
        if not re.search(r"[.;:?!»”)]\s*$", cl[i - 1]):
            v -= 0.3
        if g_halves and len(g_halves) >= 2:
            v += sim(" ".join(cl[:i]), g_halves[0]) + sim(" ".join(cl[i:]), g_halves[-1])
        if v > best:
            best, bi = v, i
    first, second = " ".join(cl[:bi]), " ".join(cl[bi:])
    if has_flex and bi >= 2:
        # the flex: the clause boundary in the first half nearest the Latin's †
        flex = lat_body.index("†") / max(len(lat_body), 1)
        fb, fbest = None, 1e9
        acc = 0
        for i in range(1, bi):
            acc += len(cl[i - 1]) + 1
            d = abs(acc / total - flex)
            if d < fbest:
                fbest, fb = d, i
        if fb:
            first = " ".join(cl[:fb]) + " † " + " ".join(cl[fb:bi])
    return first + " * " + second


def line_score(es_lines, guide, lat_lens):
    """Mean per-line similarity to the guide, and how many lines match their
    own guide line better than a neighbour."""
    tot, own = 0.0, 0
    for k, e in enumerate(es_lines):
        s = sim(plain(e), guide[k])
        tot += s
        nb = max(sim(plain(e), guide[j]) for j in (k - 1, k + 1) if 0 <= j < len(guide)) if len(guide) > 1 else 0
        if s >= nb:
            own += 1
    return tot / max(len(es_lines), 1), own


def read_do_psalm(do_root, key):
    name = "Psalm" + key[len("psalm"):].upper()
    p = do_root / "web/www/horas/Espanol/Psalterium/Psalmorum" / f"{name}.txt"
    if not p.exists():
        return None
    lines = [l.rstrip() for l in open(p, encoding="utf-8").read().splitlines()]
    return [l for l in lines if l.strip()]


def main():
    do_root = Path(sys.argv[sys.argv.index("--do") + 1]) if "--do" in sys.argv else DEFAULT_DO
    report = "--report" in sys.argv
    dry = "--dry" in sys.argv
    only = set(sys.argv[sys.argv.index("--only") + 1].split(",")) if "--only" in sys.argv else None
    show = set(sys.argv[sys.argv.index("--show") + 1].split(",")) if "--show" in sys.argv else None
    propagate_only = "--propagate-only" in sys.argv
    # the psalter as it was before any recomposition: a line the module
    # lacks (its text has gaps) falls back to it when that fits the Latin
    old_es = load(sys.argv[sys.argv.index("--old") + 1]) if "--old" in sys.argv else None
    module = None
    if "--ont" in sys.argv:
        module = load_module(sys.argv[sys.argv.index("--ont") + 1], sys.argv[sys.argv.index("--kjv") + 1])
    psalter = load(ASSETS / "psalter.json")
    es = load(ES / "psalter_es.json")
    changed, kept, skipped, drifted, gaps = [], [], [], [], []
    new_lines_by_key = {}
    for key, entry in psalter.items():
        if propagate_only or (only and key not in only):
            continue
        lat = entry["lat"]
        es_lines = (es.get(key) or {}).get("lines")
        if not es_lines or len(es_lines) != len(lat) or any(l is None for l in es_lines):
            skipped.append((key, "no complete Spanish"))
            continue
        guide = read_do_psalm(do_root, key) or []
        # rows to re-cut: Latin lines with a verse ref (not titles, $ant, rubrics)
        idx = [i for i, l in enumerate(lat) if REF_RE.match(l)]
        if len(idx) < 2:
            skipped.append((key, "single line"))
            continue
        gmap = {}
        gpos = []
        for g in guide:
            ref, body = split_ref(g)
            if ref:
                gmap.setdefault(ref.strip().strip("()"), body.strip())
                gpos.append(body.strip())
        glines = []
        refs = [split_ref(lat[i])[0].strip().strip("()") for i in idx]
        positional = len(gpos) == len(idx) and (len(set(refs)) < len(refs) or any(x not in gmap for x in refs))
        for k, i in enumerate(idx):
            ref = refs[k]
            g = None if positional else gmap.get(ref)
            if g is None and len(gpos) == len(idx):
                g = gpos[k]  # the guide is line-aligned but labels its halves a/b
            if g is None or fold_lat(g) == fold_lat(split_ref(lat[i])[1]):
                g = ""  # no Spanish guide for this line: the length prior decides
            glines.append(g)
        src = source_verses(module, key, lat[0] if not REF_RE.match(lat[0]) else "", lat) if module else None
        if not src and sum(1 for g in glines if g) < max(2, len(idx) // 2):
            skipped.append((key, "guide lacks Spanish"))
            continue
        marg = None
        if src:
            cl, marg = [], []
            for _, t, m in src:
                cs = clauses(t)
                cl.extend(cs)
                marg.extend([m] * len(cs))
        else:
            base = old_es[key]["lines"] if old_es and key in old_es and len(old_es[key].get("lines") or []) == len(lat) else es_lines
            text = " ".join(plain(split_ref(base[i] or "")[1]) for i in idx)
            cl = clauses(text)
        lat_lens = [len(plain(split_ref(lat[i])[1])) for i in idx]
        lat_texts = [plain(split_ref(lat[i])[1]) for i in idx]
        first_ref = split_ref(lat[idx[0]])[0].strip().strip("()")
        title_verses = bool(re.fullmatch(r"\d+:(\d+)[a-z]?", first_ref)) and int(re.fullmatch(r"\d+:(\d+)[a-z]?", first_ref).group(1)) > 1
        marg_orig = list(marg) if marg else None
        neighbours = None
        mnum = re.fullmatch(r"psalm(\d+)c?", key)
        if src and mnum and int(mnum.group(1)) <= 150:
            def edge(k2, last):
                e2 = psalter.get(k2)
                g2 = read_do_psalm(do_root, k2) or []
                if not e2:
                    return ("", "")
                ll = [plain(split_ref(l)[1]) for l in e2["lat"] if REF_RE.match(l)]
                gg = [plain(split_ref(x)[1]) for x in g2 if split_ref(x)[0]]
                lt = (ll[-1] if last else ll[0]) if ll else ""
                gt = (gg[-1] if last else gg[0]) if gg else ""
                if fold_lat(gt) == fold_lat(lt):
                    gt = ""
                return (gt, lt)
            nnum = int(mnum.group(1))
            neighbours = (edge(f"psalm{nnum - 1}", True), edge(f"psalm{nnum + 1}", False))
        res = best_partition(cl, [plain(g) for g in glines], lat_lens, lat_texts, skip_ends=bool(src), margin=marg, title_verses=title_verses, neighbours=neighbours)
        if not res:
            skipped.append((key, "too few clauses"))
            continue
        segs, _, cuts = res
        if src and re.match(r"^[a-záéíóúñ]", segs[0]) and len(segs) > 1:
            # the first segment opens mid-sentence: the tail of the previous
            # psalm (the module's chapter boundary drifted). Mark that
            # sentence's clauses as margin and align again.
            i = cuts[0][0]
            while i < len(cl) and not re.search(r"[.?!]\s*$", cl[i]):
                marg[i] = True
                i += 1
            if i < len(cl):
                marg[i] = True
            marg2 = list(marg)
            res = best_partition(cl, [plain(g) for g in glines], lat_lens, lat_texts, skip_ends=True, margin=marg2, title_verses=title_verses, neighbours=None)
            if res:
                segs, _, cuts = res
                drifted.append((key, "(mid-sentence opening) " + (cl[cuts[0][0] - 1][:40] if cuts[0][0] > 0 else "")))
        if src and not title_verses and len(segs) > 1:
            # the module's chapter boundary drifted: a sentence of the previous
            # psalm heads the first segment. Drop it when it fits the first
            # Latin line far worse than what follows it.
            for _round in range(3):
              m0 = re.match(r"^(.+?[.?!])\s+(?=[A-ZÁÉÍÓÚÑ¡¿«])(.+)$", segs[0])
              if not m0:
                break
              if True:
                  head, rest = m0.group(1), m0.group(2)
                  # junk adds nothing: the rest alone fits the line better
                  g0 = plain(glines[0])
                  if g0:
                      gain = sim(rest, g0) - sim(segs[0], g0)
                      cg = cognate_sim(rest, lat_texts[0]) - cognate_sim(segs[0], lat_texts[0])
                      drop = gain >= 0.05 and cg >= -0.1 and len(words(rest)) >= 3 and sim(rest, g0) > sim(head, g0) + 0.1
                  else:
                      drop = cognate_sim(rest, lat_texts[0]) - cognate_sim(segs[0], lat_texts[0]) >= 0.05
                  # a sentence that begins in lower case is the tail of the previous psalm
                  if re.match(r"^[a-záéíóúñ]", head) and len(words(rest)) >= 3:
                      drop = True
                  if os.environ.get("DRIFT_DEBUG"):
                      print("DRIFT?", key, repr(head[:50]), repr(rest[:50]), "g0=", g0[:50], "sim rest/full", round(sim(rest, g0), 2) if g0 else None, round(sim(segs[0], g0), 2) if g0 else None, "drop", drop)
                  if not drop:
                      break
                  if drop:
                      drifted.append((key, head[:60]))
                      segs[0] = rest
        if src and len(segs) > 1:
            # ... and the mirror at the end: the next psalm's opening sentence
            # glued to the last line by the module's drifting boundary
            gK, lK = plain(glines[-1]), lat_texts[-1]
            g_next = neighbours[1][0] if neighbours and neighbours[1][0] else ""
            last = segs[-1]
            bounds = [m.end() for m in re.finditer(r"[.?!](?=\s+[A-ZÁÉÍÓÚÑ¡¿«])", last)]
            for bpos in bounds:  # the first boundary after which all is the next psalm
                head, tail = last[:bpos].strip(), last[bpos:].strip()
                if len(words(head)) < 3 or len(words(tail)) < 2:
                    continue
                first_tail = re.split(r"(?<=[.?!])\s+", tail)[0]
                if gK:
                    fits_worse = sim(head, gK) >= sim(last, gK) + 0.05 and sim(head, gK) > sim(first_tail, gK) + 0.1
                else:
                    fits_worse = cognate_sim(head, lK) >= cognate_sim(last, lK) + 0.05
                next_fits = bool(g_next) and sim(first_tail, g_next) >= 0.3 and sim(first_tail, g_next) > sim(first_tail, gK) + 0.15
                if fits_worse or next_fits:
                    drifted.append((key, "(trailing) " + tail[:50]))
                    segs[-1] = head
                    break
        if src and (segs[0] != " ".join(cl[cuts[0][0]:cuts[0][1]]) or segs[-1] != " ".join(cl[cuts[-1][0]:cuts[-1][1]])):
            # junk was cut off a segment's text: mark those clauses as margin
            # and align the rest again, so the cuts move back into place
            def mark_missing(seg_text, i, j):
                kept = clauses(seg_text)
                pos = 0
                for c in range(i, j):
                    if pos < len(kept) and plain(cl[c]) == plain(kept[pos]):
                        pos += 1
                    else:
                        marg[c] = True
            mark_missing(segs[0], *cuts[0])
            mark_missing(segs[-1], *cuts[-1])
            marg2 = list(marg)
            res3 = best_partition(cl, [plain(g) for g in glines], lat_lens, lat_texts, skip_ends=True, margin=marg2, title_verses=title_verses, neighbours=None)
            if res3:
                segs, _, cuts = res3
        new = [re.sub(r"\s+([,.;:?!])", r"\1", place_marks(seg, glines[k], lat[idx[k]])) for k, seg in enumerate(segs)]
        # the earlier Spanish (before any recomposition, when given) is the
        # yardstick: the module has gaps of its own, so a psalm the module
        # composes worse than it stood keeps the earlier text, re-cut
        base_lines = old_es[key]["lines"] if old_es and key in old_es and len(old_es[key].get("lines") or []) == len(lat) else es_lines
        old_body = [split_ref(base_lines[i] or "")[1] for i in idx]
        gplain = [plain(g) for g in glines]
        if show and key in show:
            print("=====", key)
            for k, i in enumerate(idx):
                flag = "" if plain(old_body[k]) == plain(new[k]) else "   <<< CHANGED"
                print("L:", lat[i][:120]); print("O:", old_body[k][:120]); print("N:", new[k][:120] + flag); print()

        def quality(lines):
            """Own-line share plus mean affinity (guide words and Latin
            cognates), fragments penalised."""
            _, own = line_score(lines, gplain, lat_lens)
            aff = sum((sim(plain(b), gplain[k]) if gplain[k] else 0.0) + cognate_sim(plain(b), lat_texts[k])
                      for k, b in enumerate(lines)) / max(len(lines), 1)
            frag = sum(1 for b in lines if len(plain(b).split()) <= 2)
            return round(own / max(len(lines), 1) + aff - 2 * frag / max(len(lines), 1), 3)
        if src:
            recut = None
            text = " ".join(plain(b) for b in old_body)
            res2 = best_partition(clauses(text), gplain, lat_lens, lat_texts)
            if res2:
                recut = [re.sub(r"\s+([,.;:?!])", r"\1", place_marks(seg, glines[k], lat[idx[k]])) for k, seg in enumerate(res2[0])]
            q_mod = quality(new)
            cands = [("earlier", old_body)] + ([("earlier re-cut", recut)] if recut else [])
            best = max(cands, key=lambda c: quality(c[1]))
            if quality(best[1]) > q_mod + 0.06:  # the module wins ties: its text has no holes
                gaps.append((key, best[0], q_mod, quality(best[1])))
                new = best[1]
        o_mean, o_own = line_score(old_body, gplain, lat_lens)
        n_mean, n_own = line_score(new, gplain, lat_lens)
        frag_old = sum(1 for b in old_body if len(plain(b).split()) <= 2)
        frag_new = sum(1 for b in new if len(plain(b).split()) <= 2)
        if src or (n_own, round(n_mean, 3)) > (o_own, round(o_mean, 3)) or frag_new < frag_old:
            out = list(es_lines)
            for k, i in enumerate(idx):
                out[i] = split_ref(lat[i])[0] + new[k]
            new_lines_by_key[key] = out
            changed.append((key, o_own, n_own, len(idx), round(o_mean, 3), round(n_mean, 3)))
        else:
            kept.append((key, o_own, len(idx), round(o_mean, 3)))
    print(f"psalms re-cut: {len(changed)}, kept: {len(kept)}, skipped: {len(skipped)}")
    if report:
        for d in drifted:
            print("  drift-dropped %-9s %s" % d)
        for g in gaps:
            print("  not-module %-9s kept %-14s module=%s chosen=%s" % g)
        for c in changed:
            print("  recut %-9s own %2d -> %2d of %2d  sim %.3f -> %.3f" % c)
        for s in skipped:
            print("  skip ", *s)
    if dry:
        return
    for key, lines in new_lines_by_key.items():
        es[key]["lines"] = lines
    # Hand fixes for lines the module has no text for (its Psalms have a
    # few gaps): spanish-translation/psalter_fixes_es.json, key -> {index -> line}.
    fixes = ES / "psalter_fixes_es.json"
    if fixes.exists():
        for key, m in load(fixes).items():
            for i, line in m.items():
                if key in es and int(i) < len(es[key]["lines"]):
                    es[key]["lines"][int(i)] = line
    dump(ES / "psalter_es.json", es)

    # ---- propagate: every overlay verse whose Latin is a psalter line ----
    # Exact keys: a line, its halves, two consecutive lines. Fuzzy: within a
    # named psalm, the candidate (line / half / line+half combos) whose
    # Latin words overlap the verse's best (the hours' invitatory and a few
    # psalms use older wordings and other cuts than the Vulgate psalter).
    index = {}
    cands = {}  # psalm number -> [(word set, spanish)]

    def toks(t):
        return set(fold_lat(t).split())

    for key, entry in psalter.items():
        lines = es[key]["lines"]
        rows = [(split_ref(l)[1], split_ref(e)[1]) for l, e in zip(entry["lat"], lines) if REF_RE.match(l) and e]
        m = re.fullmatch(r"psalm(\d+)c?", key)
        num = int(m.group(1)) if m and int(m.group(1)) <= 150 else None
        cl = cands.setdefault(num, []) if num else None
        for i, (body_l, body_e) in enumerate(rows):
            pieces = [(body_l, body_e)]
            if "*" in body_l and "*" in body_e:
                hl, he = body_l.split("*", 1), body_e.split("*", 1)
                pieces += [(hl[0], plain(he[0])), (hl[1], plain(he[1]))]
            if i + 1 < len(rows):
                l2, e2 = rows[i + 1]
                pieces.append((body_l + " " + l2, body_e + " " + e2))
                if "*" in l2 and "*" in e2:
                    pieces.append((body_l + " " + l2.split("*", 1)[0], body_e + " " + plain(e2.split("*", 1)[0])))
                if "*" in body_l and "*" in body_e:
                    pieces.append((body_l.split("*", 1)[1] + " " + l2, plain(body_e.split("*", 1)[1]) + " " + e2))
            for pl, pe in pieces:
                index.setdefault(fold_lat(pl), pe)
                if cl is not None:
                    cl.append((toks(pl), pe))
    touched = {}

    def psalm_of(part):
        for f in ("ref", "label", "title"):
            m = re.search(r"Ps(?:alm(?:us)?)?\.?\s*(\d+)", str(part.get(f) or ""))
            if m:
                return int(m.group(1))
        return None

    def fix_verses(lat_verses, es_verses, where, part=None):
        n = 0
        num = psalm_of(part) if isinstance(part, dict) else None
        for i, lv in enumerate(lat_verses):
            if i >= len(es_verses) or not isinstance(es_verses[i], str):
                continue
            l = lv.get("lat") if isinstance(lv, dict) else lv
            if not l or fold_lat(l).startswith("gloria patri"):
                continue
            e = index.get(fold_lat(l))
            if e is None and num in cands:
                t = toks(l)
                best, bs = None, 0.0
                for ct, ce in cands[num]:
                    if not ct:
                        continue
                    d = 2 * len(t & ct) / (len(t) + len(ct))
                    if d > bs:
                        best, bs = ce, d
                if bs >= 0.75:
                    e = best
            if e is not None and plain(e) != plain(split_ref(es_verses[i])[1]):
                es_verses[i] = split_ref(es_verses[i])[0] + e
                n += 1
        if n:
            touched[where] = touched.get(where, 0) + n

    # the hours' fixed parts
    hours = {h["slug"]: h for h in load(ASSETS / "hours.json")}
    hp = load(ES / "hours_parts_es.json")
    for slug, idxs in hp.items():
        parts = hours.get(slug, {}).get("parts", [])
        for i, o in idxs.items():
            if i.isdigit() and int(i) < len(parts) and isinstance(o, dict) and isinstance(o.get("verses"), list):
                fix_verses(parts[int(i)].get("verses") or [], o["verses"], "hours_parts_es", parts[int(i)])
    dump(ES / "hours_parts_es.json", hp)
    # the weekly psalter
    pw = load(ASSETS / "psalter_weekly.json")
    pwe = load(ES / "psalter_weekly_es.json")
    for day, m in pwe.items():
        for k, v in m.items():
            src = (pw.get(day) or {}).get(k)
            if isinstance(v, list) and isinstance(src, dict) and isinstance(src.get("verses"), list):
                fix_verses(src["verses"], v, "psalter_weekly_es", src)
            elif isinstance(v, dict) and isinstance(v.get("verses"), list) and isinstance(src, dict):
                fix_verses(src.get("verses") or [], v["verses"], "psalter_weekly_es", src)
    dump(ES / "psalter_weekly_es.json", pwe)
    # commons and propers
    for sname, ename in (("commune_office.json", "commune_office_es.json"),
                         ("temporal_propers.json", "temporal_propers_es.json"),
                         ("sanctoral_propers.json", "sanctoral_propers_es.json")):
        src = load(ASSETS / sname)
        ov = load(ES / ename)
        for code, entry in ov.items():
            for fk, o in entry.items():
                p = (src.get(code) or {}).get(fk)
                if isinstance(p, dict) and isinstance(o, dict) and isinstance(o.get("verses"), list):
                    fix_verses(p.get("verses") or [], o["verses"], ename, p)
        dump(ES / ename, ov)
    print("propagated:", touched)


if __name__ == "__main__":
    main()
