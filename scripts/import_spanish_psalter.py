#!/usr/bin/env python3
"""Build spanish-translation/psalter_es.json — the whole Psalter (psalms and
scripture canticles) in Spanish, line-aligned with psalter.json.

PROVENANCE. DivinumOfficium's Espanol psalter is a MIX: some psalms are the
public-domain Petisco/Torres Amat text (1798/1825, translated from the
Vulgate) hand-lined into liturgical verses, but many others were pasted from
the MODERN Spanish liturgical psalter, which is copyrighted and translated
from the Hebrew. This importer therefore accepts a DO psalm ONLY when its
lines demonstrably ARE the Torres Amat text (mean per-line word overlap with
the TA verse >= --do-accept, default 0.85); everything else is composed
directly from the Torres Amat module, verse by verse:

  - each Latin line's "ch:verse[ab]" prefix keys the TA verse; the verse's
    KJV location is found by a per-psalm shift search scored by
    Latin<->Spanish cognate overlap (the module is KJV-versified while the
    liturgical Latin is Vulgate-versified);
  - a verse split across several Latin lines is split at the punctuation
    boundary nearest each Latin line-length ratio;
  - the flex (†) and mediant (*) marks are inserted mirroring the Latin
    line's positions, and each line keeps the Latin's ref prefix.

Canticles parse their source ref from the title line "(Canticum X * REF)".
Deuterocanonical canticles (Daniel 3, Tobit, Judith, Sirach, Wisdom), the
Athanasian Creed, and any entry the fit cannot resolve come from
spanish-translation/psalter_supplements_es.json — our own tier-2
translations — keyed by psalter key with full line arrays.

Sources (kept OUTSIDE the repo):
  --bible  theWord .ont of Torres Amat (KJV order, first 31,102 lines)
  --kjv    getbible.net v2 kjv.json (versification index only)
  --do     divinum-officium clone (web/www/horas/Espanol/...)

Run:  python3 scripts/import_spanish_psalter.py \
          --bible <torres_amat.ont> --kjv <kjv.json>
      python3 scripts/sync_spanish_assets.py
"""
import json
import re
import sys
import unicodedata
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "spanish-translation" / "psalter_es.json"
WEEKLY_OUT = ROOT / "spanish-translation" / "psalter_weekly_es.json"
SUPP_PATH = ROOT / "spanish-translation" / "psalter_supplements_es.json"
DEFAULT_DO = Path("/tmp/claude-0/-home-user-CatholicApp/"
                  "71906fbb-67e9-553f-b996-d8565178e126/scratchpad/do_repo")


def nfc(s):
    return unicodedata.normalize("NFC", s)


def arg(flag, default=None):
    if flag in sys.argv:
        return sys.argv[sys.argv.index(flag) + 1]
    return default


def fold(s):
    s = unicodedata.normalize("NFD", s)
    s = "".join(c for c in s if not unicodedata.combining(c))
    return re.sub(r"[^a-zñ ]", " ", s.lower())


def content_words(s, minlen=4):
    return {w for w in fold(s).split() if len(w) >= minlen}


def cognate_stems(s, minlen=5):
    """4-letter prefixes of longer words — Latin and Spanish share enough
    Romance stems (misericord-, iniquit-/iniquid-, exsult-/exult-) for a
    verse-alignment signal. Spanish diphthongization (porta->puerta,
    terra->tierra, mortis->muerte) is undone first so those stems match."""
    t = fold(s).replace("ue", "o").replace("ie", "e")
    return {w[:4] for w in t.split() if len(w) >= minlen}


DEUTERO = "DEUTERO"
BOOKS = {
    "Isa": "Isaiah", "Jer": "Jeremiah", "Ez": "Ezekiel", "Ezech": "Ezekiel",
    "Exod": "Exodus", "Deut": "Deuteronomy", "Hab": "Habakkuk",
    "Osea": "Hosea", "Os": "Hosea", "Soph": "Zephaniah",
    "Luc": "Luke", "1 Par": "1 Chronicles", "Prov": "Proverbs",
    "Thren": "Lamentations", "Ps": "Psalms",
    # "Canticum Annae * 3 Reg 2" is a DO data quirk: Anna's canticle is
    # 1 Kings (= 1 Samuel) 2; offer both and let the cognate fit decide.
    "3 Reg": ["1 Samuel", "1 Kings"], "1 Reg": ["1 Samuel"],
    "Dan": DEUTERO,     # Dan 3:24+ (the canticles) is deuterocanonical
    "Tob": DEUTERO, "Judith": DEUTERO, "Sir": DEUTERO, "Eccli": DEUTERO,
    "Sap": DEUTERO,
}

