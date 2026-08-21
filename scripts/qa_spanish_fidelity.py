#!/usr/bin/env python3
"""Spanish-to-Latin fidelity QA over the bundled assets.

Pairs every Spanish field with the Latin (or English) source it renders
and hunts for fidelity problems. This is the deep-dive harness that found
the cross-assigned propers, dangling @Doxology references, and
untranslated fields fixed in the 2026-08 sweep — kept as a repo tool so
any future import can be re-audited.

Run from the repo root:  python3 scripts/qa_spanish_fidelity.py

Hard checks (nonzero exit when they fire):
  EMPTY     Latin has content, Spanish is empty
  LEAK-EN   unambiguous English tokens in a Spanish field
  LEAK-LA   Spanish identical to the Latin (long fields only)
  ART       markup artifacts: &/@ leftovers, double spaces, space
            before punctuation, edge whitespace
  VNUM      leading verse-number prefix disagrees with the Latin's
  BANK      an Office psalm verse disagrees with the Spanish Psalter
  DUP       identical Spanish on two different Latin fields of one day
  ALLELUIA  "aleluya" present/absent against the Latin's "allelúja"
  STRUCT    responsory/versicle R./V./* line structure differs
  HEAD      lesson heading names a different evangelist/author than
            the Latin (the O12 heading scan, kept re-runnable)
  GLORIA    "Glória Patri" present in one language, absent in the other

Advisory (printed, never fatal):
  NOPAIR    a long Latin field with no English AND no Spanish — the
            pre-existing Latin-only corpus (its own tranche)
  COG       lowest cognate-scored pairs per corpus — worth an eyeball
            after a new import; free renderings legitimately score 0
  GROUP     same-Latin fields carrying different Spanish — legitimate
            register variants show up here too, so triage by hand

--strict promotes GROUP minority-variants to a hard failure.
"""
import argparse
import json
import re
import sys
import unicodedata
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
R = ROOT / "Introibo" / "Resources"

# Known-intentional flags: (check, file, key-prefix)
ALLOWLIST = [
    # Spanish phonetic respelling uses English 'ye' for the J sound
    ("LEAK-EN", "courses", "ave.sections_es[1].items_es[4].phon_es"),
    # lectio4/lectio94 differ only by an i/j spelling (ejiceret/eiceret);
    # the shared Spanish is correct for both
    ("DUP", "sanctoral", "09-23.lectio4+lectio94"),
]

def allowed(check, file, key):
    return any(c == check and f == file and key.startswith(k)
               for c, f, k in ALLOWLIST)

def load(name):
    return json.load(open(R / name))

def fold(s):
    s = unicodedata.normalize("NFD", s.lower())
    s = "".join(c for c in s if unicodedata.category(c) != "Mn")
    s = s.replace("æ", "ae").replace("œ", "oe").replace("j", "i")
    return re.sub(r"[^a-z0-9 ]+", " ", s)

def stems(s):
    out = set()
    for w in fold(s).split():
        w = w.replace("ue", "o").replace("ie", "e")
        if len(w) >= 5:
            out.add(w[:4])
    return out

def cog(lat, es):
    a, b = stems(lat), stems(es)
    return len(a & b) / len(a) if a else None

def sim(a, b):
    A, B = stems(a), stems(b)
    return len(A & B) / max(1, min(len(A), len(B)))

# Unambiguous English tokens (none are Spanish/Latin words).
EN_STRONG = {"the", "and", "of", "shall", "thou", "thee", "thy", "hath",
             "unto", "which", "was", "were", "from", "with", "our",
             "they", "their", "would", "should", "might", "hast", "ye"}
EN_RE = re.compile(r"[A-Za-zÀ-ÿ']+")

def en_hits(es):
    return [t for t in (w.lower() for w in EN_RE.findall(es) if w.isascii())
            if t in EN_STRONG]

EVANG_LAT = {"matthaeum": "mateo", "marcum": "marcos",
             "lucam": "lucas", "ioannem": "iuan"}
AUTH_PAIRS = [  # heading author (folded Latin genitive → folded Spanish)
    ("bernardini", "bernardino"), ("bernardi", "bernardo"),
    ("chrysostomi", "crisostomo"), ("hieronymi", "ieronimo"),
    ("gregorii", "gregorio"), ("augustini", "agustin"),
    ("ambrosii", "ambrosio"), ("hilarii", "hilario"),
    ("damasceni", "damasceno"), ("leonis", "leon"), ("bedae", "beda"),
]

def head_checks(file, key, lat, es):
    """Lesson-heading fidelity: evangelist and homily-author names."""
    latf = fold("\n".join(lat.split("\n")[:2]))
    esf = fold("\n".join(es.split("\n")[:3]))
    m = re.search(r"secundum (matthaeum|marcum|lucam|ioannem)", latf)
    if m:
        got = re.search(r"segun (?:san )?(mateo|marcos|lucas|iuan)", esf)
        if got and got.group(1) != EVANG_LAT[m.group(1)]:
            flag("HEAD", file, key,
                 f"lat secundum {m.group(1)} :: es según {got.group(1)}")
    if re.search(r"\b(homilia|sermo|sermone|tractatu) (sancti|beati)\b", latf):
        for lt, st in AUTH_PAIRS:
            if re.search(rf"\b{lt}\b", latf):
                if not re.search(rf"\b{st}\b", esf):
                    flag("HEAD", file, key,
                         f"lat author {lt}, es heading lacks {st} :: "
                         f"{es.split(chr(10))[0][:60]}")
                break

VNUM_RE = re.compile(r"^(\d+:\d+[a-c]?)\s")
ART_RE = re.compile(r"[&@]|(?<!\.)\.\.(?!\.)| {2,}| [;:,.!?](?!\.)")

flags = defaultdict(list)
cogs = defaultdict(list)
n_pairs = Counter()
groups = defaultdict(list)

def flag(check, file, key, detail):
    if not allowed(check, file, key):
        flags[check].append((file, key, detail))

def marker_shape(text):
    """Sequence of structural markers (R./V./*) at line starts."""
    out = []
    for line in text.split("\n"):
        line = line.strip()
        if line.startswith(("R. ", "R.br")):
            out.append("R")
        elif line.startswith("V. "):
            out.append("V")
        elif line.startswith("* "):
            out.append("*")
    return out

def check_pair(file, key, lat, es, tier="normal"):
    """tier: normal | free (verse translations) | skip-cog"""
    n_pairs[file] += 1
    if lat and lat.strip() and (not es or not es.strip()):
        flag("EMPTY", file, key, lat[:60])
        return
    if not es:
        return
    h = en_hits(es)
    if len(h) >= 2 or (len(h) == 1 and len(es) < 80):
        flag("LEAK-EN", file, key, f"{sorted(set(h))} :: {es[:90]}")
    if lat and lat.startswith("$") and es == lat:
        return
    if lat and lat.startswith("#"):
        # special container blocks: the vernacular mirrors the English
        # ceremony layout, not the abbreviated Latin
        return
    if ART_RE.search(es) or es != es.strip():
        flag("ART", file, key, es[:90])
    if not lat:
        return
    if len(lat) > 40 and fold(lat) == fold(es):
        flag("LEAK-LA", file, key, es[:80])
    m_l, m_e = VNUM_RE.match(lat), VNUM_RE.match(es)
    if m_l and m_e and m_l.group(1).rstrip("abc") != m_e.group(1).rstrip("abc"):
        flag("VNUM", file, key, f"lat={m_l.group(1)} es={m_e.group(1)} :: {es[:60]}")
    lat_all = "allelui" in fold(lat[-40:])
    es_all = "aleluy" in fold(es[-40:])
    if file in ("prayers", "psalter", "psalter_weekly"):
        lat_all = es_all = False   # received texts / Torres Amat are canonical
    if "dicitur" in lat or "T. P." in es[-40:] or "(Aleluya" in es[-40:]:
        # seasonal-rubric conditionals: the Spanish uses the hand-missal
        # "(T. P. Aleluya)" convention; the Latin carries rubric lines
        lat_all = es_all = False
    if lat.strip() and lat_all != es_all and tier not in ("free", "skip-cog"):
        flag("ALLELUIA", file, key,
             f"lat {'has' if lat_all else 'lacks'} allelúja :: {es[-80:]}")
    if tier != "free" and (lat.startswith(("R. ", "V. ")) or "\n* " in lat):
        if marker_shape(lat) != marker_shape(es):
            flag("STRUCT", file, key,
                 f"lat {marker_shape(lat)} es {marker_shape(es)} :: {es[:60]}")
    if "\n" in lat:
        head_checks(file, key, lat, es)
    if tier == "normal" and file not in ("prayers", "psalter") \
            and not lat.startswith("$"):
        latf, esf = fold(lat), fold(es)
        # word-boundary: the genitive "in glória Patris sui" is not a doxology
        lat_gp = bool(re.search(r"\bgloria patri\b", latf))
        es_gp = bool(re.search(r"\bgloria al padre\b", esf))
        if lat_gp != es_gp:
            flag("GLORIA", file, key,
                 f"lat {'has' if lat_gp else 'lacks'} Glória Patri :: {es[-70:]}")
        # advisory: translations legitimately move/split the flex marker
        if lat.count("*") and lat.count("*") != es.count("*"):
            flag("STAR", file, key,
                 f"lat {lat.count('*')}* es {es.count('*')}* :: {es[:60]}")
    if len(lat) > 40:
        groups[fold(lat).strip()].append((f"{file} {key}", es))
    if tier != "skip-cog":
        c = cog(lat, es)
        if c is not None and len(stems(lat)) >= 4:
            cogs[file].append((c, key, lat, es))