CANTICLE_NAMES = {
    "Canticum Trium Puerorum": "Cántico de los tres jóvenes",
    "Canticum David": "Cántico de David",
    "Canticum Tobiæ": "Cántico de Tobías",
    "Canticum Judith": "Cántico de Judit",
    "Canticum Jeremiæ": "Cántico de Jeremías",
    "Canticum Isaiæ": "Cántico de Isaías",
    "Canticum Ecclesiastici": "Cántico del Eclesiástico",
    "Canticum Ecclesiasticæ": "Cántico del Eclesiástico",
    "Canticum Ezechiæ": "Cántico de Ezequías",
    "Canticum Annæ": "Cántico de Ana",
    "Canticum Moysis": "Cántico de Moisés",
    "Canticum Habacuc": "Cántico de Habacuc",
    "Canticum Zachariæ": "Cántico de Zacarías",
    "Canticum B. Mariæ Virginis": "Cántico de la B. Virgen María",
    "Canticum Simeonis": "Cántico de Simeón",
    "Canticum Quicumque": "Símbolo Atanasiano",
    "Canticum Oseæ": "Cántico de Oseas",
    "Canticum Sophoniæ": "Cántico de Sofonías",
    "Canticum Sapientiæ": "Cántico de la Sabiduría",
    "Canticum Ezechielis": "Cántico de Ezequiel",
    "Canticum Proverb": "Cántico de los Proverbios",
    "Canticum ejusdem": "Cántico del mismo",
    "Canticum": "Cántico",
}


def vulg_to_kjv_psalm(n):
    if n <= 8:
        return [n]
    if n == 9:
        return [9, 10]
    if n <= 112:
        return [n + 1]
    if n == 113:
        return [114, 115]
    if n in (114, 115):
        return [116]
    if n <= 145:
        return [n + 1]
    if n in (146, 147):
        return [147]
    return [n]


def parse_line_ref(line):
    """'22:4 Nam, et si…' -> ('22:4', 4, 'Nam, et si…'); a/b/c suffixes are
    kept in the prefix but ignored for verse lookup."""
    m = re.match(r"^(\d+):(\d+)([a-d]?)\s+(.*)$", line)
    if not m:
        return None
    return (m.group(1) + ":" + m.group(2) + m.group(3),
            int(m.group(2)), m.group(4))


def split_by_ratios(text, k, ratios):
    """Split text into k nonempty pieces at punctuation boundaries nearest
    the cumulative ratios (fractions of total length)."""
    if k == 1:
        return [text]
    # candidate cut positions: after , ; : . ? ! (followed by a space);
    # fall back to word boundaries when punctuation runs out
    punct = [m.end() for m in re.finditer(r"[,;:.?!]\s", text)]
    spaces = [m.end() for m in re.finditer(r"\s", text)]
    picks = []
    lo = 1
    for i in range(k - 1):
        target = int(len(text) * ratios[i])
        cands = [c for c in punct if lo < c < len(text)]
        if not cands:
            cands = [c for c in spaces if lo < c < len(text)]
        if not cands:
            return None
        best = min(cands, key=lambda c: abs(c - target))
        picks.append(best)
        lo = best + 1
    parts = []
    prev = 0
    for c in picks + [len(text)]:
        parts.append(text[prev:c].strip())
        prev = c
    if any(not p for p in parts):
        return None
    return parts


def insert_marks(es_text, lat_text):
    """Mirror the Latin line's flex (†) and mediant (*) marks into the
    Spanish text at the punctuation boundary nearest the same position
    ratio. Every liturgical line carries one *; some also carry a †."""
    out = es_text
    for mark in ("†", "*"):
        if mark not in lat_text or mark in out:
            continue
        ratio = lat_text.index(mark) / max(1, len(lat_text))
        target = int(len(out) * ratio)
        cands = [m.end() for m in re.finditer(r"[,;:.?!]\s", out)]
        if not cands:
            cands = [m.start() for m in re.finditer(r"\s", out)]
        if not cands:
            continue
        pos = min(cands, key=lambda c: abs(c - target))
        head, tail = out[:pos].rstrip(), out[pos:].lstrip()
        if not head or not tail:
            continue
        out = head + " " + mark + " " + tail
    # order: † must precede * (re-run cheaply if inverted)
    if "†" in out and "*" in out and out.index("†") > out.index("*"):
        out = out.replace(" † ", " ").replace(" * ", " † ", 1)
    return out


def cap_first(s):
    for i, ch in enumerate(s):
        if ch.isalpha():
            return s[:i] + ch.upper() + s[i + 1:]
    return s


def main():
    bible_path = arg("--bible")
    kjv_path = arg("--kjv")
    do_root = Path(arg("--do", str(DEFAULT_DO)))
    do_accept = float(arg("--do-accept", "0.85"))
    if not bible_path or not kjv_path:
        sys.exit("pass --bible <torres_amat.ont> --kjv <kjv.json>")

    verse_lines = open(bible_path, encoding="utf-8-sig",
                       newline="").read().splitlines()
    # strip theWord markup (<CM>, formatting tags) from every verse
    verse_lines = [re.sub(r"\s+", " ", re.sub(r"<[^>]*>", " ", l)).strip()
                   for l in verse_lines]
    kjv = json.load(open(kjv_path, encoding="utf-8"))["books"]
    index = {}   # book -> {(ch, v): text}
    line_no = 0
    for b in kjv:
        by = index.setdefault(b["name"], {})
        for ch in b["chapters"]:
            for v in ch["verses"]:
                by[(int(ch["chapter"]), int(v["verse"]))] = \
                    verse_lines[line_no]
                line_no += 1

    supp = (json.load(open(SUPP_PATH, encoding="utf-8"))
            if SUPP_PATH.exists() else {})
    do_ps = do_root / "web/www/horas/Espanol/Psalterium/Psalmorum"

    psalter = json.load(open(ROOT / "Introibo" / "Resources" /
                             "psalter.json"))

    out = {}
    report = {"do_verbatim": [], "composed": [], "supplement": [],
              "skipped": []}

    for name in sorted(psalter, key=lambda x: (len(x), x)):
        m = re.match(r"psalm(\d+)([a-z]*)$", name)
        num, suf = int(m.group(1)), m.group(2)
        lat = [nfc(l) for l in psalter[name]["lat"]]

        # ---- supplements take absolute precedence (hand-translated) ----
        if name in supp:
            lines = supp[name]
            if len(lines) != len(lat):
                report["skipped"].append((name, "supplement line count"))
                continue
            out[name] = {"lines": [nfc(l) for l in lines]}
            report["supplement"].append(name)
            continue

        # ---- resolve the source book/chapters ----
        title_es = None
        body_lat = lat
        if lat and lat[0].startswith("("):
            tm = re.match(r"^\(([^*]+?)\s*\*\s*(.+)\)$", lat[0])
            if not tm:
                report["skipped"].append((name, "unparsed title"))
                continue
            cname, ref = tm.group(1).strip(), tm.group(2).strip()
            # "Ibid." continuation canticles inherit their neighbour's book
            IBID = {"psalm247": "Hab 3", "psalm248": "Hab 3",
                    "psalm255": "Sap 10"}
            if ref.startswith("Ibid") and name in IBID:
                ref = IBID[name]
            base = CANTICLE_NAMES.get(cname)
            if base is None:
                report["skipped"].append((name, f"canticle name {cname!r}"))
                continue
            title_es = f"({base} * {ref})"
            body_lat = lat[1:]
            bm = re.match(r"^((?:\d\s)?[A-Za-z]+)\.?\s", ref)
            book = BOOKS.get(bm.group(1)) if bm else None
            if book is None:
                report["skipped"].append((name, f"canticle ref {ref!r}"))
                continue
            if book == DEUTERO:
                report["skipped"].append((name, "deuterocanon (supplement)"))
                continue
            books = book if isinstance(book, list) else [book]
            chapters = None   # canticle lines carry their own ch:verse
            # the ref names the source chapter(s) — the DP alignment below
            # is restricted to them ("Isa 61:10-11; 62:1-3" -> [61, 62])
            cant_chapters = [int(m2) for m2 in
                             re.findall(r"(\d+):", ref)] or None
        else:
            if num > 150:
                report["skipped"].append((name, "canticle without title"))
                continue
            books = ["Psalms"]
            chapters = vulg_to_kjv_psalm(num)
            cant_chapters = None

        # ---- try DO verbatim (Torres Amat already hand-lined) ----
        do_file = do_ps / f"Psalm{num}{suf}.txt"
        if do_file.exists():
            do_lines = [nfc(l.strip()) for l in
                        open(do_file, encoding="utf-8").read().splitlines()
                        if l.strip() and not l.strip().startswith("$")]
            if len(do_lines) == len(lat):
                scores = []
                ok = True
                for ll, dl in zip(body_lat, do_lines[len(lat) - len(body_lat):]):
                    pr = parse_line_ref(ll)
                    pd = parse_line_ref(dl)
                    if not pr or not pd or pr[1] != pd[1]:
                        ok = False
                        break
                    ew = content_words(pd[2])
                    if not ew:
                        continue
                    best = 0.0
                    for bkname in books:
                        chs = chapters or \
                            [c for (c, v) in index.get(bkname, {})]
                        for c in set(chs):
                            for s in (-2, -1, 0, 1, 2):
                                t = index.get(bkname, {}).get((c, pr[1] + s))
                                if t:
                                    sc = len(content_words(t) & ew) / len(ew)
                                    best = max(best, sc)
                    scores.append(best)
                if ok and scores and sum(scores) / len(scores) >= do_accept:
                    lines = do_lines
                    if title_es and not lines[0].startswith("("):
                        pass   # DO file lacks title; fall through to compose
                    else:
                        if title_es:
                            lines = [title_es] + lines[1:]
                        out[name] = {"lines":
                                     [re.sub(r"\s{2,}", " ", l).strip()
                                      for l in lines]}
                        report["do_verbatim"].append(name)
                        continue

        # ---- compose from Torres Amat ----
        # "$ant" rubric markers inside the Invitatory pass through verbatim
        parsed = []
        bad = None
        for l in body_lat:
            if l.strip().startswith("$"):
                parsed.append((None, None, l))
                continue
            pr = parse_line_ref(l)
            if not pr:
                bad = f"unparsed line {l[:40]!r}"
                break
            parsed.append(pr)
        if bad:
            report["skipped"].append((name, bad))
            continue

        # per-line fit: pick (book, ch, verse+shift) by cognate overlap
        # with the LATIN. Multi-chapter psalms (9, 113, 114/115, 146/147)
        # and breviary-numbered canticles need shifts far beyond ±2, so a
        # wide retry follows a failed narrow search.
        def search(v, lstem, shifts):
            best = None
            for bkname in books:
                bidx = index.get(bkname, {})
                chs = (chapters if chapters else
                       sorted({c for (c, _) in bidx}))
                for c in chs:
                    for s in shifts:
                        t = bidx.get((c, v + s))
                        if not t:
                            continue
                        sc = len(cognate_stems(t) & lstem)
                        if best is None or sc > best[0]:
                            best = (sc, bkname, c, v + s, t)
            return best

        # ---- map each line to its source verse ----
        # PSALMS: the Vulgate and KJV cover the same verse sequence — only
        # the numbering differs (titles, split psalms). Sequential packing
        # is deterministic: the i-th DISTINCT Vulgate verse number maps to
        # the i-th verse of the mapped KJV chapter run. CANTICLES: the
        # breviary renumbers verses freely, so lines are placed by cognate
        # votes with monotonic interpolation for weak lines.
        content = [(p, v, t) for (p, v, t) in parsed if p is not None]
        distinct = []
        for _, v, _ in content:
            if not distinct or distinct[-1] != v:
                distinct.append(v)

        # Both psalms and canticles align by the same monotone DP: free
        # start (skips module title-verses), advance-one bias (sequential
        # by default), stalls/skips only where cognate evidence pays for
        # them (Vulgate verse splits, breviary renumbering).
        verse_of = {}   # vulgate verse number -> (book, ch, kjv_v, text)
        if True:
            stems = {}
            for _, v, lt in content:
                stems[v] = stems.get(v, set()) | cognate_stems(lt)
            best_path = None
            for bkname in books:
                bidx = index.get(bkname, {})
                if chapters is not None:
                    chs = chapters
                else:
                    chs = (cant_chapters if cant_chapters else
                           sorted({c for (c, _) in bidx}))
                run = [(bkname, c, v) for c in chs
                       for (cc, v) in sorted(k for k in bidx if k[0] == c)]
                if not run:
                    continue
                # monotone alignment: breviary verse i -> run index j,
                # j non-decreasing, advancing at most 3 per step
                n, m2_ = len(distinct), len(run)
                NEG = float("-inf")
                dp = [[NEG] * m2_ for _ in range(n)]
                back = [[None] * m2_ for _ in range(n)]
                def sc(i, j):
                    bk, c, kv = run[j]
                    return len(cognate_stems(bidx[(c, kv)]) &
                               stems[distinct[i]])
                # PSALMS are anchored: the liturgical text covers the whole
                # psalm and the module merges titles into verse 1's text,
                # so the path starts at the run's first verse and ends at
                # its last (stalls absorb Vulgate verse splits). CANTICLES
                # excerpt a chapter, so start and end stay free.
                anchored = chapters is not None
                if anchored:
                    dp[0][0] = sc(0, 0)
                else:
                    # canticle start prior: the breviary numbering equals
                    # the source's at the canticle's first verse, so favour
                    # starting there (cognate evidence can still override)
                    for j in range(m2_):
                        prior = 0.5 if run[j][2] == distinct[0] else 0.0
                        dp[0][j] = sc(0, j) + prior
                for i in range(1, n):
                    for j in range(m2_):
                        for pj in range(max(0, j - 3), j + 1):
                            if dp[i-1][pj] == NEG:
                                continue
                            # bias toward advancing one verse per line:
                            # stalls (verse sharing) and skips must be
                            # justified by cognate evidence
                            step = j - pj
                            bias = (0.3 if step == 1 else
                                    -0.3 if step == 0 else -0.1)
                            val = dp[i-1][pj] + sc(i, j) + bias
                            if val > dp[i][j]:
                                dp[i][j] = val
                                back[i][j] = pj
                if anchored and dp[n-1][m2_ - 1] != NEG:
                    endj = m2_ - 1
                else:
                    endj = max(range(m2_), key=lambda j: dp[n-1][j])
                if dp[n-1][endj] == NEG:
                    continue
                path = [endj]
                for i in range(n - 1, 0, -1):
                    path.append(back[i][path[-1]])
                path.reverse()
                if best_path is None or dp[n-1][endj] > best_path[0]:
                    best_path = (dp[n-1][endj], bkname, run, path)
            if best_path is None:
                report["skipped"].append((name, "canticle alignment failed"))
                continue
            _, bkname, run, path = best_path
            zeros = 0
            for i, v in enumerate(distinct):
                bk, c, kv = run[path[i]]
                t = index[bk][(c, kv)]
                if not (cognate_stems(t) & stems[v]):
                    zeros += 1
                verse_of[v] = (bk, c, kv, t)
            report.setdefault("fit_quality", {})[name] = zeros

        line_src = []
        for prefix, v, lat_text in parsed:
            if prefix is None:            # "$ant" rubric passthrough
                line_src.append((None, lat_text, None))
                continue
            bk, c, kv, t = verse_of[v]
            line_src.append((prefix, lat_text, (1, bk, c, kv, t)))

        # group consecutive lines that drew the same source verse, then
        # split that verse's text across the group
        es_body = []
        i = 0
        compose_fail = None
        while i < len(line_src):
            if line_src[i][2] is None:    # rubric passthrough
                es_body.append(line_src[i][1])
                i += 1
                continue
            j = i
            key = line_src[i][2][1:4]
            while (j + 1 < len(line_src) and line_src[j + 1][2] is not None
                   and line_src[j + 1][2][1:4] == key):
                j += 1
            group = line_src[i:j + 1]
            text = re.sub(r"\s+", " ", group[0][2][4]).strip()
            text = re.sub(r"\s+([,.;:!?])", r"\1", text)
            # the module merges psalm TITLES into verse 1's text ("Cuando,
            # después que pecó con Betsabé… Ten piedad de mí…"): drop
            # leading sentences with no cognate echo in the Latin while
            # the remainder still has one
            _, _, (_, gbk, _, gkv, _) = group[0]
            if gbk == "Psalms" and gkv <= 2:
                glat = " ".join(g[1] for g in group)
                gstem = cognate_stems(glat)
                sents = re.split(r"(?<=[.!?])\s+", text)
                dropped = 0
                while (len(sents) > 1 and dropped < 2 and
                       not (cognate_stems(sents[0]) & gstem) and
                       (cognate_stems(" ".join(sents[1:])) & gstem)):
                    sents = sents[1:]
                    dropped += 1
                if dropped:
                    text = " ".join(sents)
            k = len(group)
            lat_lens = [len(g[1]) for g in group]
            total = sum(lat_lens)
            ratios = []
            acc = 0
            for L in lat_lens[:-1]:
                acc += L
                ratios.append(acc / total)
            parts = split_by_ratios(text, k, ratios)
            if parts is None:
                compose_fail = f"cannot split verse {group[0][0]}"
                break
            for (prefix, lat_text, _), part in zip(group, parts):
                part = cap_first(part)
                part = insert_marks(part, lat_text)
                part = re.sub(r"\s{2,}", " ", part)
                es_body.append(f"{prefix} {part}")
            i = j + 1
        if compose_fail:
            report["skipped"].append((name, compose_fail))
            continue

        lines = ([title_es] if title_es else []) + es_body
        if len(lines) != len(lat):
            report["skipped"].append((name, "composed line count"))
            continue
        out[name] = {"lines": [re.sub(r"\s{2,}", " ", nfc(l)).strip()
                               for l in lines]}
        report["composed"].append(name)

    OUT.write_text(json.dumps(out, ensure_ascii=False, indent=1,
                              sort_keys=True) + "\n", encoding="utf-8")
    n_lines = sum(len(v["lines"]) for v in out.values())
    print(f"wrote {len(out)} entries ({n_lines} lines)")

    # ---- fan the bank out to the weekly psalter (same Latin line ->
    # same Spanish line; unmatched verses stay null = English) ----
    def fold_ws(s):
        s = unicodedata.normalize("NFD", s)
        s = "".join(c for c in s if not unicodedata.combining(c))
        return re.sub(r"\s+", " ", s.lower()).strip()

    bank = {}
    for n2, v2 in psalter.items():
        if n2 in out:
            for ll, el in zip(v2["lat"], out[n2]["lines"]):
                bank[fold_ws(ll)] = el
    weekly = json.load(open(ROOT / "Introibo" / "Resources" /
                            "psalter_weekly.json"))
    wout = {}
    w_tot = w_hit = 0
    for day, parts in weekly.items():
        for key, part in parts.items():
            vs = part.get("verses") or []
            es_vs = []
            any_hit = False
            for vv in vs:
                w_tot += 1
                el = bank.get(fold_ws(vv["lat"]))
                if el is not None:
                    w_hit += 1
                    any_hit = True
                es_vs.append(el)
            if any_hit:
                wout.setdefault(day, {})[key] = es_vs
    WEEKLY_OUT.write_text(json.dumps(wout, ensure_ascii=False, indent=1,
                                     sort_keys=True) + "\n",
                          encoding="utf-8")
    print(f"weekly psalter: {w_hit}/{w_tot} verses matched")
    print(f"  DO verbatim (Torres Amat, hand-lined): "
          f"{len(report['do_verbatim'])}")
    print(f"  composed from Torres Amat: {len(report['composed'])}")
    print(f"  hand supplements: {len(report['supplement'])}")
    if report["skipped"]:
        print(f"  SKIPPED {len(report['skipped'])}:")
        for name, why in report["skipped"]:
            print(f"    {name}: {why}")
    weak = {n: z for n, z in report.get("fit_quality", {}).items() if z}
    if weak:
        print(f"  fit warnings (lines with ZERO cognate overlap): {weak}")


if __name__ == "__main__":
    main()