def check_free(file, key, es):
    check_pair(file, key, None, es, tier="skip-cog")

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--strict", action="store_true",
                    help="promote GROUP minority variants to failures")
    ap.add_argument("--show", type=int, default=12,
                    help="examples printed per check")
    args = ap.parse_args()

    # Spanish Psalter index for the verse-bank check.
    ps_lat = load("psalter.json")
    ps_es = load("psalter_es.json")
    ps_ix = {}
    for ps, o in ps_es.items():
        lat_lines = (ps_lat.get(ps) or {}).get("lat") or []
        lines = o.get("lines") if isinstance(o, dict) else o
        for i, l in enumerate(lines or []):
            if i < len(lat_lines):
                m = re.match(r"(\d+:\d+)[a-c]?\s", lat_lines[i])
                if m:
                    ps_ix.setdefault((ps, m.group(1)), []).append(
                        re.sub(r"^\d+:\d+[a-c]?\s", "", l))

    def bank_check(file, key, lat, es):
        # Canticle chapter refs collide with psalm numbers — skip them.
        if "canticle" in key:
            return
        m = re.match(r"(\d+):(\d+)[a-c]?\s", lat)
        if not m:
            return
        cands = []
        for suf in ("", "a", "b", "c"):
            cands += ps_ix.get((f"psalm{m.group(1)}{suf}",
                                f"{m.group(1)}:{m.group(2)}"), [])
        es_st = stems(es)
        if not cands or not es_st:
            return
        best = max(len(es_st & stems(c)) / len(es_st) for c in cands)
        if best < 0.45:
            flag("BANK", file, key, f"{best:.2f} lat={lat[:50]} es={es[:70]}")

    # ---- prayers ----
    src = {p["slug"]: p for p in load("prayers.json")}
    for slug, o in load("prayers_es.json").items():
        if slug.startswith("_") or slug not in src:
            continue
        for i, line in enumerate(o["lines_es"]):
            lat = src[slug]["lines"][i].get("lat") or ""
            if lat.strip() or line.strip():
                check_pair("prayers", f"{slug}[{i}]", lat, line)

    # ---- missal ordinary + canon variants ----
    src = {s["slug"]: s for s in load("missal.json")}
    for slug, o in load("missal_es.json").items():
        if slug in src:
            for i, le in enumerate(o["body_es"]):
                check_pair("missal", f"{slug}[{i}]",
                           src[slug]["body"][i].get("lat") or "",
                           le.get("eng_es") or "")
    src = load("canon_variants.json")
    for g, entries in load("canon_variants_es.json").items():
        for k, o in entries.items():
            check_pair("canon_variants", f"{g}.{k}",
                       (src.get(g, {}).get(k) or {}).get("lat") or "",
                       o.get("eng_es") or "")

    # ---- marian antiphons ----
    src = {a["slug"]: a for a in load("marian_antiphons.json")}
    for slug, o in load("marian_antiphons_es.json").items():
        if slug in src:
            check_pair("marian", slug, src[slug].get("lat") or "",
                       o.get("body_es") or "")

    # ---- psalter ----
    for ps, o in ps_es.items():
        lat_lines = (ps_lat.get(ps) or {}).get("lat") or []
        lines = o.get("lines") if isinstance(o, dict) else o
        for i, line in enumerate(lines or []):
            if i < len(lat_lines):
                check_pair("psalter", f"{ps}[{i}]", lat_lines[i], line,
                           "skip-cog" if len(line) < 40 else "normal")

    # ---- psalter weekly ----
    src = load("psalter_weekly.json")
    for day, entry in load("psalter_weekly_es.json").items():
        for fk, verses in entry.items():
            pv = ((src.get(day) or {}).get(fk) or {}).get("verses") or []
            for i, v in enumerate(verses or []):
                if v is None:
                    continue
                lat = pv[i].get("lat") if i < len(pv) else ""
                check_pair("psalter_weekly", f"{day}.{fk}[{i}]",
                           lat or "", v, "skip-cog")
                bank_check("psalter_weekly", f"{day}.{fk}[{i}]", lat or "", v)

    # ---- psalter weekly: part-level ferial cursus (tranche O10) ----
    src = load("psalter_weekly.json")
    pw_parts = load("psalter_weekly_parts_es.json")
    for day, entry in pw_parts.items():
        for fk, v in entry.items():
            lat = ((src.get(day) or {}).get(fk) or {}).get("lat") or ""
            tier = "free" if fk.startswith("hymnus") else "normal"
            check_pair("psalter_weekly", f"{day}.{fk}", lat, v, tier)
    # source-side coverage: every part-level eng needs a Spanish part
    for day, parts in src.items():
        for fk, part in parts.items():
            if isinstance(part, dict) and isinstance(part.get("eng"), str) \
                    and part["eng"].strip():
                if not ((pw_parts.get(day) or {}).get(fk) or "").strip():
                    flag("MISSING", "psalter_weekly", f"{day}.{fk}",
                         part["eng"][:60])

    # ---- hours ordinary ----
    src = {h["slug"]: h for h in load("hours.json")}
    for slug, entry in load("hours_parts_es.json").items():
        parts = (src.get(slug) or {}).get("parts") or []
        for pk, o in entry.items():
            try:
                part = parts[int(pk)]
            except (ValueError, IndexError):
                continue
            for ef, lf in (("eng", "lat"), ("engR", "latR")):
                if o.get(ef) is not None:
                    check_pair("hours_parts", f"{slug}[{pk}].{ef}",
                               part.get(lf) or "", o[ef])

    # ---- office propers maps ----
    OFFICE = [("commune", "commune_office.json", "commune_office_es.json"),
              ("temporal", "temporal_propers.json", "temporal_propers_es.json"),
              ("sanctoral", "sanctoral_propers.json", "sanctoral_propers_es.json"),
              ("hymns", "hymns_seasonal.json", "hymns_seasonal_es.json")]
    PAIRS = [("eng", "lat"), ("engR", "latR"), ("v1Eng", "v1"),
             ("r1Eng", "r1"), ("v2Eng", "v2"), ("r2Eng", "r2"),
             ("antiphonEng", "antiphon")]
    for name, sname, ename in OFFICE:
        src = load(sname)
        es = load(ename)
        for code, entry in es.items():
            sentry = src.get(code) or {}
            for fk, o in entry.items():
                part = sentry.get(fk) or {}
                tier = ("free" if (name == "hymns" or fk.startswith("hymnus"))
                        else "normal")
                for ef, lf in PAIRS:
                    if o.get(ef) is not None:
                        check_pair(name, f"{code}.{fk}.{ef}",
                                   part.get(lf) or "", o[ef],
                                   tier if ef in ("eng", "antiphonEng") else "normal")
                if o.get("verses"):
                    pv = part.get("verses") or []
                    for i, v in enumerate(o["verses"]):
                        if v is None:
                            continue
                        lat = pv[i].get("lat") if i < len(pv) else ""
                        check_pair(name, f"{code}.{fk}.verses[{i}]",
                                   lat or "", v, "skip-cog")
                        bank_check(name, f"{code}.{fk}.verses[{i}]", lat or "", v)
            # DUP: identical Spanish on two different Latin parts of a day.
            seen = {}
            def bare(t):
                return " ".join(fold("\n".join(
                    l for l in t.split("\n")
                    if not l.startswith("$")).strip()).split())
            for fk, o in entry.items():
                e = o.get("eng")
                lat = bare((sentry.get(fk) or {}).get("lat") or "")
                if not e or len(e) < 60:
                    continue
                if e in seen and bare((sentry.get(seen[e]) or {}).get("lat") or "") != lat:
                    flag("DUP", name, f"{code}.{seen[e]}+{fk}", e[:80])
                seen.setdefault(e, fk)
        # NOPAIR: long Latin with neither English nor Spanish anywhere.
        for code, sentry in src.items():
            for fk, part in sentry.items():
                if not isinstance(part, dict):
                    continue
                lat = part.get("lat") or ""
                first = lat.split("\n")[0]
                artifact = (
                    fk in ("comment", "initial", "commemoratio", "scriptura")
                    or lat.startswith(("#", "@", "!", "["))
                    or "…" in lat or "... " in lat
                    or "lectiones" in lat or "Psalmi Dominica" in lat
                    or (len(lat) < 60 and first.startswith(("In ", "Feria", "Sabbato")))
                )
                if (len(lat) > 120 and not (part.get("eng") or "").strip()
                        and not artifact):
                    o = (es.get(code) or {}).get(fk) or {}
                    if not (o.get("eng") or "").strip():
                        flag("NOPAIR", name, f"{code}.{fk}", lat[:70])
                # MISSING: the source carries English but the overlay has no
                # Spanish — a source-side gap invisible to the overlay-driven
                # pairing loops above (tranche O10 lesson).
                if (part.get("eng") or "").strip():
                    o = (es.get(code) or {}).get(fk) or {}
                    if not (o.get("eng") or "").strip():
                        flag("MISSING", name, f"{code}.{fk}",
                             (part.get("eng") or "")[:60])

    # ---- missal propers + readings ----
    tem = load("missal_tempora.json")
    san = load("missal_sanctoral.json")
    mis_es = {}
    for fname in ("missal_propers_es.json", "missal_readings_es.json"):
        tag = fname.replace("_es.json", "")
        for code, entry in load(fname).items():
            if code.startswith("_"):
                continue
            e = tem.get(code) or san.get(code) or {}
            for field, v in entry.items():
                f = e.get(field)
                lat = (f or {}).get("lat") or "" if isinstance(f, dict) else ""
                check_pair(tag, f"{code}.{field}", lat, v)
                if (v or "").strip():
                    mis_es[(code, field)] = True
    # MISSING: every English-bearing missal field needs Spanish in one of
    # the two overlay files (source-side coverage, tranche O10 lesson).
    for mname, msrc in (("missal_tempora", tem), ("missal_sanctoral", san)):
        for code, entry in msrc.items():
            if not isinstance(entry, dict):
                continue
            for field, part in entry.items():
                if isinstance(part, dict) and isinstance(part.get("eng"), str) \
                        and part["eng"].strip():
                    if (code, field) not in mis_es:
                        flag("MISSING", mname, f"{code}.{field}",
                             part["eng"][:60])

    # ---- rosary + mysteries ----
    src = {p["slug"]: p for p in load("rosary_prayers.json")}
    for slug, o in load("rosary_prayers_es.json").items():
        for i, line in enumerate(o.get("lines_es") or []):
            lat = src[slug]["lines"][i]["lat"] if slug in src else ""
            check_pair("rosary", f"{slug}[{i}]", lat, line)
    src = {s["slug"]: s for s in load("mysteries.json")}
    for slug, o in load("mysteries_es.json").items():
        for i, m in enumerate(o.get("mysteries") or []):
            lat = src[slug]["mysteries"][i]["title"] if slug in src else ""
            check_pair("mysteries", f"{slug}[{i}].title", lat,
                       m.get("eng_es") or "", "free")
            check_free("mysteries", f"{slug}[{i}].body", m.get("body_es") or "")
            check_free("mysteries", f"{slug}[{i}].fruit", m.get("fruit_es") or "")

    # ---- English-source corpora: leakage/artifact checks only ----
    for slug, o in load("stations_es.json").items():
        for f in ("title_es", "med_es", "stabat_es"):
            if o.get(f):
                check_free("stations", f"{slug}.{f}", o[f])

    def walk_free(file, key, node):
        if isinstance(node, str):
            check_free(file, key, node)
        elif isinstance(node, list):
            for i, v in enumerate(node):
                walk_free(file, f"{key}[{i}]", v)
        elif isinstance(node, dict):
            for k, v in node.items():
                walk_free(file, f"{key}.{k}", v)
    for fname in ("saints_es.json", "reference_es.json", "courses_es.json",
                  "ui_strings_es.json"):
        for k, v in load(fname).items():
            if not k.startswith("_"):
                walk_free(fname.replace("_es.json", ""), k, v)

    # ---- report ----
    print("pairs checked per corpus:")
    for f, n in sorted(n_pairs.items()):
        print(f"  {f:18} {n}")
    print()
    HARD = ("EMPTY", "LEAK-EN", "LEAK-LA", "VNUM", "BANK", "DUP",
            "ALLELUIA", "STRUCT", "ART", "MISSING", "HEAD", "GLORIA")
    failed = False
    for check in HARD:
        items = flags[check]
        print(f"== {check}: {len(items)} flags")
        for f, k, d in items[:args.show]:
            print(f"   [{f}] {k}: {d}")
        if items:
            failed = True
        print()

    st = flags["STAR"]
    print(f"== STAR (advisory): {len(st)} fields where the inline * flex-marker")
    print("   count differs from the Latin's — translations legitimately move")
    print("   or split the flex, so triage by hand after an import.")
    for f, k, d in st[:args.show]:
        print(f"   [{f}] {k}: {d}")
    print()

    np = flags["NOPAIR"]
    print(f"== NOPAIR (advisory): {len(np)} fields display Latin-only in BOTH")
    print("   languages (no English either) — the pre-existing Latin-only")
    print("   corpus, tracked as its own translation tranche.")
    for f, k, d in np[:args.show]:
        print(f"   [{f}] {k}: {d}")
    print()

    print("== GROUP (advisory): same Latin, different Spanish")
    n_groups = 0
    for key, rows in groups.items():
        if len(rows) < 2:
            continue
        variants = defaultdict(list)
        for k, e in rows:
            for v in variants:
                if sim(v, e) >= 0.55:
                    variants[v].append(k)
                    break
            else:
                variants[e].append(k)
        if len(variants) > 1:
            sizes = sorted(len(v) for v in variants.values())
            if sizes[0] * 3 <= sizes[-1] or len(rows) >= 6:
                n_groups += 1
                if n_groups <= args.show:
                    print("   LAT:", key[:70])
                    for v, ks in variants.items():
                        print(f"     [{len(ks)}] {v[:64]} :: {ks[0]}")
    print(f"   {n_groups} inconsistent groups")
    if args.strict and n_groups:
        failed = True
    print()

    print("== COG (advisory): cognate-score distribution")
    for file, rows in sorted(cogs.items()):
        rows.sort()
        n = len(rows)
        pct = lambda p: rows[int(n * p)][0] if n else 0
        print(f"   {file:18} n={n:6}  p5={pct(.05):.2f} med={pct(.5):.2f}")

    if failed:
        print("\nFAILURES — see the flags above")
        sys.exit(1)
    print("\nSpanish fidelity QA: clean")

if __name__ == "__main__":
    main()
